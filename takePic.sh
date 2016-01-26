#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
timestamp=$(date +"%y%m%d%H%M%S")
date=$(date +"%y%m%d")
destination="$DIR/archive/$date"

source $DIR/config.cfg
source $DIR/v4l2.cfg

if [ ! -d $destination ]; then
    mkdir $destination
fi

filename=$destination/$timestamp-ae3.jpg
ERROR="$(ffmpeg -f video4linux2 -s $RESOLUTION -i /dev/video0 -ss 0:0:5 -frames 1 $filename 2>&1 > /dev/null)"

OUT=$?
if [ $OUT -ne 0 ];then
   rm $filename

   echo $ERROR | mutt -e "set content_type=text/html" -e "set realname = \"$EMAIL_REAL_NAME\"" -e "set smtp_url = \"$SMTP_URL\"" -e "set smtp_pass = \"$SMTP_PASS\"" -e "set from = \"$FROM_EMAIL\"" -s "$EMAIL_SUBJECT" -- $TO_EMAIL
   if [[ "$ERROR" == *"Input/output error" ]] || [[ "$ERROR" == *"Device or resource busy" ]]
   then
      # Root cron runs script every minute which looks for /tmp/reboot.now
      # If file is found, system is rebooted
      echo REBOOT > /tmp/reboot.now
   fi
   exit $OUT
else
   scp -pr $filename $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/latest_pic.jpg
fi

