#!/bin/bash
# Work Recorder installer. Safe to run again (re-install / repair).
#   ./install.sh [--no-transcribe] [--no-skill] [--no-open]
#     --no-transcribe  skip speech-to-text (faster-whisper: ~200MB + a ~500MB model on first use)
#     --no-skill       do not install the AI skill (Claude Code / Codex)
#     --no-open        do not open System Settings
set -u
cd "$(dirname "$0")"
BASE="$(pwd)"
WR_BASE="$BASE"; . "$BASE/scripts/lang.sh"
TRANSCRIBE=1; SKILL=1; OPEN=1
for a in "$@"; do
  case "$a" in
    --no-transcribe) TRANSCRIBE=0 ;;
    --no-skill) SKILL=0 ;;
    --no-open) OPEN=0 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "$(T "知らない引数" "Unknown argument"): $a"; exit 64 ;;
  esac
done
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
ok() { printf '  OK  %s\n' "$1"; }
ng() { printf '  NG  %s\n' "$1"; }
step() { printf '\n== %s\n' "$1"; }

step "1. $(T "この Mac で動くか" "Is this Mac supported?")"
[ "$(uname)" = "Darwin" ] || { ng "$(T "macOS 専用です" "macOS only")"; exit 1; }
MACV="$(sw_vers -productVersion)"
[ "${MACV%%.*}" -ge 12 ] 2>/dev/null || { ng "macOS 12 $(T "以降が必要です（今は" "or later is required (this is") $MACV$(T "）" ")")"; exit 1; }
ok "macOS $MACV"

step "2. Homebrew"
if ! command -v brew >/dev/null; then
  ng "$(T "Homebrew がありません。https://brew.sh の1行をターミナルで流してから、もう一度 ./install.sh を流してください（Mac のパスワードが要るので本人が流します）" "Homebrew is missing. Run the one-liner from https://brew.sh in Terminal (it asks for your Mac password, so you run it), then run ./install.sh again.")"
  exit 2
fi
ok "$(brew --version | head -1)"

step "3. $(T "Hammerspoon（ボタンを出す無料のアプリ）と ffmpeg（動画を縮める道具）" "Hammerspoon (free app that draws the button) and ffmpeg (shrinks the video)")"
if [ ! -d /Applications/Hammerspoon.app ] && [ ! -d "$HOME/Applications/Hammerspoon.app" ]; then
  brew install --cask hammerspoon || { ng "$(T "Hammerspoon を入れられませんでした" "Could not install Hammerspoon")"; exit 3; }
fi
ok "Hammerspoon"
if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
  brew install ffmpeg || { ng "$(T "ffmpeg を入れられませんでした" "Could not install ffmpeg")"; exit 3; }
fi
ok "ffmpeg"

step "4. $(T "下ごしらえの道具（Python の箱）" "Python environment for post-processing")"
PYBIN="$(command -v python3)"
[ -n "$PYBIN" ] || { ng "$(T "python3 がありません（xcode-select --install で入ります）" "python3 not found (run: xcode-select --install, or: brew install python)")"; exit 4; }
"$PYBIN" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' || { ng "$(T "Python 3.9 以降が必要です（brew install python）" "Python 3.9+ is required (brew install python)")"; exit 4; }
[ -x .venv/bin/python ] || "$PYBIN" -m venv .venv || { ng "$(T "Python の箱を作れませんでした" "Could not create the Python environment")"; exit 4; }
.venv/bin/python -m pip install -q --upgrade pip >/dev/null 2>&1
.venv/bin/python -m pip install -q pillow || { ng "$(T "Pillow を入れられませんでした" "Could not install Pillow")"; exit 4; }
ok "$(T "Pillow（コマ一覧に秒数を書く）" "Pillow (draws timestamps on contact sheets)")"
if [ "$TRANSCRIBE" = 1 ]; then
  if .venv/bin/python -m pip install -q faster-whisper; then
    ok "$(T "faster-whisper（話し声の文字起こし。初回だけモデルを約500MB取ってくる）" "faster-whisper (speech-to-text; downloads a ~500MB model the first time it runs)")"
  else
    ng "$(T "faster-whisper を入れられませんでした（文字起こしなしで動きます）" "Could not install faster-whisper (works without transcription)")"
  fi
else
  ok "$(T "文字起こしは入れない（--no-transcribe）" "skipping transcription (--no-transcribe)")"
fi
chmod +x install.sh uninstall.sh doctor.sh scripts/*.sh scripts/*.py
if [ ! -f config.json ]; then
  cp config.example.json config.json
  ok "$(T "設定を作った" "created config") $BASE/config.json"
else
  ok "$(T "設定はそのまま使う" "keeping existing config") $BASE/config.json"
fi

step "5. $(T "Hammerspoon の設定に、ボタンを読む数行を足す（今の設定は消さない）" "Add a few lines to your Hammerspoon config (existing config is kept)")"
mkdir -p "$HOME/.hammerspoon"
INIT="$HOME/.hammerspoon/init.lua"
touch "$INIT"
TMP="$(mktemp)"
awk '/^-- >>> work-recorder >>>/{skip=1} !skip{print} /^-- <<< work-recorder <<</{skip=0}' "$INIT" > "$TMP"
cat >> "$TMP" <<EOT
-- >>> work-recorder >>>
-- Work Recorder button. To remove: $BASE/uninstall.sh
hs.autoLaunch(true)          -- start Hammerspoon at login (keeps the button available)
require("hs.ipc")            -- lets doctor.sh / AI agents query the state
WorkRecorder = dofile([==[$BASE/hammerspoon/recorder.lua]==])
-- <<< work-recorder <<<
EOT
mv "$TMP" "$INIT"
ok "$INIT"

step "6. $(T "AI 用のスキル（録画を見て、どの作業にするか相談する手順）" "AI skill (how an agent reads a recording and turns it into a skill)")"
if [ "$SKILL" = 1 ]; then
  for dest in "$HOME/.claude/skills/work-recorder" "$HOME/.codex/skills/work-recorder"; do
    parent="$(dirname "$(dirname "$dest")")"
    if [ -d "$parent" ] || [ "$dest" = "$HOME/.claude/skills/work-recorder" ]; then
      mkdir -p "$dest"
      sed "s|{{BASE}}|$BASE|g" skill/SKILL.md > "$dest/SKILL.md"
      ok "$dest/SKILL.md"
    fi
  done
else
  ok "$(T "入れない（--no-skill）" "skipped (--no-skill)")"
fi

step "7. $(T "Hammerspoon を起動・読み直す" "Start / reload Hammerspoon")"
HS=/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs
[ -x "$HS" ] || HS="$HOME/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"
if pgrep -x Hammerspoon >/dev/null; then
  ( "$HS" -t 5 -c 'hs.reload()' >/dev/null 2>&1 & )
  sleep 3
else
  open -a Hammerspoon
  sleep 4
fi
ok "Hammerspoon"

step "8. $(T "権限（本人がスイッチを入れる。AI や台本からは入れられない）" "Permissions (you flip these switches yourself; scripts and AI cannot)")"
if [ "$WR_JA" = 1 ]; then
cat <<'EOT'
  システム設定 > プライバシーとセキュリティ で、次の3つの一覧の「Hammerspoon」を入にしてください。
    1) 画面収録（または「画面とシステムオーディオの録音」）… 録画に必須
    2) マイク … 声つきで録るとき（初めて声ありで録ると聞かれます）
    3) アクセシビリティ … 窓の名前を記録するとき（なくても録画はできます）
  画面収録を入にしたら、Hammerspoon を一度終了して開き直してください（メニューの Quit → 開き直す）。
EOT
else
cat <<'EOT'
  In System Settings > Privacy & Security, turn ON "Hammerspoon" in these three lists:
    1) Screen Recording (or "Screen & System Audio Recording")  - required to record
    2) Microphone  - for recording with your voice (macOS asks the first time)
    3) Accessibility  - to log window titles (recording works without it)
  After enabling Screen Recording, quit Hammerspoon once (menu: Quit) and open it again.
EOT
fi
if [ "$OPEN" = 1 ]; then
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
fi

step "$(T "できあがり" "Done")"
echo "  $(T "権限を入れたら ./doctor.sh で点検できます。" "After granting the permissions, run ./doctor.sh to check everything.")"
echo
if [ "$WR_JA" = 1 ]; then cat docs/USAGE.ja.md; else cat docs/USAGE.md; fi
