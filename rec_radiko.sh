#!/bin/bash
BIN_DIR="/usr/local/bin"

LANG=ja_JP.utf8
CMDNAME="$(basename "$0")"

pid=$$
date=`date '+%Y-%m-%d-%H_%M_%S'`
#playerurl=http://radiko.jp/player/swf/player_3.0.0.01.swf
#playerurl=http://radiko.jp/player/swf/player_4.0.0.00.swf
playerurl="http://radiko.jp/apps/js/flash/myplayer-release.swf"
playerfile="$(echo "$playerurl" | gawk 'BEGIN{FS="/"}{print $NF}')"
tmpdir="/tmp"
keyfile="$tmpdir/authkey.png"
auth1file="$tmpdir/auth1_fms_${pid}"
auth2file="$tmpdir/auth2_fms_${pid}"

outdir="."

function print_channel_list()
{
  local ret=0
  if [ -x "$BIN_DIR/station_xml_dl.rb" ]; then
    "$BIN_DIR/station_xml_dl.rb" 6
    ret=$?
  else
    ./station_xml_dl.rb 6
    ret=$?
  fi
  if [ $ret -ne 0 ]; then
    echo "Station XML download error." 1>&2
    exit 1
  fi
}

function usage()
{
  cat << __EOF__ 1>&2
使い方: $CMDNAME チャンネル名 録音時間（分） [出力ディレクトリ] [Prefix]"
  チャンネル名
$(print_channel_list)
  らじるらじる公式Twitter: @nhk_radiru  https://twitter.com/nhk_radiru/with_replies

__EOF__

}

if [ $# -le 1 ]; then
  usage
  exit 1
fi

if [ $# -ge 2 ]; then
  channel=$1
  DURATION=`expr $2 \* 60`
fi
if [ $# -ge 3 ]; then
  outdir=$3
fi
PREFIX=${channel}
if [ $# -ge 4 ]; then
  PREFIX=$4
fi

#
# get player
#
function download_player_swf()
{
  local ret=0
  local tmpdir="$1"
  local file="$2"
  local url="$3"
  if [ -f "$tmpdir/$file" ]; then
    swfdump "$file" > /dev/null
    if [ $? -ne 0 ]; then
      rm -f "$tmpdir/$file"
    fi
  fi
  if [ ! -f "$tmpdir/$file" ]; then
    (cd "$tmpdir"; wget --timestamping -q "$url")
    ret=$?
    if [ $ret -ne 0 ]; then
      echo "failed get player" 1>&2
    fi
  fi
  return $ret
}

#
# get keydata (need swftool)
#
function extract_swf()
{
  local ret=0
  local tmpdir="$1"
  local swffile="$2"
  local keyfile="$3"
  if [ ! -f "$keyfile" ]; then
    swfextract -b 12 "$tmpdir/$swffile" -o "$keyfile"
    ret=$?
    if [ ! -f "$keyfile" ]; then
      echo "failed get keydata"
      exit 1
    fi
  fi
  return $ret
}

download_player_swf "$tmpdir" "$playerfile" "$playerurl"
if [ $? -ne 0 ]; then
  exit 1
fi
extract_swf "$tmpdir" "$playerfile" "$keyfile"

#
# access auth1_fms
#
if [ -f "$auth1file" ]; then
  rm -f "$auth1file"
fi
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_ts" \
     --header="X-Radiko-App-Version: 4.0.0" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --post-data='\r\n' \
     --no-check-certificate \
     --save-headers \
     -O "$auth1file" \
     https://radiko.jp/v2/api/auth1_fms

if [ $? -ne 0 ]; then
  echo "failed auth1 process"
  exit 1
fi

#
# get partial key
#
authtoken=`perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)' "$auth1file"`
offset=`perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)' "$auth1file"`
length=`perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)' "$auth1file"`

partialkey=`dd if=$keyfile bs=1 skip=${offset} count=${length} 2> /dev/null | base64`

#echo "authtoken: ${authtoken} \noffset: ${offset} length: ${length} \npartialkey: $partialkey"

rm -f "$auth1file"

if [ -f "$auth2file" ]; then
  rm -f "$auth2file"
fi

#
# access auth2_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_ts" \
     --header="X-Radiko-App-Version: 4.0.0" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --header="X-Radiko-Authtoken: ${authtoken}" \
     --header="X-Radiko-Partialkey: ${partialkey}" \
     --post-data='\r\n' \
     --no-check-certificate \
     -O "$auth2file" \
     https://radiko.jp/v2/api/auth2_fms

if [ $? -ne 0 -o ! -f "$auth2file" ]; then
  echo "failed auth2 process"
  exit 1
fi

#echo "authentication success"

areaid=`perl -ne 'print $1 if(/^([^,]+),/i)' "$auth2file"`
#echo "areaid: $areaid"

rm -f "$auth2file"

#
# get stream-url
#

if [ -f ${channel}.xml ]; then
  rm -f ${channel}.xml
fi

wget -q "http://radiko.jp/v2/station/stream/${channel}.xml"

stream_url=`echo "cat /url/item[1]/text()" | xmllint --shell ${channel}.xml | tail -2 | head -1`
url_parts=(`echo ${stream_url} | perl -pe 's!^(.*)://(.*?)/(.*)/(.*?)$/!$1://$2 $3 $4!'`)

rm -f ${channel}.xml


streaming_temp_file=`mktemp "/tmp/${channel}_${date}_XXX"`

echo "ストリーミング放送を一時ファイル $streaming_temp_file に保存します。" 1>&2

#
# rtmpdump
#
rtmpdump --quiet \
         -r ${url_parts[0]} \
         --app ${url_parts[1]} \
         --playpath ${url_parts[2]} \
         -W $playerurl \
         -C S:"" -C S:"" -C S:"" -C S:$authtoken \
         --live \
         --stop ${DURATION} \
         --flv "$streaming_temp_file"

ffmpeg -loglevel quiet -y -i "$streaming_temp_file" -acodec libmp3lame -ab 128k "${outdir}/${PREFIX}_${date}.mp3"
if [ $? -eq 0 ]; then
  rm -f "$streaming_temp_file"
fi
