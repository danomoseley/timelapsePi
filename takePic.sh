#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
timestamp=$(date +"%y%m%d%H%M")
date=$(date +"%y%m%d")
destination="$DIR/archive/photo/$date"
minute=$(date +"%-M")

reboot () {
   # Root cron runs script every minute which looks for /tmp/reboot.now
   # If file is found, system is rebooted
   echo "Input/output error, rebooting"
   echo REBOOT > /tmp/reboot.now
   exit $1
}

source $DIR/config.cfg
v4l2-ctl --set-ctrl=${V4L2_CTRL_CONFIG}
if [ $? -ne 0 ]; then
    reboot 1
fi

if [ ! -d $destination ]; then
    mkdir -p $destination
fi

filename=$destination/$timestamp.jpg

failed_pics=0
while [ $failed_pics -lt 5 ]; do
   ERROR_FILE=/tmp/ffmpeg${timestamp}
   delay_seconds=$(( 5 + $failed_pics ))
   { ffmpeg -y -f video4linux2 -s $RESOLUTION -i /dev/video0 -ss 0:0:${delay_seconds} -frames 1 $filename > $ERROR_FILE.log 2>&1 ; echo "$?" > $ERROR_FILE.response ; } &
   sleep 10
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
         if [[ $((10#$minute % $PIC_SYNC_INTERVAL)) -eq 0 || $1 -eq $minute ]]
         then
            scp -pr $filename $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/latest_pic.jpg
            source $DIR/backupArchive.sh
         fi
         exit 0
      fi
   fi
   failed_pics=$(( $failed_pics + 1 ))
   sleep 5
done
echo "No valid pics after 5 attempts"
