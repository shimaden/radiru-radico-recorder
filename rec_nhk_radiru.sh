#!/bin/bash
#
# ９月初旬からNHKネットラジオ（らじる）の配信方法が
# 変更になっている。これまでのRTMPをベースとした配信
# に代え、HLS(HTTP Live Streaming)をベースとするもの
# に変更された。
#
# 参考: https://memorandum.yamasnet.com/archives/Post-18550.html
#
# 録音コマンド（m4a）
#   ffmpeg -i M3U8URL -c copy outputfilename.m4a
#   ファイルサイズ的に m4a が最も小さくなる
#   m4a ファイルのときだけ "-c copy" オプションが使える。
#
# 録音コマンド（mp3）
#   ffmpeg -i M3U8URL -write_xing 0 outputfilename.mp3 
#   Mac かつ保存形式が mp3 ファイルの場合には、ファイルの
#   時間表示を正しくさせるために "-write_xing 0" オプション必須。
#   （参考： https://trac.ffmpeg.org/ticket/2697 ）
#
# 参考: https://gist.github.com/riocampos/93739197ab7c765d16004cd4164dca73

CMDNAME="$(basename $0)"

function usage()
{
  cat <<  __EOF__ 1>&2

使い方
  $CMDNAME NHKR1|NHKR2|NHKFM 録音時間（分） [出力DIR] [Prefix]"

__EOF__
}

if [ $# -lt 2 -o $# -gt 4 ]; then
  usage
  exit 1
fi

DATE="$(date '+%Y%m%d_%H%M')"

STATION="$1"
DURATION="$(expr $2 \* 60)"

if [ -z "$3" ]; then
  OUTDIR="$PWD"
else
  OUTDIR="$3"
fi
if [ -z "$4" ]; then
  PREFIX=""
else
  PREFIX="$4"
fi

EXT="mp3"
OUT_FNAME="$OUTDIR/$PREFIX${STATION}_$DATE.$EXT"


if [ "$STATION" = "NHKR1" ]; then
   STREAM_URL="https://nhkradioakr1-i.akamaihd.net/hls/live/511633/1-r1/1-r1-01.m3u8"
elif [ "$STATION" = "NHKR2" ]; then
   STREAM_URL="https://nhkradioakr2-i.akamaihd.net/hls/live/511929/1-r2/1-r2-01.m3u8"
elif [ "$STATION" = "NHKFM" ]; then
   STREAM_URL="https://nhkradioakfm-i.akamaihd.net/hls/live/512290/1-fm/1-fm-01.m3u8"
else
  echo "誤った放送局名: \"$STATION\"放送局名は NHKR1|NHKR2|NHKFM のみです。" 1>&2
  exit 1
fi

#ffmpeg -i "$STREAM_URL" -t $DURATION -write_xing 0 "$PWD/${STATION}_$DATE.mp3"
ffmpeg -i "$STREAM_URL" -t $DURATION -write_xing 0 "$OUT_FNAME"
