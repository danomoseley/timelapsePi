#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

url="http://dataservice.accuweather.com/forecasts/v1/daily/5day/${ACCUWEATHER_LOCATION_ID}?apikey=${ACCUWEATHER_API_KEY}"
result=$(curl -s $url)

tomorrow=$(echo $result | jq '.DailyForecasts[1].Day.IconPhrase')
tomorrow_lower=$(echo "$tomorrow" | awk '{print tolower($0)}')

echo $tomorrow

if [[ "$tomorrow_lower" =~ .*"sunny".* ]]; then
    exposure_absolute=4
else
    exposure_absolute=20
fi

sed -i "s/\(EXPOSURE_ABSOLUTE *= *\).*/\1$exposure_absolute/" $DIR/config.cfg
