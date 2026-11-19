# Sourced by install.sh / doctor.sh / uninstall.sh. Sets WR_JA=1 when the UI should be Japanese.
# Order: config.json "ui_language" -> the Mac's first preferred language -> $LANG.
WR_JA=0
_wr_lang=""
_wr_cfg="${WR_BASE:-.}/config.json"
if [ -f "$_wr_cfg" ]; then
  _wr_lang="$(sed -n 's/.*"ui_language"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$_wr_cfg" | head -1)"
fi
case "$_wr_lang" in ja|en) ;; *) _wr_lang="" ;; esac
if [ -z "$_wr_lang" ]; then
  _wr_lang="$(defaults read -g AppleLanguages 2>/dev/null | tr -d '() ",' | /usr/bin/grep -v '^ *$' | head -1 | head -c2)"
  [ -z "$_wr_lang" ] && _wr_lang="$(printf '%s' "${LANG:-en}" | head -c2)"
fi
[ "$_wr_lang" = "ja" ] && WR_JA=1
# T "日本語" "English"
T() { if [ "$WR_JA" = 1 ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }
