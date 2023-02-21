#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

make_command="/usr/bin/screen -dmS make-timelapse ${DIR}/make.sh"

tomorrow=$(date --date='tomorrow' +"%Y-%m-%d")

url="http://api.sunrise-sunset.org/json?date=$tomorrow&lat=$SUNRISE_SUNSET_LATITUDE&lng=$SUNRISE_SUNSET_LONGITUDE"
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


IFS=':' read sunset_hour sunset_minute <<< "$sunset"
sunset_hour=$((sunset_hour+12))
sunset_minute=$((10#$sunset_minute))
echo $sunset_minute
sunset_minute=$((sunset_minute+SUNRISE_SUNSET_BUFFER_MINUTES+SUNSET_EXTRA_BUFFER_MINUTES))
echo $sunset_minute
sunset_minute=$(echo "($sunset_minute + 9) / 10 * 10" | bc)
echo $sunset_minute
if ((sunset_minute > 59)); then
    sunset_minute=$((sunset_minute-60))
    sunset_hour=$((sunset_hour+1))
fi

cron_hour_start=$((sunrise_hour+1))
cron_hour_end=$((sunset_hour-1))

sunrise_cron="$sunrise_minute-59/10 $sunrise_hour * * * $make_command #SUNRISE_COMMAND"
sunset_cron="0-$sunset_minute/10 $sunset_hour * * * $make_command #SUNSET_COMMAND"
range_cron="*/10 $cron_hour_start-$cron_hour_end * * * $make_command #RANGE_COMMAND"

cron=$(crontab -l)
cron=$(sed "s,.*#SUNRISE_COMMAND$,$sunrise_cron,g" <<< "$cron")
cron=$(sed "s,.*#RANGE_COMMAND$,$range_cron,g" <<< "$cron")
cron=$(sed "s,.*#SUNSET_COMMAND$,$sunset_cron,g" <<< "$cron")

echo "$cron" | crontab -
