#!/bin/bash
# screencapture -v を、止めの合図が来るまで動かし続ける中継（recorder.lua が起動する）。
#   rec-run.sh <録画のフォルダ> [--mic <マイクの名前>] <screencapture の引数...>
# - screencapture -v は「入力に文字が来たら止める」作りで、入力が閉じていると起動してすぐ止まる
#   （hs.task から直接起動すると 0.1 秒の録画になった）。名前つきの管を開けたままにし、
#   フォルダに .stop ができたら文字を1つ送って止める。ctrl-c（SIGINT）で止めると動画が壊れる。
# - 声は screencapture -g だと 0.05 秒の動画になる（2026-11-17 実測。声なしは正常）。そこで声は ffmpeg で
#   voice.m4a に別に録り、ingest.sh が映像と合わせる。
set -u
DIR="$1"; shift
MIC=""
if [ "${1:-}" = "--mic" ]; then MIC="$2"; shift 2; fi
PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
FIFO="$DIR/.ctl"
# .stop は消さない（Mac が重いと起動より先に押され、ここで消すと二度と止まらなくなる。フォルダは毎回新しい）
rm -f "$FIFO"
mkfifo "$FIFO"
APID=""
if [ -n "$MIC" ]; then
  # ":default" は既定のマイク（名前は言語の設定で変わるので使わない）
  ffmpeg -nostdin -hide_banner -loglevel error -f avfoundation -i ":default" -ac 1 -c:a aac -b:a 64k "$DIR/voice.m4a" 2>>"$DIR/voice.log" &
  APID=$!
  # screencapture と同時に起動すると声の側が固まって何も書かない（2026-11-17 実測）。書き始めを待ってから録画へ
  for _ in $(seq 1 40); do { [ -s "$DIR/voice.m4a" ] || [ -f "$DIR/.stop" ]; } && break; sleep 0.25; done
fi
/usr/sbin/screencapture "$@" < "$FIFO" &
PID=$!
exec 3>"$FIFO"
START=$(date +%s)
SENT=0
while kill -0 "$PID" 2>/dev/null; do
  # 止めの合図か、3時間の上限（押し忘れでディスクを埋めない）。
  # 起動の直後に押されると、screencapture が受け取る用意の前で文字を取りこぼし、止まらなかった
  # 止まるまで1秒ごとに送り直す
  if [ -f "$DIR/.stop" ] || [ $(( $(date +%s) - START )) -ge 10800 ]; then
    if [ $(( SENT % 4 )) -eq 0 ]; then printf 'q' >&3; fi
    SENT=$((SENT + 1))
  fi
  sleep 0.25
done
wait "$PID"
CODE=$?
# ffmpeg は SIGTERM で書き終えて閉じる（裏の仕事なので SIGINT は効かない）
if [ -n "$APID" ]; then kill -TERM "$APID" 2>/dev/null; wait "$APID" 2>/dev/null; fi
exec 3>&-
rm -f "$FIFO" "$DIR/.stop"
exit $CODE
