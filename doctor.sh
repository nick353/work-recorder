#!/bin/bash
# Work Recorder health check. Run after installing, or when something does not work. Each NG line says how to fix it.
#   ./doctor.sh
cd "$(dirname "$0")"
BASE="$(pwd)"
WR_BASE="$BASE"; . "$BASE/scripts/lang.sh"
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
HS=/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs
[ -x "$HS" ] || HS="$HOME/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"
BAD=0
ok() { printf 'OK %s\n' "$1"; }
ng() { printf 'NG %s\n   -> %s\n' "$1" "$2"; BAD=$((BAD + 1)); }
note() { printf -- '-  %s\n' "$1"; }
FIX="$(T "./install.sh を流す" "run ./install.sh")"

[ "$(uname)" = "Darwin" ] || ng "$(T "macOS ではない" "not macOS")" "$(T "macOS 専用です" "macOS only")"
{ [ -d /Applications/Hammerspoon.app ] || [ -d "$HOME/Applications/Hammerspoon.app" ]; } && ok "$(T "Hammerspoon が入っている" "Hammerspoon is installed")" || ng "$(T "Hammerspoon が無い" "Hammerspoon is missing")" "$FIX"
command -v ffmpeg >/dev/null && ok "$(T "ffmpeg が入っている" "ffmpeg is installed")" || ng "$(T "ffmpeg が無い" "ffmpeg is missing")" "$FIX"
command -v ffprobe >/dev/null && ok "ffprobe" || ng "$(T "ffprobe が無い（ffmpeg と一緒に入る）" "ffprobe is missing (comes with ffmpeg)")" "brew install ffmpeg"
[ -x .venv/bin/python ] && ok "$(T "Python の箱がある" "Python environment exists")" || ng "$(T "Python の箱が無い" "Python environment is missing")" "$FIX"
if .venv/bin/python -c "import PIL" 2>/dev/null; then ok "Pillow"; else ng "Pillow $(T "が無い" "is missing")" "$FIX"; fi
if .venv/bin/python -c "import faster_whisper" 2>/dev/null; then ok "$(T "文字起こし（faster-whisper）が使える" "transcription (faster-whisper) is available")"; else note "$(T "文字起こしは入っていない（声は録れるが文字にはならない。入れるなら ./install.sh）" "transcription is not installed (voice is recorded but not transcribed; run ./install.sh to add it)")"; fi
/usr/bin/grep -q "work-recorder" "$HOME/.hammerspoon/init.lua" 2>/dev/null && ok "$(T "Hammerspoon の設定にボタンが入っている" "button is registered in your Hammerspoon config")" || ng "$(T "Hammerspoon の設定に無い" "not registered in your Hammerspoon config")" "$FIX"

if ! pgrep -x Hammerspoon >/dev/null; then
  ng "$(T "Hammerspoon が動いていない" "Hammerspoon is not running")" "open -a Hammerspoon"
else
  ok "$(T "Hammerspoon が動いている" "Hammerspoon is running")"
  OUT="$("$HS" -t 15 -c 'return (WorkRecorder and "loaded" or "missing") .. " " .. tostring(hs.screenRecordingState()) .. " " .. tostring(hs.microphoneState and hs.microphoneState()) .. " " .. tostring(hs.accessibilityState())' 2>/dev/null | tail -1)"
  if [ -z "$OUT" ]; then
    ng "$(T "Hammerspoon に問い合わせできない" "Cannot talk to Hammerspoon")" "$(T "Hammerspoon を終了して開き直す（初回は設定の画面が出たら閉じてよい）。それでも駄目なら ./install.sh" "Quit and reopen Hammerspoon (close its preferences window if it appears). If that fails, run ./install.sh")"
  else
    set -- $OUT
    [ "$1" = "loaded" ] && ok "$(T "ボタンが読み込まれている（画面の右端にマウスを寄せると出る）" "button is loaded (move the mouse to the screen edge to see it)")" || ng "$(T "ボタンが読み込まれていない" "button is not loaded")" "$(T "Hammerspoon のコンソールに出た誤りを見る。./install.sh で入れ直す" "check the Hammerspoon console for errors, then run ./install.sh")"
    [ "$2" = "true" ] && ok "$(T "画面収録の許可あり" "Screen Recording permission granted")" || ng "$(T "画面収録の許可が無い（録画できない）" "Screen Recording permission missing (cannot record)")" "$(T "システム設定 > プライバシーとセキュリティ > 画面収録 で Hammerspoon を入にし、Hammerspoon を開き直す" "System Settings > Privacy & Security > Screen Recording: enable Hammerspoon, then quit and reopen it")"
    [ "$3" = "true" ] && ok "$(T "マイクの許可あり" "Microphone permission granted")" || note "$(T "マイクの許可がまだ（初めて声ありで録るときに聞かれる。システム設定 > マイク でも入にできる）" "Microphone permission not granted yet (macOS asks the first time you record with voice, or enable it in System Settings > Microphone)")"
    [ "$4" = "true" ] && ok "$(T "アクセシビリティの許可あり（窓の名前も記録する）" "Accessibility permission granted (window titles are logged)")" || note "$(T "アクセシビリティの許可がまだ（なくても録画はできる。窓の名前を残すなら入にする）" "Accessibility permission not granted (optional; enable it to log window titles)")"
  fi
fi
DIR="$(.venv/bin/python -c "import sys; sys.path.insert(0,'scripts'); import rec; print(rec.ROOT)" 2>/dev/null)"
note "$(T "録画の置き場" "recordings folder"): ${DIR:-~/Movies/WorkRecorder}"
[ $BAD -eq 0 ] && echo "$(T "点検おわり: 問題なし" "Check finished: no problems")" || echo "$(T "点検おわり: 直す所" "Check finished: things to fix:") ${BAD}"
exit $BAD
