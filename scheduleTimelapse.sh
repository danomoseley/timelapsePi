#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

make_command="/usr/bin/screen -dmS make-timelapse ${DIR}/make.sh"
SUNSET_EXTRA_BUFFER_MINUTES=${SUNSET_EXTRA_BUFFER_MINUTES:-0}

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
sunrise_range_start_hour=$sunrise_hour
sunrise_minute=$((10#$sunrise_minute))
sunrise_range_start_minute=$((sunrise_minute-SUNRISE_SUNSET_BUFFER_MINUTES))
if ((sunrise_range_start_minute < 0)); then
    sunrise_range_start_minute=$((60+sunrise_range_start_minute))
    sunrise_range_start_hour=$((sunrise_range_start_hour-1))	
fi


IFS=':' read sunset_hour sunset_minute <<< "$sunset"
sunset_hour=$((sunset_hour+12))
sunset_range_end_hour=$sunset_hour
sunset_minute=$((10#$sunset_minute))
sunset_minute_with_buffer=$((sunset_minute+SUNRISE_SUNSET_BUFFER_MINUTES-10))
sunset_range_end_minute=$sunset_minute_with_buffer
sunset_range_end_minute=$(echo "($sunset_range_end_minute + 9) / 10 * 10" | bc)

if [ "$sunset_range_end_minute" -eq "$sunset_minute_with_buffer" ]; then
    sunset_range_end_minute=$((sunset_range_end_minute+10))
fi

if ((sunset_range_end_minute > 59)); then
    sunset_range_end_minute=$((sunset_range_end_minute-60))
    sunset_range_end_hour=$((sunset_range_end_hour+1))
fi

sunset_finale_minute=$((sunset_range_end_minute+10))
sunset_finale_hour=$sunset_range_end_hour
if ((sunset_finale_minute > 59)); then
    sunset_finale_minute=$((sunset_finale_minute-60))
    sunset_finale_hour=$((sunset_finale_hour+1))
fi

range_hour_start=$((sunrise_range_start_hour+1))
range_hour_end=$((sunset_range_end_hour-1))

sunrise_range_cron="$sunrise_range_start_minute-59/10 $sunrise_range_start_hour * * * $make_command #SUNRISE_RANGE_COMMAND"
sunset_range_cron="0-$sunset_range_end_minute/10 $sunset_range_end_hour * * * $make_command #SUNSET_RANGE_COMMAND"
sunset_finale_cron="$sunset_finale_minute $sunset_finale_hour * * * $make_command sunset #SUNSET_FINALE_COMMAND"
range_cron="*/10 $range_hour_start-$range_hour_end * * * $make_command #RANGE_COMMAND"

cron=$(crontab -l)
cron=$(sed "s,.*#SUNRISE_RANGE_COMMAND$,$sunrise_range_cron,g" <<< "$cron")
cron=$(sed "s,.*#RANGE_COMMAND$,$range_cron,g" <<< "$cron")
cron=$(sed "s,.*#SUNSET_RANGE_COMMAND$,$sunset_range_cron,g" <<< "$cron")
cron=$(sed "s,.*#SUNSET_FINALE_COMMAND$,$sunset_finale_cron,g" <<< "$cron")

echo "$cron" | crontab -

