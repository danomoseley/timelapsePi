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
while [ $failed_pics -lt 5 ]
do
   ERROR="$(ffmpeg -f video4linux2 -s $RESOLUTION -i /dev/video0 -ss 0:0:5 -frames 1 $filename 2>&1 > /dev/null)"

   OUT=$?
   if [ $OUT -ne 0 ]
   then
      rm $filename

      echo $ERROR
      if [[ "$ERROR" == *"Input/output error" ]] || [[ "$ERROR" == *"Device or resource busy" ]]
      then
         # Root cron runs script every minute which looks for /tmp/reboot.now
         # If file is found, system is rebooted
         echo REBOOT > /tmp/reboot.now
      fi
      exit $OUT
   else
      file_size=$(wc -c <"$filename")
      if [ $file_size -le $MINIMUM_FILE_SIZE ]
      then
         rm $filename
         failed_pics=$(( $failed_pics + 1 ))
      else
         if [[ $((10#$minute % $PIC_SYNC_INTERVAL)) -eq 0 || $1 -eq $minute ]]
         then
            scp -pr $filename $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/latest_pic.jpg
         fi
         exit 0
      fi
   fi
done
echo "No valid pics after 5 attempts"
