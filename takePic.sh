#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
timestamp=$(date +"%y%m%d%H%M")
date=$(date +"%y%m%d")
destination="$DIR/archive/photo/$date"
minute=$(date +"%-M")

source $DIR/config.cfg
source $DIR/v4l2.cfg

if [ ! -d $destination ]; then
    mkdir -p $destination
fi

filename=$destination/$timestamp.jpg

failed_pics=0
while [ $failed_pics -lt 5 ]; do
   ERROR_FILE=/tmp/ffmpeg${timestamp}
   { ffmpeg -f video4linux2 -s $RESOLUTION -i /dev/video0 -ss 0:0:5 -frames 1 $filename > $ERROR_FILE.log 2>&1 ; echo "$?" > $ERROR_FILE.response ; } &
   pid=$!
   sleep 10
   kill -9 $pid > /dev/null 2>&1
   status=$?
   if [ $status -eq 0 ]; then 
      OUT=124
      ERROR=''
   else
      OUT=`cat $ERROR_FILE.response`
      ERROR=`cat $ERROR_FILE.log`
      rm $ERROR_FILE.log $ERROR_FILE.response
   fi

   if [ $OUT -ne 0 ]; then
      if [ -f $filename ]; then
         rm $filename
      fi

      if [ $OUT -eq 124 ]; then
         echo "Capture timed out"
      elif [[ "$ERROR" == *"Input/output error" ]]; then
         # Root cron runs script every minute which looks for /tmp/reboot.now
         # If file is found, system is rebooted
         echo "Input/output error, rebooting"
         echo REBOOT > /tmp/reboot.now
         exit $OUT
      elif [[ "$ERROR" == *"Device or resource busy" ]]; then
         echo "Device or resource busy"
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
