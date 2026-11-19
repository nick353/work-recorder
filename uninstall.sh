#!/bin/bash
# Remove Work Recorder. Your recordings themselves are NOT deleted.
#   ./uninstall.sh
cd "$(dirname "$0")"
WR_BASE="$(pwd)"; . "$WR_BASE/scripts/lang.sh"
INIT="$HOME/.hammerspoon/init.lua"
if [ -f "$INIT" ]; then
  TMP="$(mktemp)"
  awk '/^-- >>> work-recorder >>>/{skip=1} !skip{print} /^-- <<< work-recorder <<</{skip=0}' "$INIT" > "$TMP" && mv "$TMP" "$INIT"
  echo "OK $(T "Hammerspoon の設定からボタンを外した" "removed the button from your Hammerspoon config")"
fi
for d in "$HOME/.claude/skills/work-recorder" "$HOME/.codex/skills/work-recorder"; do
  [ -d "$d" ] && rm -r "$d" && echo "OK $(T "外した" "removed") $d"
done
HS=/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs
[ -x "$HS" ] || HS="$HOME/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"
pgrep -x Hammerspoon >/dev/null && ( "$HS" -t 5 -c 'hs.reload()' >/dev/null 2>&1 & )
echo "$(T "録画は残しています。要らなければ Finder で録画のフォルダ（config.json の recordings_dir）を消してください。" "Your recordings are kept. Delete the recordings folder (recordings_dir in config.json) in Finder if you no longer need it.")"
echo "$(T "Hammerspoon・ffmpeg も残しています（brew uninstall --cask hammerspoon / brew uninstall ffmpeg で消せます）。" "Hammerspoon and ffmpeg are kept (remove with: brew uninstall --cask hammerspoon / brew uninstall ffmpeg).")"
