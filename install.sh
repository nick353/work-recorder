#!/bin/bash
# Work Recorder（作業録画）を入れる。何度流しても同じ結果になる（入れ直し・直しにも使える）。
#   ./install.sh [--no-transcribe] [--no-skill] [--no-open]
#     --no-transcribe  文字起こし（faster-whisper、約200MB＋初回にモデル約500MB）を入れない
#     --no-skill       AI 用のスキル（Claude Code / Codex）を入れない
#     --no-open        権限の設定画面を開かない
set -u
cd "$(dirname "$0")"
BASE="$(pwd)"
TRANSCRIBE=1; SKILL=1; OPEN=1
for a in "$@"; do
  case "$a" in
    --no-transcribe) TRANSCRIBE=0 ;;
    --no-skill) SKILL=0 ;;
    --no-open) OPEN=0 ;;
    *) echo "知らない引数: $a"; exit 64 ;;
  esac
done
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
ok() { printf '  ○ %s\n' "$1"; }
ng() { printf '  × %s\n' "$1"; }
step() { printf '\n== %s\n' "$1"; }

step "1. この Mac で動くか"
[ "$(uname)" = "Darwin" ] || { ng "macOS 専用です"; exit 1; }
ok "macOS $(sw_vers -productVersion)"

step "2. Homebrew"
if ! command -v brew >/dev/null; then
  ng "Homebrew がありません。https://brew.sh の1行をターミナルで流してから、もう一度 ./install.sh を流してください（Mac のパスワードが要るので本人が流します）"
  exit 2
fi
ok "$(brew --version | head -1)"

step "3. Hammerspoon（ボタンを出す無料のアプリ）と ffmpeg（動画を縮める道具）"
if [ ! -d /Applications/Hammerspoon.app ]; then
  brew install --cask hammerspoon || { ng "Hammerspoon を入れられませんでした"; exit 3; }
fi
ok "Hammerspoon"
if ! command -v ffmpeg >/dev/null; then
  brew install ffmpeg || { ng "ffmpeg を入れられませんでした"; exit 3; }
fi
ok "ffmpeg"

step "4. 下ごしらえの道具（Python の箱）"
PYBIN="$(command -v python3)"
[ -n "$PYBIN" ] || { ng "python3 がありません（xcode-select --install で入ります）"; exit 4; }
[ -x .venv/bin/python ] || "$PYBIN" -m venv .venv || { ng "Python の箱を作れませんでした"; exit 4; }
.venv/bin/python -m pip install -q --upgrade pip >/dev/null 2>&1
.venv/bin/python -m pip install -q pillow || { ng "Pillow を入れられませんでした"; exit 4; }
ok "Pillow（コマ一覧に秒数を書く）"
if [ "$TRANSCRIBE" = 1 ]; then
  if .venv/bin/python -m pip install -q faster-whisper; then
    ok "faster-whisper（話し声の文字起こし。初回だけモデルを約500MB取ってくる）"
  else
    ng "faster-whisper を入れられませんでした（文字起こしなしで動きます）"
  fi
else
  ok "文字起こしは入れない（--no-transcribe）"
fi
chmod +x install.sh uninstall.sh doctor.sh scripts/*.sh scripts/*.py
[ -f config.json ] || cp config.example.json config.json
ok "設定 $BASE/config.json"

step "5. Hammerspoon の設定に、ボタンを読む数行を足す（今の設定は消さない）"
mkdir -p "$HOME/.hammerspoon"
INIT="$HOME/.hammerspoon/init.lua"
touch "$INIT"
TMP="$(mktemp)"
awk '/^-- >>> work-recorder >>>/{skip=1} !skip{print} /^-- <<< work-recorder <<</{skip=0}' "$INIT" > "$TMP"
cat >> "$TMP" <<EOF
-- >>> work-recorder >>>
-- Work Recorder（作業録画）のボタン。消すときは $BASE/uninstall.sh
hs.autoLaunch(true)          -- ログインしたら自動で起動（ボタンを常に出す）
require("hs.ipc")            -- AI が状態を確かめる口（doctor.sh が使う）
WorkRecorder = dofile("$BASE/hammerspoon/recorder.lua")
-- <<< work-recorder <<<
EOF
mv "$TMP" "$INIT"
ok "$INIT"

step "6. AI 用のスキル（録画を見て、どの作業にするか相談する手順）"
if [ "$SKILL" = 1 ]; then
  for dest in "$HOME/.claude/skills/work-recorder" "$HOME/.codex/skills/work-recorder"; do
    parent="$(dirname "$(dirname "$dest")")"
    if [ -d "$parent" ] || [ "$dest" = "$HOME/.claude/skills/work-recorder" ]; then
      mkdir -p "$dest"
      sed "s#{{BASE}}#$BASE#g" skill/SKILL.md > "$dest/SKILL.md"
      ok "$dest/SKILL.md"
    fi
  done
else
  ok "入れない（--no-skill）"
fi

step "7. Hammerspoon を起動・読み直す"
HS=/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs
if pgrep -x Hammerspoon >/dev/null; then
  ( "$HS" -t 5 -c 'hs.reload()' >/dev/null 2>&1 & )
  sleep 3
else
  open -a Hammerspoon
  sleep 4
fi
ok "Hammerspoon"

step "8. 権限（本人がスイッチを入れる。AI や台本からは入れられない）"
cat <<'EOF'
  システム設定 > プライバシーとセキュリティ で、次の3つの一覧の「Hammerspoon」を入にしてください。
    1) 画面収録（または「画面とシステムオーディオの録音」）… 録画に必須
    2) マイク … 声つきで録るとき（初めて声ありで録ると聞かれます）
    3) アクセシビリティ … 窓の名前を記録するとき（なくても録画はできます）
  画面収録を入にしたら、Hammerspoon を一度終了して開き直してください（メニューの Quit → 開き直す）。
EOF
if [ "$OPEN" = 1 ]; then
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
fi

step "できあがり"
echo "  権限を入れたら ./doctor.sh で点検できます。"
echo
cat docs/USAGE.md
