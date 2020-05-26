#!/bin/bash

die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -gt 0 ] || die "1 argument required, $# provided"

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

date=$(date +"%y%m%d")
if [ ! -z "$2" ]; then
    date=$2
fi
timestamp=$(date +"%y%m%d%H%M%S")
path="$DIR/archive/photo/$date"
temp_folder=/tmp/$timestamp

if [ $1 = "hourly" ]; then
    destination="$DIR/archive/timelapse/hourly/$date"
    date_hour=$(date +"%y%m%d%H")
    filename=$date_hour.mp4
    minutes=60
elif [ $1 = "daily" ]; then
    destination="$DIR/archive/timelapse"
    filename=$date.mp4
    minutes=720
else
    die "First argument must be one of hourly or daily"
fi

if [ ! -d $destination ]; then
    mkdir -p $destination
fi

if [ ! -d $temp_folder ]; then
    mkdir $temp_folder
fi

i=0
find $path/*.jpg -mmin -$minutes -type f | while read f; do
    padded_i=`printf %05d $i`
    ln -sf "$f" "$temp_folder/$padded_i.jpg"
    i=$((i+1))
done

ERROR="$(nice -n 19 mencoder mf://$temp_folder/*.jpg -nosound -o /tmp/$filename -vf scale=1280:-10,harddup -lavfopts format=mp4 -oac mp3lame -ovc x264 -sws 9 -x264encopts nocabac:level_idc=30:bframes=0:global_header:threads=auto:subq=5:frameref=6:partitions=all:trellis=1:chroma_me:me=umh:bitrate=500 -of lavf -mf fps=12 2>&1 > /dev/null)"
OUT=$?

rm -R $temp_folder

if [ $OUT -ne 0 ];then
    echo $ERROR
    rm /tmp/$filename
    exit $OUT
else
    mv /tmp/$filename $destination
    scp -pr $destination/$filename $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/latest_vid.mp4
fi
