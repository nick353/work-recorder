#!/bin/bash
# 作業録画の下ごしらえ（録画を止めたあとに recorder.lua が裏で呼ぶ）。
#   ingest.sh <録画のフォルダ> [--no-voice]
# 1) raw.mov（Retina・60コマ/秒で30分約1GB）を recording.mp4（幅1440・10コマ/秒）に縮め、元は消す。
#    声は rec-run.sh が voice.m4a に別に録っているので、ここで映像と合わせる。
# 2) prep.py でコマ一覧・文字起こし・MANIFEST.md を作る（AI が読む入口）。
# 3) meta.json を「未相談」にする。外へは何も送らない。
set -u
DIR="$1"; shift || true
VOICE=1
[ "${1:-}" = "--no-voice" ] && VOICE=0
PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
BASE="$(cd "$(dirname "$0")/.." && pwd)"
PY="$BASE/.venv/bin/python"
[ -x "$PY" ] || PY="$(command -v python3)"
LOG="$DIR/ingest.log"
exec >>"$LOG" 2>&1
echo "== $(date '+%F %T') 下ごしらえ開始"

RAW="$DIR/raw.mov"
MP4="$DIR/recording.mp4"
if [ -f "$RAW" ]; then
  IN=(-i "$RAW"); MAP=(-map 0:v:0); AUDIO=(-an)
  if [ -s "$DIR/voice.m4a" ]; then
    # 声は録画より先に始まり、ほぼ同時に終わる。長さの差だけ声の頭を切ってそろえる
    VD=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW")
    AD=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$DIR/voice.m4a")
    SKIP=$("$PY" -c "print(max(0.0, round(float('${AD:-0}' or 0) - float('${VD:-0}' or 0), 2)))")
    echo "声の頭を ${SKIP}秒 切ってそろえる（録画 ${VD}秒・声 ${AD}秒）"
    IN+=(-ss "$SKIP" -i "$DIR/voice.m4a"); MAP+=(-map 1:a:0); AUDIO=(-c:a aac -b:a 64k -ac 1 -shortest)
  else
    VOICE=0
  fi
  if nice -n 15 ffmpeg -nostdin -y -loglevel error "${IN[@]}" "${MAP[@]}" -vf "scale=1440:-2,fps=10" \
      -c:v libx264 -preset veryfast -crf 30 -pix_fmt yuv420p "${AUDIO[@]}" -movflags +faststart "$MP4"; then
    rm -f "$RAW" "$DIR/voice.m4a"
  else
    echo "縮める段で失敗。raw.mov を残して続ける"
    MP4="$RAW"
  fi
fi
[ -f "$MP4" ] || { echo "録画のファイルが無い"; exit 1; }

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$MP4" | cut -d. -f1)
DUR=${DUR:-0}
PREP_ARGS=("$DIR" --video "$MP4")
[ "$VOICE" = 0 ] && PREP_ARGS+=(--no-speech)
nice -n 15 "$PY" "$BASE/scripts/prep.py" "${PREP_ARGS[@]}" || echo "prep.py で失敗（録画は残っている）"

"$PY" "$BASE/scripts/rec.py" finish "$DIR" --duration "$DUR"
echo "== $(date '+%F %T') 終わり（${DUR}秒）"
