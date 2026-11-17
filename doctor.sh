#!/bin/bash
# Work Recorder の点検。入れたあと・うまく動かないときに流す。× の行に直し方が出る。
#   ./doctor.sh
cd "$(dirname "$0")"
BASE="$(pwd)"
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
HS=/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs
BAD=0
ok() { printf '○ %s\n' "$1"; }
ng() { printf '× %s\n   → %s\n' "$1" "$2"; BAD=$((BAD + 1)); }

[ -d /Applications/Hammerspoon.app ] && ok "Hammerspoon が入っている" || ng "Hammerspoon が無い" "./install.sh を流す"
command -v ffmpeg >/dev/null && ok "ffmpeg が入っている" || ng "ffmpeg が無い" "./install.sh を流す"
[ -x .venv/bin/python ] && ok "Python の箱がある" || ng "Python の箱が無い" "./install.sh を流す"
if .venv/bin/python -c "import faster_whisper" 2>/dev/null; then ok "文字起こし（faster-whisper）が使える"; else echo "- 文字起こしは入っていない（声は録れるが文字にはならない。入れるなら ./install.sh）"; fi
grep -q "work-recorder" "$HOME/.hammerspoon/init.lua" 2>/dev/null && ok "Hammerspoon の設定にボタンが入っている" || ng "Hammerspoon の設定に無い" "./install.sh を流す"

if ! pgrep -x Hammerspoon >/dev/null; then
  ng "Hammerspoon が動いていない" "open -a Hammerspoon"
else
  ok "Hammerspoon が動いている"
  OUT="$("$HS" -t 15 -c 'return (WorkRecorder and "loaded" or "missing") .. " " .. tostring(hs.screenRecordingState()) .. " " .. tostring(hs.microphoneState and hs.microphoneState()) .. " " .. tostring(hs.accessibilityState())' 2>/dev/null | tail -1)"
  if [ -z "$OUT" ]; then
    ng "Hammerspoon に問い合わせできない" "Hammerspoon を終了して開き直す（初回は設定の画面が出たら閉じてよい）。それでも駄目なら ./install.sh"
  else
    set -- $OUT
    [ "$1" = "loaded" ] && ok "ボタンが読み込まれている（画面の右端にマウスを寄せると出る）" || ng "ボタンが読み込まれていない" "Hammerspoon のコンソールに出た誤りを見る。./install.sh で入れ直す"
    [ "$2" = "true" ] && ok "画面収録の許可あり" || ng "画面収録の許可が無い（録画できない）" "システム設定 > プライバシーとセキュリティ > 画面収録 で Hammerspoon を入にし、Hammerspoon を開き直す"
    [ "$3" = "true" ] && ok "マイクの許可あり" || echo "- マイクの許可がまだ（初めて声ありで録るときに聞かれる。システム設定 > マイク でも入にできる）"
    [ "$4" = "true" ] && ok "アクセシビリティの許可あり（窓の名前も記録する）" || echo "- アクセシビリティの許可がまだ（なくても録画はできる。窓の名前を残すなら入にする）"
  fi
fi
DIR="$(.venv/bin/python -c "import sys; sys.path.insert(0,'scripts'); import rec; print(rec.ROOT)" 2>/dev/null)"
echo "- 録画の置き場: ${DIR:-~/Movies/作業録画}"
[ $BAD -eq 0 ] && echo "点検おわり: 問題なし" || echo "点検おわり: 直す所 ${BAD}件"
exit $BAD
