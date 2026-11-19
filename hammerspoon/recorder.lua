-- Work Recorder（作業録画）のボタン。画面の端に黒い切り欠き（サイドノッチ）を貼り、マウスを寄せるとボタンが出てくる。
-- 手作業を声つきで録画し、あとで AI（Claude Code / Codex など）に渡して、毎日の仕事（スキル）にするための道具。
--   ふだん: 端に細い黒い線だけ。マウスを寄せるとノッチが出てくる。
--   ● 録画: 押すと録画（声あり）。option を押しながらで声なし。録画中はノッチが出たままで赤い ■ と時間。押すと止めて保存。
--   未相談: AI との相談を待っている録画の本数。押すと録画の一覧のフォルダ。
--   長押し（0.25秒）か押したまま動かすとつまめる: 上下に動かす・反対の端へ運ぶ。離すと近い方の端へ吸い寄せられて貼りつく。位置は覚える。
--   ctrl+option+cmd+R でも開始・停止。外から: open -g "hammerspoon://rec-toggle?voice=0"
-- 止めたら scripts/ingest.sh が縮めて下ごしらえ（文字起こし・コマ一覧）する。録画はこの Mac の中にだけ置き、外へは送らない。

local M = {}
local HOME = os.getenv("HOME")
-- この道具の置き場（このファイルの2つ上）。どこに置いても動く
local BASE = debug.getinfo(1, "S").source:sub(2):match("^(.*)/hammerspoon/[^/]+$") or (HOME .. "/work-recorder")
-- 設定（任意）: <置き場>/config.json に {"recordings_dir": "~/Movies/作業録画"}
local function loadConfig()
  local f = io.open(BASE .. "/config.json", "r")
  if not f then return {} end
  local body = f:read("*a"); f:close()
  local ok, c = pcall(hs.json.decode, body)
  return (ok and type(c) == "table") and c or {}
end
local CONFIG = loadConfig()
local ROOT = (CONFIG.recordings_dir or "~/Movies/作業録画"):gsub("^~", HOME)
local SKILL = BASE
local INGEST = SKILL .. "/scripts/ingest.sh"

local rec = nil      -- { task, dir, started, voice, lastKey, poll, stopping }
local busy = 0       -- 下ごしらえ中の本数
local start, stop    -- 下で定義

---------------------------------------------------------------- 台帳
local function pendingCount()
  local n = 0
  local ok, iter, dirobj = pcall(hs.fs.dir, ROOT)
  if not ok or not iter then return 0 end
  for name in iter, dirobj do
    if name:match("^%d%d%d%d%-") then
      local f = io.open(ROOT .. "/" .. name .. "/meta.json", "r")
      if f then
        local body = f:read("*a"); f:close()
        local okj, meta = pcall(hs.json.decode, body)
        if okj and meta and meta.status == "未相談" then n = n + 1 end
      end
    end
  end
  return n
end

local function writeJSON(path, tbl)
  local f = io.open(path, "w")
  if f then f:write(hs.json.encode(tbl, true)); f:close() end
end

local function fmt(s) return string.format("%d:%02d", s // 60, s % 60) end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

---------------------------------------------------------------- 見た目の定数
local K = 0.5523            -- 円の4分の1を3次曲線で描く係数
local H = 118               -- ボタンが並ぶ所の高さ
local OPEN_W, REST_W = 54, 6
local FILLET = 10           -- 縁から反って出る凹の角
local BLACK = { red = 0.04, green = 0.04, blue = 0.05, alpha = 1 }
local GRAY = { white = 0.62 }
local RED = { red = 0.96, green = 0.23, blue = 0.21 }
local GREEN = { red = 0.36, green = 0.8, blue = 0.45 }
local DIM = { white = 0.28 }
local PAD = 16              -- つまんでいる間の伸び縮みの余白

local side = hs.settings.get("workrec.side") or "right"     -- 貼りつく端
local yfrac = hs.settings.get("workrec.yfrac") or 0.42      -- 縦の位置（画面の高さの割合）

local notch = hs.canvas.new({ x = 0, y = 0, w = REST_W, h = H + 20 })
local tip = hs.canvas.new({ x = 0, y = 0, w = 10, h = 10 })
local width = REST_W        -- 貼りついている時の幅（動かしている途中も）
local target = REST_W
local anim = nil
local hovering = false
local pulse = 0
local cachedCount = 0
local fillet = FILLET       -- 吸い寄せのあと、凹の角が0から育つ
local mode = "docked"       -- docked（端に貼りつく）/ floating（つまんでいる・吸い寄せの途中）
local float = { x = 0, y = 0, sx = 1, sy = 1, vx = 0, vy = 0 }  -- 浮いている時の中心と伸び
local drawnW = nil

local function screenFrame() return hs.screen.primaryScreen():fullFrame() end

local function centerY(f, T)
  return clamp(f.y + f.h * yfrac, f.y + 30 + T / 2, f.y + f.h - 8 - T / 2)
end

-- 右端に貼りつく形: 画面の縁から内へ丸く反って（凹の角）出て、外側の角は丸い（凸の角）。左端は左右を反転する
local function shape(w, rf)
  local r = math.min(rf, w / 2)
  local R = math.min(15, w - r)
  local T = H + 2 * FILLET
  local top = FILLET - r        -- 凹の角が小さい間も、ボタンの位置はずらさない
  local pts = {
    { x = w, y = top },
    { x = w - r, y = top + r, c1x = w, c1y = top + K * r, c2x = w - r + K * r, c2y = top + r },
    { x = R, y = FILLET },
    { x = 0, y = FILLET + R, c1x = R - K * R, c1y = FILLET, c2x = 0, c2y = FILLET + R - K * R },
    { x = 0, y = FILLET + H - R },
    { x = R, y = FILLET + H, c1x = 0, c1y = FILLET + H - R + K * R, c2x = R - K * R, c2y = FILLET + H },
    { x = w - r, y = FILLET + H },
    { x = w, y = FILLET + H + r, c1x = w - r + K * r, c1y = FILLET + H, c2x = w, c2y = FILLET + H + r - K * r },
  }
  if side == "left" then
    for _, p in ipairs(pts) do
      p.x = w - p.x
      if p.c1x then p.c1x = w - p.c1x; p.c2x = w - p.c2x end
    end
  end
  return pts, T
end

-- 浮いている時の形: 角の丸い粒。動く向きに伸び、横に縮む（液体らしく）
local function blob(cw, ch, sx, sy)
  local w, h = OPEN_W * sx, (H + 8) * sy
  local x, y = (cw - w) / 2, (ch - h) / 2
  return { type = "rectangle", frame = { x = x, y = y, w = w, h = h },
    roundedRectRadii = { xRadius = math.min(24, w / 2), yRadius = math.min(24, w / 2) },
    action = "fill", fillColor = BLACK, trackMouseDown = true, id = "body" }
end

local function ring(id, cx, cy, color, frac)
  local out = {
    { id = id, type = "circle", center = { x = cx, y = cy }, radius = 14, action = "fill",
      fillColor = { white = 1, alpha = 0.001 }, trackMouseEnterExit = true, trackMouseDown = true },
    { type = "circle", center = { x = cx, y = cy }, radius = 12.5, action = "stroke",
      strokeColor = DIM, strokeWidth = 2.5 },
  }
  if frac and frac > 0 then
    table.insert(out, { type = "arc", center = { x = cx, y = cy }, radius = 12.5, startAngle = 0,
      endAngle = 360 * math.min(frac, 1), action = "stroke", strokeColor = color, strokeWidth = 2.5,
      arcRadii = false })
  end
  return out
end

local function label(text, cx, y, color)
  return { type = "text", text = hs.styledtext.new(text, { font = { size = 9 },
    color = color or GRAY, paragraphStyle = { alignment = "center" } }),
    frame = { x = cx - 27, y = y, w = 54, h = 12 } }
end

-- ボタン2つ（録画・未相談）を、中心 cx・上端 top から描く
local function buttons(els, cx, top)
  local y1, y2 = top + 30, top + 84
  if rec and rec.stopping then
    for _, e in ipairs(ring("rec", cx, y1, GRAY, (pulse % (2 * math.pi)) / (2 * math.pi))) do table.insert(els, e) end
    table.insert(els, label("保存中", cx, y1 + 17))
  elseif rec then
    local glow = 0.55 + 0.45 * math.abs(math.sin(pulse))
    for _, e in ipairs(ring("rec", cx, y1, RED, 1)) do table.insert(els, e) end
    table.insert(els, { type = "rectangle", frame = { x = cx - 5, y = y1 - 5, w = 10, h = 10 },
      roundedRectRadii = { xRadius = 2, yRadius = 2 }, action = "fill",
      fillColor = { red = RED.red, green = RED.green, blue = RED.blue, alpha = glow } })
    table.insert(els, label(fmt(math.floor(hs.timer.secondsSinceEpoch() - rec.started)), cx, y1 + 17, RED))
  else
    for _, e in ipairs(ring("rec", cx, y1, RED, 0)) do table.insert(els, e) end
    table.insert(els, { type = "circle", center = { x = cx, y = y1 }, radius = 6, action = "fill", fillColor = RED })
    table.insert(els, label("録画", cx, y1 + 17))
  end
  local frac = 0
  if busy > 0 then frac = (pulse % (2 * math.pi)) / (2 * math.pi) elseif cachedCount > 0 then frac = 1 end
  for _, e in ipairs(ring("count", cx, y2, busy > 0 and GRAY or GREEN, frac)) do table.insert(els, e) end
  table.insert(els, { type = "text", text = hs.styledtext.new(tostring(cachedCount), { font = { name = ".AppleSystemUIFontBold", size = 12 },
    color = { white = 0.92 }, paragraphStyle = { alignment = "center" } }), frame = { x = cx - 14, y = y2 - 8, w = 28, h = 16 } })
  table.insert(els, label(busy > 0 and "準備中" or "未相談", cx, y2 + 17))
  return y1, y2
end

local Y1, Y2 = FILLET + 30, FILLET + 84    -- 貼りついている時のボタンの高さ（吹き出しの位置に使う）

local function draw()
  local f = screenFrame()
  if mode == "floating" then
    local cw, ch = OPEN_W + 2 * PAD, H + 8 + 2 * PAD
    notch:frame({ x = math.floor(float.x - cw / 2), y = math.floor(float.y - ch / 2), w = cw, h = ch })
    local els = { blob(cw, ch, float.sx, float.sy) }
    buttons(els, cw / 2, (ch - (H + 8) * float.sy) / 2 + 4 * float.sy)
    notch:replaceElements(els)
    drawnW = nil
    return
  end
  local pts, T = shape(width, fillet)
  local cy = centerY(f, T)
  local x = side == "left" and f.x or (f.x + f.w - width)
  local newFrame = { x = x, y = math.floor(cy - T / 2), w = width, h = T }
  -- 出入りの途中で縁に白いすき間が出た。窓の大きさと中の絵の更新が1コマずれると、
  -- 広がる時は窓だけ先に広がって空きができる。広がる時は絵を先に、縮む時は窓を先に変え、空きを作らない
  local growing = drawnW == nil or width >= drawnW
  if not growing then notch:frame(newFrame) end
  local els = {
    { id = "body", type = "segments", closed = true, coordinates = pts, action = "fill", fillColor = BLACK,
      trackMouseDown = true },
  }
  if width >= OPEN_W * 0.8 then
    buttons(els, side == "left" and (width / 2 - 1) or (width / 2 + 1), FILLET)
  end
  notch:replaceElements(els)
  if growing then notch:frame(newFrame) end
  drawnW = width
end

local function animateTo(w)
  target = w
  if anim then return end
  anim = hs.timer.doEvery(1 / 60, function()
    if mode ~= "docked" then return end
    -- 幅は整数の点だけ（小数の位置だと画面の縁とのあいだに細い線が出る）
    local d = target - width
    if math.abs(d) <= 1 then
      width = target
      anim:stop(); anim = nil
    else
      local step = d * 0.3
      if step > 0 then step = math.max(1, math.floor(step)) else step = math.min(-1, math.ceil(step)) end
      width = width + step
    end
    draw()
  end)
end

-- 吹き出し（ボタンの内側の向きに出す。投稿の形）
local function showTip(text, cy)
  if mode ~= "docked" then return end
  local nf = notch:frame()
  local st = hs.styledtext.new(text, { font = { size = 12 }, color = { white = 0.95 } })
  local sz = hs.drawing.getTextDrawingSize(st)
  local w, h = sz.w + 24, 30
  local onLeft = side == "left"
  tip:frame({ x = onLeft and (nf.x + nf.w + 4) or (nf.x - w - 10), y = nf.y + cy - h / 2, w = w + 6, h = h })
  local bx = onLeft and 6 or 0
  local tri = onLeft
    and { { x = 7, y = h / 2 - 6 }, { x = 0, y = h / 2 }, { x = 7, y = h / 2 + 6 } }
    or { { x = w - 1, y = h / 2 - 6 }, { x = w + 6, y = h / 2 }, { x = w - 1, y = h / 2 + 6 } }
  tip:replaceElements(
    { type = "rectangle", frame = { x = bx, y = 0, w = w, h = h }, roundedRectRadii = { xRadius = 9, yRadius = 9 },
      action = "fill", fillColor = BLACK },
    { type = "segments", closed = true, action = "fill", fillColor = BLACK, coordinates = tri },
    { type = "text", text = st, frame = { x = bx + 12, y = (h - sz.h) / 2, w = sz.w + 4, h = sz.h + 2 } }
  )
  tip:show()
end

local closeTimer = nil
local function wantOpen() return hovering or rec ~= nil end
local function settle()
  if closeTimer then closeTimer:stop(); closeTimer = nil end
  if mode ~= "docked" then return end
  if wantOpen() then
    animateTo(OPEN_W)
  else
    closeTimer = hs.timer.doAfter(1.0, function()
      closeTimer = nil
      if not wantOpen() and mode == "docked" then tip:hide(); animateTo(REST_W) end
    end)
  end
end

---------------------------------------------------------------- つまむ・運ぶ・吸い寄せる
local press = nil       -- { id, t0, x0, y0, cx, cy, offX, offY, timer, dragging }
local spring = nil
local moveFloat         -- 下で定義（吸い寄せの途中でも使う）

local function dockedCenter(f, s)
  local T = H + 2 * FILLET
  local cx = s == "left" and (f.x + OPEN_W / 2) or (f.x + f.w - OPEN_W / 2)
  return cx, centerY(f, T)
end

-- 離した所から、近い方の端へ。ばねで寄って少し行き過ぎて戻り、着いたら凹の角が育って縁に溶けこむ
local function snap()
  local f = screenFrame()
  side = (float.x < f.x + f.w / 2) and "left" or "right"
  yfrac = clamp((float.y - f.y) / f.h, 0.05, 0.95)
  hs.settings.set("workrec.side", side)
  hs.settings.set("workrec.yfrac", yfrac)
  local tx, ty = dockedCenter(f, side)
  if spring then spring:stop() end
  spring = hs.timer.doEvery(1 / 60, function()
    float.vx = (float.vx + (tx - float.x) * 0.11) * 0.74
    float.vy = (float.vy + (ty - float.y) * 0.11) * 0.74
    float.x = float.x + float.vx
    float.y = float.y + float.vy
    local sp = math.sqrt(float.vx ^ 2 + float.vy ^ 2)
    local along = sp > 0.01 and math.abs(float.vx) / sp or 0
    local s = clamp(sp / 45, 0, 0.3)
    float.sx = 1 + s * along - s * 0.5 * (1 - along)
    float.sy = 1 + s * (1 - along) - s * 0.5 * along
    if math.abs(tx - float.x) < 0.8 and math.abs(ty - float.y) < 0.8 and sp < 0.8 then
      spring:stop(); spring = nil
      -- 着いた: 端に貼りつく形へ。凹の角を0から育てる
      mode = "docked"; width = OPEN_W; drawnW = nil; fillet = 0
      local grow
      grow = hs.timer.doEvery(1 / 60, function()
        fillet = math.min(FILLET, fillet + 1.2)
        draw()
        if fillet >= FILLET then grow:stop() end
      end)
      draw()
      hovering = false
      settle()
      return
    end
    moveFloat()
  end)
end

-- つまんだ点を、押した瞬間の位置で覚える（動き出した瞬間の位置で覚えると、押してから動かした分だけ
-- マウスと離れてついてきた。作り始めの不具合）
local function beginDrag()
  press.dragging = true
  if closeTimer then closeTimer:stop(); closeTimer = nil end
  if anim then anim:stop(); anim = nil end
  tip:hide()
  mode = "floating"
  float.x, float.y = press.cx, press.cy
  float.vx, float.vy = 0, 0
  float.sx, float.sy = 1.08, 1.08      -- つまんだ合図に少しふくらむ
  press.offX, press.offY = press.x0 - press.cx, press.y0 - press.cy
  draw()
end

-- 運んでいる間は、窓を動かして粒の大きさだけ変える（毎回すべて描き直すと遅れた）
moveFloat = function()
  local cw, ch = OPEN_W + 2 * PAD, H + 8 + 2 * PAD
  notch:topLeft({ x = math.floor(float.x - cw / 2), y = math.floor(float.y - ch / 2) })
  local w, h = OPEN_W * float.sx, (H + 8) * float.sy
  notch[1].frame = { x = (cw - w) / 2, y = (ch - h) / 2, w = w, h = h }
end

local function click(id)
  tip:hide()
  if id == "rec" then
    if rec then stop() else start(not hs.eventtap.checkKeyboardModifiers().alt) end
  elseif id == "count" then
    hs.fs.mkdir(ROOT)
    hs.execute("open " .. string.format("%q", ROOT))
  end
end

local function onPress(id)
  if press and press.timer then press.timer:stop() end
  local m = hs.mouse.absolutePosition()
  local nf = notch:frame()
  press = { id = id, t0 = hs.timer.secondsSinceEpoch(), x0 = m.x, y0 = m.y, dragging = false }
  -- 粒になった時の中心: 貼りついている時は、端から OPEN_W/2 の所（つまんだ点がずれないように今の形から決める）
  if mode == "docked" then
    press.cx = side == "left" and (nf.x + OPEN_W / 2) or (nf.x + nf.w - OPEN_W / 2)
    press.cy = nf.y + nf.h / 2
  else
    press.cx, press.cy = float.x, float.y
  end
  -- ボタンが離されたかは、押されている状態を60分の1秒ごとに見る（アクセシビリティの許可なしで動く）
  press.timer = hs.timer.doEvery(1 / 60, function()
    local p = press
    if not p then return end
    local held = hs.eventtap.checkMouseButtons().left
    local m2 = hs.mouse.absolutePosition()
    local moved = math.abs(m2.x - p.x0) + math.abs(m2.y - p.y0)
    if not held then
      p.timer:stop(); press = nil
      if p.dragging then snap() elseif hs.timer.secondsSinceEpoch() - p.t0 < 0.5 then click(p.id) end
      return
    end
    -- つまむのは、押したまま動かし始めた瞬間（5点）か、0.25秒押し続けた時。待たずに指についてくる
    if not p.dragging and (moved >= 5 or hs.timer.secondsSinceEpoch() - p.t0 >= 0.25) then beginDrag() end
    if p.dragging then
      local nx, ny = m2.x - p.offX, m2.y - p.offY
      float.vx = float.vx * 0.5 + (nx - float.x) * 0.5
      float.vy = float.vy * 0.5 + (ny - float.y) * 0.5
      float.x, float.y = nx, ny
      local sp = math.sqrt(float.vx ^ 2 + float.vy ^ 2)
      local along = sp > 0.01 and math.abs(float.vx) / sp or 0
      local s = clamp(sp / 40, 0, 0.3)
      float.sx = 1.04 + s * along - s * 0.5 * (1 - along)
      float.sy = 1.04 + s * (1 - along) - s * 0.5 * along
      moveFloat()
    end
  end)
end

notch:level(hs.canvas.windowLevels.overlay)
notch:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
notch:clickActivating(false)
notch:canvasMouseEvents(false, false, true, false)
tip:level(hs.canvas.windowLevels.overlay)
tip:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
tip:clickActivating(false)

notch:mouseCallback(function(_, msg, id)
  if id == "_canvas_" then
    if mode ~= "docked" then return end
    if msg == "mouseEnter" then
      hovering = true
      cachedCount = pendingCount()
      settle()
    elseif msg == "mouseExit" then
      -- ここでは閉じない。閉じるかは端の見張りが広いゆとりで決める
      tip:hide()
    end
    return
  end
  if msg == "mouseDown" then
    onPress(id)
  elseif msg == "mouseEnter" and not press then
    if id == "rec" then
      showTip(rec and (rec.stopping and "保存しています" or "止めて保存する") or "録画を始める（声あり）・option で声なし・長押しで動かす", Y1)
    elseif id == "count" then
      showTip(busy > 0 and ("下ごしらえ中 " .. busy .. "本") or ("相談を待っている録画 " .. cachedCount .. "本・押すと一覧"), Y2)
    end
  elseif msg == "mouseExit" then
    tip:hide()
  end
end)

-- 録画中・保存中・下ごしらえ中だけ、輪を動かす
local motion = hs.timer.doEvery(1 / 12, function()
  if rec or busy > 0 then
    pulse = pulse + 0.35
    if mode == "docked" and width > REST_W + 1 then draw() end
  end
end)

-- 端の見張り: 右に外付けの画面があると、右端でマウスが止まらず通り過ぎ、細い線に乗った合図を取りこぼす
-- （外付けの画面を右や左に並べている Mac でよく起きる）。
-- 20分の1秒ごとにマウスの位置を見て、ノッチの高さで端から6点以内に来たら開く
local edgeWatch = hs.timer.doEvery(1 / 20, function()
  if mode ~= "docked" or press then return end
  local f = screenFrame()
  local m = hs.mouse.absolutePosition()
  if hovering then
    -- 外の画面へ抜けると「出た」の合図が来ないことがある。ノッチの外に出ていたら閉じる側へ
    -- 外かどうかは「開ききった形」＋内側に広いゆとりで見る。開く途中の細い形で見ると、
    -- ボタンへ指を動かす途中で外と見て閉じていた（2026-11-19 オーナー「押そうとしたら引っ込むのが早すぎる」）
    local nf = notch:frame()
    local outX
    if side == "left" then
      outX = m.x < f.x - 4 or m.x > f.x + OPEN_W + 36
    else
      outX = m.x < f.x + f.w - OPEN_W - 36 or m.x > f.x + f.w + 4
    end
    if outX or m.y < nf.y - 24 or m.y > nf.y + nf.h + 24 then
      hovering = false
      tip:hide()
      settle()
    end
    return
  end
  local T = H + 2 * FILLET
  local cy = centerY(f, T)
  if math.abs(m.y - cy) > T / 2 then return end
  local near = side == "left" and (m.x >= f.x and m.x <= f.x + 6) or (m.x <= f.x + f.w and m.x >= f.x + f.w - 6)
  if near then
    hovering = true
    cachedCount = pendingCount()
    settle()
  end
end)

-- 画面の配置が変わったら貼り直す
local screenWatch = hs.screen.watcher.new(function() if mode == "docked" then draw() end end):start()

---------------------------------------------------------------- 何をしたかの記録
-- Chrome の URL は AppleScript を裏で聞く。同期で聞くと Hammerspoon が数秒固まり、止めるボタンが効かなかった
local urlBusy = false
local function chromeURLAsync(cb)
  if urlBusy then return cb(nil) end
  urlBusy = true
  local t = hs.task.new("/usr/bin/osascript", function(code, out)
    urlBusy = false
    cb(code == 0 and out and out:gsub("%s+$", "") or nil)
  end, { "-e", 'tell application "Google Chrome" to get URL of active tab of front window' })
  if not t:start() then urlBusy = false; cb(nil) end
  hs.timer.doAfter(3, function() if t:isRunning() then t:terminate() end end)
end

local function writeEvent(appName, title, url)
  if not rec then return end
  local key = appName .. "|" .. title .. "|" .. (url or "")
  if key == rec.lastKey then return end
  rec.lastKey = key
  local f = io.open(rec.dir .. "/events.jsonl", "a")
  if f then
    f:write(hs.json.encode({ t = math.floor(hs.timer.secondsSinceEpoch() - rec.started), app = appName, title = title, url = url }) .. "\n")
    f:close()
  end
end

local function logFront()
  if not rec then return end
  local app = hs.application.frontmostApplication()
  local appName = app and app:name() or "?"
  local win = hs.window.focusedWindow()
  local title = win and win:title() or ""
  if appName == "Google Chrome" then
    chromeURLAsync(function(url) writeEvent(appName, title, url) end)
  else
    writeEvent(appName, title, nil)
  end
end

---------------------------------------------------------------- 録画
local function runIngest(dir, voice)
  busy = busy + 1
  draw()
  local args = { dir }
  if not voice then table.insert(args, "--no-voice") end
  local t = hs.task.new(INGEST, function(code, _, err)
    busy = math.max(0, busy - 1)
    cachedCount = pendingCount()
    draw()
    if code == 0 then
      hs.notify.new({ title = "作業録画を保存しました", informativeText = "AI（Claude Code・Codex など）に「作業録画を見て」と言えば、どの作業にするか相談できます（未相談 " .. cachedCount .. "本）" }):send()
    else
      hs.notify.new({ title = "作業録画の下ごしらえに失敗", informativeText = "録画は残っています: " .. dir .. "\n" .. (err or ""):sub(1, 120) }):send()
    end
  end, args)
  t:start()
end

start = function(voice)
  if rec then return end
  local id = os.date("%Y-%m-%d_%H%M%S")
  local dir = ROOT .. "/" .. id
  hs.fs.mkdir(ROOT); hs.fs.mkdir(dir)
  -- 声は screencapture -g だと動画が 0.05 秒で壊れるので、既定のマイクを rec-run.sh が ffmpeg で別に録る
  local args = { dir }
  if voice then table.insert(args, "--mic"); table.insert(args, "default") end
  for _, a in ipairs({ "-v", "-k", "-x", dir .. "/raw.mov" }) do table.insert(args, a) end
  -- 中継の rec-run.sh が screencapture の入力を開けたままにする（直接だと入力が閉じていて即止まる）
  local task = hs.task.new(SKILL .. "/scripts/rec-run.sh", function()
    local r = rec
    rec = nil
    if r and r.poll then r.poll:stop() end
    settle()
    draw()
    local d = r and r.dir or dir
    if hs.fs.attributes(d .. "/raw.mov") then
      runIngest(d, voice)
    else
      -- 録画が残らなかった回は、空のフォルダを台帳に残さない
      os.remove(d .. "/events.jsonl"); os.remove(d .. "/meta.json"); os.remove(d .. "/voice.log"); os.remove(d .. "/voice.m4a"); os.remove(d)
      hs.notify.new({ title = "作業録画が保存されませんでした", informativeText = "画面収録の許可（システム設定 > プライバシーとセキュリティ > 画面収録）で Hammerspoon を入にしてください" }):send()
    end
  end, args)
  if not task:start() then
    hs.notify.new({ title = "録画を始められませんでした", informativeText = "rec-run.sh が起動しません" }):send()
    return
  end
  rec = { task = task, dir = dir, started = hs.timer.secondsSinceEpoch(), voice = voice, lastKey = nil }
  writeJSON(dir .. "/meta.json", { id = id, started = os.date("%Y-%m-%dT%H:%M:%S"), voice = voice, status = "録画中" })
  logFront()
  rec.poll = hs.timer.doEvery(2, logFront)
  settle()
  draw()
end

stop = function()
  if not rec or rec.stopping then return end
  rec.stopping = true          -- 押したことがすぐ分かるように、輪を灰色で回して「保存中」に
  local f = io.open(rec.dir .. "/.stop", "w")
  if f then f:write("stop"); f:close() end
  draw()
end

function M.toggle(voice)
  if rec then stop() else start(voice ~= false) end
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "R", function() M.toggle(true) end)
hs.urlevent.bind("rec-toggle", function(_, params) M.toggle(params.voice ~= "0") end)

cachedCount = pendingCount()
draw()
notch:show()

M.notch, M.tip, M.motion, M.screenWatch, M.edgeWatch = notch, tip, motion, screenWatch, edgeWatch
M.state = function() return { recording = rec ~= nil, stopping = rec and rec.stopping or false, busy = busy, width = width, pending = cachedCount, side = side, yfrac = yfrac, mode = mode } end
-- 試し用: つまんで運んで離すのを、マウスを使わずに再現する
M.testDrop = function(x, y) mode = "floating"; float.x, float.y = x, y; float.vx, float.vy = 0, 0; float.sx, float.sy = 1, 1; draw(); snap() end
-- 試し用: 1コマにかかる時間（すべて描き直す・粒を動かすだけ）をミリ秒で返す
M.bench = function()
  local saveMode = mode
  mode = "floating"; float.x, float.y = 700, 400; float.sx, float.sy = 1, 1; draw()
  local t = hs.timer.absoluteTime()
  for _ = 1, 30 do draw() end
  local full = (hs.timer.absoluteTime() - t) / 30 / 1e6
  t = hs.timer.absoluteTime()
  for i = 1, 30 do float.x = 700 + i; moveFloat() end
  local fast = (hs.timer.absoluteTime() - t) / 30 / 1e6
  mode = saveMode; drawnW = nil; draw()
  return string.format("すべて描き直す %.2fms・粒を動かすだけ %.2fms", full, fast)
end
return M
