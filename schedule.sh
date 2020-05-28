#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

command="$DIR/takePic.sh"
schedule_command="$DIR/schedule.sh"

tomorrow=$(date --date='tomorrow' +"%Y-%m-%d")

url="https://api.sunrise-sunset.org/json?date=$tomorrow&lat=$SUNRISE_SUNSET_LATITUDE&lng=$SUNRISE_SUNSET_LONGITUDE"
result=$(curl -s $url)

sunrise=$(echo $result | jq '.results.sunrise')
sunrise=${sunrise:1:-1}
sunrise=$(date -d "$sunrise UTC" +%-I:%M)

sunset=$(echo $result | jq '.results.sunset')
sunset=${sunset:1:-1}
sunset=$(date -d "$sunset UTC" +%-I:%M)

echo "Sunrise: ${sunrise}am"
echo "Sunset: ${sunset}pm"

IFS=':' read sunrise_hour sunrise_minute <<< "$sunrise"
sunrise_hour=$((10#$sunrise_hour))
sunrise_minute=$((10#$sunrise_minute))
sunrise_minute=$((sunrise_minute-SUNRISE_SUNSET_BUFFER_MINUTES))
if ((sunrise_minute < 0)); then
    sunrise_minute=$((60+sunrise_minute))
    sunrise_hour=$((sunrise_hour-1))	
fi

cron_hour_start=$((sunrise_hour+1))

IFS=':' read sunset_hour sunset_minute <<< "$sunset"
sunset_hour=$((sunset_hour+12))
sunset_minute=$((10#$sunset_minute))
sunset_minute=$((sunset_minute+SUNRISE_SUNSET_BUFFER_MINUTES))
if ((sunset_minute > 59)); then
    sunset_minute=$((sunset_minute-60))
    sunset_hour=$((sunset_hour+1))
fi


cron_hour_end=$((sunset_hour-1))

sunrise_cron="$sunrise_minute-59 $sunrise_hour * * * $command $sunrise_minute #SUNRISE_COMMAND"
range_cron="* $cron_hour_start-$cron_hour_end * * * $command #RANGE_COMMAND"
sunset_cron="0-$sunset_minute $sunset_hour * * * $command $sunset_minute #SUNSET_COMMAND"
schedule_cron="$sunset_minute $sunset_hour * * * $schedule_command #SCHEDULE_COMMAND"

cron=$(crontab -l)
cron=$(sed "s,.*#SUNRISE_COMMAND$,$sunrise_cron,g" <<< "$cron")
cron=$(sed "s,.*#RANGE_COMMAND$,$range_cron,g" <<< "$cron")
cron=$(sed "s,.*#SUNSET_COMMAND$,$sunset_cron,g" <<< "$cron")
cron=$(sed "s,.*#SCHEDULE_COMMAND$,$schedule_cron,g" <<< "$cron")

timezone=$(date +%Z)
expires_sunrise=$(date -d "$tomorrow $sunrise_hour:$sunrise_minute $timezone" --utc +'%Y-%m-%dT%H:%M:%SZ')

/home/pi/.local/bin/aws s3 cp --quiet "$DIR/black.jpg" s3://camp.danomoseley.com/latest_pic.jpg --expires "$expires_sunrise"

echo "$cron" | crontab -

source $DIR/weather.sh

