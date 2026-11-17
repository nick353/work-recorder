#!/bin/bash
# Work Recorder を外す。録画そのもの（~/Movies/作業録画 など）は消さない。
#   ./uninstall.sh
cd "$(dirname "$0")"
INIT="$HOME/.hammerspoon/init.lua"
if [ -f "$INIT" ]; then
  TMP="$(mktemp)"
  awk '/^-- >>> work-recorder >>>/{skip=1} !skip{print} /^-- <<< work-recorder <<</{skip=0}' "$INIT" > "$TMP" && mv "$TMP" "$INIT"
  echo "○ Hammerspoon の設定からボタンを外した"
fi
for d in "$HOME/.claude/skills/work-recorder" "$HOME/.codex/skills/work-recorder"; do
  [ -d "$d" ] && rm -r "$d" && echo "○ $d を外した"
done
pgrep -x Hammerspoon >/dev/null && ( /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -t 5 -c 'hs.reload()' >/dev/null 2>&1 & )
echo "録画は残しています。要らなければ Finder で録画のフォルダを消してください。"
echo "Hammerspoon・ffmpeg も残しています（brew uninstall --cask hammerspoon / brew uninstall ffmpeg で消せます）。"
