#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

date=$(date +"%y%m%d")
if [ ! -z "$1" ]; then
    date=$1
fi
path="$DIR/archive/photo/$date"
destination="$DIR/archive/timelapse"
temp_folder=/tmp/$date

if [ ! -d $destination ]; then
    mkdir -p $destination
fi

if [ ! -d $temp_folder ]; then
    mkdir $temp_folder
fi

i=0
for f in $path/*-ae3.jpg
do
    padded_i=`printf %05d $i`
    ln -s "$f" "$temp_folder/$padded_i.jpg"
    i=$((i+1))
done

ERROR="$(mencoder mf://$temp_folder/*.jpg -nosound -o /tmp/$date.mp4 -vf scale=480:-10,harddup -lavfopts format=mp4 -faacopts mpeg=4:object=2:raw:br=128 -oac faac -ovc x264 -sws 9 -x264encopts nocabac:level_idc=30:bframes=0:global_header:threads=auto:subq=5:frameref=6:partitions=all:trellis=1:chroma_me:me=umh:bitrate=500 -of lavf -mf fps=12 2>&1 > /dev/null)"

rm -R $temp_folder

OUT=$?
if [ $OUT -ne 0 ];then
    echo ERROR
    rm /tmp/$date.mp4
    exit $OUT
else
    mv /tmp/$date.mp4 $destination
    scp -pr $destination/$date.mp4 $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/latest_vid.mp4
fi
