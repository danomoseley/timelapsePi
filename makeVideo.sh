#!/bin/bash

die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "1 argument required, $# provided"
echo $1 | grep -E -q '^[0-9]+$' || die "Numeric argument required, $1 provided"

DIR=$(cd $(dirname $0); pwd -P)
date=$(date +"%y%m%d")
timestamp=$(date +"%y%m%d%H%M%S")
path="$DIR/archive/$date"
destination="$DIR/timelapse"
temp_folder=$destination/$timestamp

minutes=$1

if [ ! -d $destination ]; then
    mkdir $destination
fi

if [ ! -d $temp_folder ]; then
    mkdir $temp_folder
fi

i=0

find $path/*-ae3.jpg -mmin -$minutes -type f | while read f; do
    padded_i=`printf %05d $i`
    ln -sf "$f" "$temp_folder/$padded_i.jpg"
    i=$((i+1))
done

filepath=$destination/$timestamp-$minutes.mp4

#mencoder mf://$temp_folder/*.jpg -nosound -o $filepath -vf scale=480:-10,harddup -lavfopts format=mp4 -faacopts mpeg=4:object=2:raw:br=128 -oac faac -ovc x264 -sws 9 -x264encopts nocabac:level_idc=30:bframes=0:global_header:threads=auto:subq=5:frameref=6:partitions=all:trellis=1:chroma_me:me=umh:bitrate=500 -of lavf -mf fps=12

rm -R $temp_folder

echo $filepath
