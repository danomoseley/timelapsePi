#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

command="$DIR/takePic.sh"
daily_timelapse_command="$DIR/makeDailyVideo.sh"
hourly_timelapse_command="$DIR/makeHourlyVideo.sh"

result=$(curl -s http://weather.yahooapis.com/forecastrss?w=$YAHOO_WEATHER_ID|grep astronomy| awk -F\" '{print $2 " " $4;}')

read sunrise sunrise_a sunset sunset_a <<<$(echo $result)

IFS=':' read sunrise_hour sunrise_minute <<< "$sunrise"
sunrise_minute=$(echo $sunrise_minute | sed 's/^0*//')
sunrise_hour=$(echo $sunrise_hour | sed 's/^0*//')
sunrise_minute=$((sunrise_minute-SUNRISE_SUNSET_BUFFER_MINUTES))
if ((sunrise_minute < 0)); then
    sunrise_minute=$((60+sunrise_minute))
    sunrise_hour=$((sunrise_hour-1))	
fi

cron_hour_start=$((sunrise_hour+1))

IFS=':' read sunset_hour sunset_minute <<< "$sunset"
sunset_hour=$((sunset_hour+12))
sunset_minute=$((sunset_minute+SUNRISE_SUNSET_BUFFER_MINUTES))
if ((sunset_minute > 59)); then
    sunset_minute=$((sunset_minute-60))
    sunset_hour=$((sunset_hour+1))
fi

daily_timelapse_hour=$sunset_hour
daily_timelapse_minute=$((sunset_minute+1))
if ((daily_timelapse_minute > 59)); then
    daily_timelapse_minute=$((daily_timelapse_minute-60))
    daily_timelapse_hour=$((daily_timelapse_hour+1))
fi

cron_hour_end=$((sunset_hour-1))

sunrise_cron="$sunrise_minute-59 $sunrise_hour * * * $command $sunrise_minute #SUNRISE_COMMAND"
range_cron="* $cron_hour_start-$cron_hour_end * * * $command #RANGE_COMMAND"
sunset_cron="0-$sunset_minute $sunset_hour * * * $command $sunset_minute #SUNSET_COMMAND"
daily_timelapse_cron="$daily_timelapse_minute $daily_timelapse_hour * * * $daily_timelapse_command #DAILY_TIMELAPSE_COMMAND"
hourly_timelapse_cron="0 $cron_hour_start-$sunset_hour * * * $hourly_timelapse_command #RANGE_HOURLY_TIMELAPSE_COMMAND"

cron=$(crontab -l)
cron=$(sed "s,.*#SUNRISE_COMMAND$,$sunrise_cron,g" <<< "$cron")
cron=$(sed "s,.*#RANGE_COMMAND$,$range_cron,g" <<< "$cron")
cron=$(sed "s,.*#RANGE_HOURLY_TIMELAPSE_COMMAND$,$hourly_timelapse_cron,g" <<< "$cron")
cron=$(sed "s,.*#SUNSET_COMMAND$,$sunset_cron,g" <<< "$cron")
cron=$(sed "s,.*#DAILY_TIMELAPSE_COMMAND,$daily_timelapse_cron,g" <<< "$cron")

echo "$cron" | crontab -
#echo "$cron"
