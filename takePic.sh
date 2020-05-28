#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
timestamp=$(date +"%y%m%d%H%M")
date=$(date +"%y%m%d")
minute=$(date +"%-M")
destination="$DIR/archive/photo/$date"

reboot () {
   # Root cron runs script every minute which looks for /tmp/reboot.now
   # If file is found, system is rebooted
   echo "Input/output error, rebooting"
   echo REBOOT > /tmp/reboot.now
   exit $1
}

floatToInt() {
   printf "%.0f\n" "$@"
}
source $DIR/config.cfg
v4l2-ctl -d /dev/video0 --set-ctrl="focus_auto=0"
v4l2-ctl -d /dev/video0 --set-ctrl="focus_absolute=0"
v4l2-ctl -d /dev/video0 --set-ctrl="exposure_auto_priority=0"
v4l2-ctl -d /dev/video0 --set-ctrl="exposure_auto=1"
exposure_absolute=$EXPOSURE_ABSOLUTE
white_balance_temperature=4300

while true; do
    v4l2-ctl -d /dev/video0 --set-ctrl="exposure_absolute=$exposure_absolute"
    val=$(v4l2-ctl -d /dev/video0 --get-ctrl="exposure_absolute" | awk '{ print $2 }')
    if [[ $val -eq $exposure_absolute ]]; then
        break
    fi
done
v4l2-ctl -d /dev/video0 --set-ctrl="brightness=128"
v4l2-ctl -d /dev/video0 --set-ctrl="contrast=128"
v4l2-ctl -d /dev/video0 --set-ctrl="saturation=128"
v4l2-ctl -d /dev/video0 --set-ctrl="white_balance_temperature_auto=0"

while true; do
    v4l2-ctl -d /dev/video0 --set-ctrl="white_balance_temperature=$white_balance_temperature"
    val=$(v4l2-ctl -d /dev/video0 --get-ctrl="white_balance_temperature" | awk '{ print $2 }')
    if [[ $val -eq $white_balance_temperature ]]; then
        break
    fi
done
v4l2-ctl -d /dev/video0 --set-ctrl="backlight_compensation=0"
v4l2-ctl -d /dev/video0 --set-ctrl="sharpness=128"
v4l2-ctl -d /dev/video0 --set-ctrl="gain=0"

if [ $? -ne 0 ]; then
    reboot 1
fi

if [ ! -d $destination ]; then
    mkdir -p $destination
fi

filename=$destination/$timestamp.jpg

failed_pics=0
while [ $failed_pics -lt 3 ]; do
    ERROR_FILE=/tmp/ffmpeg${timestamp}
    delay_seconds=$(( 10 + $failed_pics ))
    { ffmpeg -y -f video4linux2 -s $RESOLUTION -i /dev/video0 -ss 0:0:${delay_seconds} -frames 1 $filename > $ERROR_FILE.log 2>&1 ; echo "$?" > $ERROR_FILE.response ; } &
    sleep 15
    killall -q ffmpeg
    if [ $? -eq 0 ]; then
        OUT=124
        ERROR=''
    else
        if [ -f "$ERROR_FILE.response" ]; then
            OUT=`cat $ERROR_FILE.response`
            rm $ERROR_FILE.response
        else
            OUT=999
        fi
        if [ -f "$ERROR_FILE.log" ]; then
            ERROR=`cat $ERROR_FILE.log`
            rm $ERROR_FILE.log
        else
            ERROR='Error file not found'
        fi
    fi

    if [ $OUT -ne 0 ]; then
        if [ -f $filename ]; then
            rm $filename
        fi

        if [ $OUT -eq 124 ]; then
            # echo "Capture timed out"
            :
        elif [[ "$ERROR" == *"Device or resource busy" ]]; then
            # echo "Device or resource busy"
            :
        elif [[ "$ERROR" == *"Input/output error" ]]; then
            reboot $OUT
        else
            echo $ERROR
        fi
    else
        file_size=$(wc -c <"$filename")
        if [ $file_size -le $MINIMUM_FILE_SIZE ]; then
            rm $filename
        else
            img_brightness=$(convert "$filename" -colorspace gray -format "%[fx:100*mean]" info:)
            img_brightness=$(printf "%.0f" "$img_brightness")
            min_brightness=$(($TARGET_BRIGHTNESS-5))
            max_brightness=$(($TARGET_BRIGHTNESS+5))
            previous_exposure_absolute=$exposure_absolute
            if [ $img_brightness -ge $max_brightness ] && [ $exposure_absolute -ge 4 ]; then
                exposure_absolute=$(($exposure_absolute-1))
                sed -i "s/\(EXPOSURE_ABSOLUTE *= *\).*/\1$exposure_absolute/" $DIR/config.cfg
            elif [ $img_brightness -le $min_brightness ] && [ $exposure_absolute -le 30 ]; then
                exposure_absolute=$(($exposure_absolute+1))
                sed -i "s/\(EXPOSURE_ABSOLUTE *= *\).*/\1$exposure_absolute/" $DIR/config.cfg
            fi
            printf "Image brightness: ${img_brightness}\nExposure setting: ${exposure_absolute}\nPrevious exposure: ${previous_exposure_absolute}\nTarget brightness: ${TARGET_BRIGHTNESS}\nMax brightness: ${max_brightness}\nMin brightness: ${min_brightness}"

            v4l2-ctl -l > $destination/$timestamp.txt
            /home/pi/.local/bin/aws s3 cp --quiet $filename s3://camp.danomoseley.com/latest_pic.jpg --expires "$(date -d '+1 minute' --utc +'%Y-%m-%dT%H:%M:%SZ')"
            convert "$filename" -thumbnail 600 - | /home/pi/.local/bin/aws s3 cp --quiet - s3://camp.danomoseley.com/latest_pic_thumb.jpg --expires "$(date -d '+1 minute' --utc +'%Y-%m-%dT%H:%M:%SZ')"

            /home/pi/.local/bin/aws s3 cp --quiet $filename "s3://camp.danomoseley.com/archive/photo/$date/$timestamp.jpg"
            disk_usage=$( df -h | grep '/dev/root' | awk {'print $5'} | sed 's/%//' )
            if [ $disk_usage -ge 90 ]; then
                echo "Disk space $disk_usage%"
            fi
            if [[ $((10#$minute % $PIC_SYNC_INTERVAL)) -eq 0 || $1 -eq $minute ]]; then
                #nice -n 19 scp -pr $filename $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/latest_pic.jpg
                source $DIR/backupArchive.sh
            fi
            exit 0
        fi
    fi
    failed_pics=$(( $failed_pics + 1 ))
    sleep 5
done
echo "No valid pics after 5 attempts"
reboot $OUT

