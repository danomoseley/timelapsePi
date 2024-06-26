#!/bin/bash
set -e
umask 002

dir=$(cd $(dirname $0); pwd -P)
source $dir/config.cfg

libx264_preset=${LIBX264_PRESET:-medium}
# Lower CRF = higher quality, 17 should be effectively lossless and 23 is default
libx264_crf=${LIBX264_CRF:-17}

# Mystery value to help fix extra frame lag between stitched timelapse chunks
snip_microseconds=${SNIP_MICROSECONDS:-89600}

CURL_UPLOAD_LIMIT=${CURL_UPLOAD_LIMIT:-500k}
DAILY_TIMELAPSE_UPLOAD_INTERVAL=${DAILY_TIMELAPSE_UPLOAD_INTERVAL:-30}

start=$SECONDS

date=$(date '+%y%m%d')
log_file="$dir/$date-output.txt"

start_minute=$(date '+%M')

tmp_dir="$dir/$date"
if [ ! -d $tmp_dir ]; then
    mkdir $tmp_dir
fi

processing_dir="$tmp_dir/output"
if [ -d $processing_dir ]; then
    echo "$processing_dir exists, already in progress? Exiting." | tee -a $log_file
    exit
fi

mkdir $processing_dir

trap "rm -Rf ${processing_dir}" EXIT

get_video_duration () {
    file_path=$1
    if [ -f "$file_path" ]; then
        video_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -sexagesimal "$file_path")
        echo $video_duration
    else
        echo "File not found ${file_path}" | tee -a $log_file
    fi
}

append_new_video () {
    speed=$1
    if [ -f "${dir}/${date}-${speed}.mp4" ]; then
        tik=$SECONDS
        echo "file '${dir}/${date}-${speed}.mp4'" >> "${processing_dir}/${date}-${speed}-list.txt"
        echo "file '${processing_dir}/${date}-${speed}.mp4'" >> "${processing_dir}/${date}-${speed}-list.txt"
        nice -19 ffmpeg -loglevel error -y -r 25 -f concat -safe 0 -i "${processing_dir}/${date}-${speed}-list.txt" -c copy -f mp4 "${processing_dir}/${date}-${speed}.mp4~incomplete" | tee -a $log_file
        mv "${processing_dir}/${date}-${speed}.mp4~incomplete" "${processing_dir}/${date}-${speed}.mp4"
        merge_timestamp=$(get_video_duration "${dir}/${date}-${speed}.mp4")
        echo "${speed}x merge timestamp: ${merge_timestamp}" | tee -a $log_file
        echo "${speed}x concat: $((SECONDS-tik))s" | tee -a $log_file
    else
        echo "No ${speed}x video yet, no concat to do." | tee -a $log_file
    fi
}

print_stats () {
    tik=$1
    display_name=$2
    elapsed_seconds=$((SECONDS-tik))
    elapsed_time=$(date -d@${elapsed_seconds} -u +%H:%M:%S)
    echo "${display_name}: ${elapsed_time} (${elapsed_seconds}s)" | tee -a $log_file
}

upload_stream_video () {
    filepath=$1
    response=$(curl --limit-rate ${CURL_UPLOAD_LIMIT} -X POST --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}" -F file=@$filepath https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream)
    video_id=$(jq -r '.result.uid' <<<"$response")
    echo $video_id
}

wait_for_video_ready_to_stream () {
    video_id=$1
    kv_key=$2
    ready_to_stream=false

    attempts=0
    while [ "${ready_to_stream}" != "true" ]; do
        response=$(curl -s -X GET --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}" --url https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/${video_id} --header 'Content-Type: application/json')
        ready_to_stream=$(jq -r '.result.readyToStream' <<<"$response")

        attempts=$((attempts+1))
        if [ "${ready_to_stream}" != "true" ]; then
            if (( attempts <= 5 )); then
                echo "Waiting 10s for video (${video_id}) to be ready to stream..." | tee -a $log_file
                sleep 10
            else
                echo "Giving up on video ready to stream, skipping KV update: ${response}" | tee -a $log_file
                break
            fi
        else
            echo "Video ${video_id} ready to stream" | tee -a $log_file
            put_kv_value $kv_key $video_id
        fi
    done
}

generate_stream_video_downloads () {
    video_id=$1
    response=$(curl --limit-rate ${CURL_UPLOAD_LIMIT} -X POST --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}" https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/$video_id/downloads)
    url=$(jq -r '.result.default.url' <<<"$response")
    echo $url
}

delete_stream_video () {
    video_id=$1
    echo "Deleting Cloudflare Stream video (id: ${video_id})" | tee -a $log_file
    status_code=$(curl -s --write-out '%{http_code}' --output /dev/null --request DELETE --url https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/${video_id} --header 'Content-Type: application/json' --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}")
    echo "Status: ${status_code}" | tee -a $log_file
}

put_kv_value () {
    key=$1
    value=$2
    response=$(curl -s --request PUT --url https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/storage/kv/namespaces/${CLOUDFLARE_KV_NAMESPACE_ID}/values/${TIMELAPSE_IDENTIFIER}-${key} --header 'Content-Type: multipart/form-data' --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}" --form metadata={} --form value=$value)

    success=$(jq -r '.success' <<<"$response")

    echo "KV setting ${TIMELAPSE_IDENTIFIER}-${key}=${value}" | tee -a $log_file
    echo "KV success: ${success}" | tee -a $log_file
}

echo "$(date '+%y%m%d%H%M%S')" | tee -a $log_file

tik=$SECONDS
echo "Starting rsync..." | tee -a $log_file
nice -19 rsync --remove-source-files -a --include="${date}*.h264" --exclude='*' pi@192.168.2.14:~/timelapsePi/vid/ $tmp_dir
print_stats $tik "Rsync"

shopt -s nullglob
for f in $tmp_dir/*.h264; do echo "file '$f'" >> "$processing_dir/${date}-list.txt"; done
shopt -u nullglob

if [ ! -s "$processing_dir/${date}-list.txt" ]; then
    echo "Nothing to do, exiting." | tee -a $log_file
    rm -Rf $tmp_dir
    exit
fi

tik=$SECONDS
echo "Starting FFmpeg 60x processing (preset: ${libx264_preset}, crf: ${libx264_crf})..." | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -f concat -safe 0 -i $processing_dir/${date}-list.txt -filter:v "setpts=PTS/60" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -ss "${snip_microseconds}us" -f mp4 "${processing_dir}/${date}-60.mp4" | tee -a $log_file
print_stats $tik "FFmpeg 60x"

append_new_video "60"

nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-60.mp4" -c copy "${processing_dir}/latest-clip-60.mp4" | tee -a $log_file

tik=$SECONDS
/home/dan/nvidia/ffmpeg/ffmpeg -loglevel error -y -hwaccel cuda -i "${processing_dir}/latest-clip-60.mp4" -an -c:v h264_nvenc -preset p7 -tune hq -rc constqp -f mp4 "${processing_dir}/latest-clip-60-web.mp4" | tee -a $log_file
print_stats $tik "FFmpeg latest-clip-60-web"

echo "Starting upload to Cloudflare Stream..." | tee -a $log_file

echo "Deleting previous videos" | tee -a $log_file

if [ -f "${dir}/previous_clip_video_id.txt" ]; then
    previous_clip_video_id=$(cat "${dir}/previous_clip_video_id.txt")
    delete_stream_video $previous_clip_video_id
    rm "${dir}/previous_clip_video_id.txt"
fi

if [ -f "${dir}/previous_timelapse_video_id.txt" ]; then
    previous_timelapse_video_id=$(cat "${dir}/previous_timelapse_video_id.txt")
    delete_stream_video $previous_timelapse_video_id
    rm "${dir}/previous_timelapse_video_id.txt"
fi

if [ "$1" != "sunset" ]; then
    tik=$SECONDS

    echo "Uploading latest clip..." | tee -a $log_file
    clip_video_id=$(upload_stream_video "${processing_dir}/latest-clip-60-web.mp4")

    echo "Latest clip video id ${clip_video_id}" | tee -a $log_file

    wait_for_video_ready_to_stream $clip_video_id "latest-clip-video-id"
    url=$(generate_stream_video_downloads $clip_video_id)
    put_kv_value "latest-clip-download-url" $url

    if [ -f "${dir}/latest_clip_video_id.txt" ]; then
        latest_clip_video_id=$(cat "${dir}/latest_clip_video_id.txt")
        echo $latest_clip_video_id > "${dir}/previous_clip_video_id.txt"
    fi
   
    echo $clip_video_id > "${dir}/latest_clip_video_id.txt"
    
    print_stats $tik "Latest clip upload"
else
    echo "Skipping latest clip upload" | tee -a $log_file
fi

if [ $(( 10#$start_minute % $DAILY_TIMELAPSE_UPLOAD_INTERVAL )) -eq 0 ] || [ "$1" == "sunset" ]; then
    tik=$SECONDS
    echo "Starting FFmpeg 480x processing..." | tee -a $log_file
    #/home/dan/nvidia/ffmpeg/ffmpeg -loglevel error -y -hwaccel cuda -i "${processing_dir}/${date}-60.mp4" -filter:v "setpts=PTS/16" -an -c:v h264_nvenc -preset p7 -tune hq -rc constqp -f mp4 "${processing_dir}/${date}-960.mp4" | tee -a $log_file
    /home/dan/nvidia/ffmpeg/ffmpeg -loglevel error -y -hwaccel cuda -i "${processing_dir}/${date}-60.mp4" -filter:v "setpts=PTS/8" -an -c:v h264_nvenc -preset p7 -tune hq -rc constqp -f mp4 "${processing_dir}/${date}-480.mp4" | tee -a $log_file
    #nice -19 ffmpeg -loglevel error -y -i "${processing_dir}/${date}-60.mp4" -filter:v "setpts=PTS/16" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -f mp4 "${processing_dir}/${date}-960.mp4" | tee -a $log_file
    print_stats $tik "FFmpeg 480x"
fi

mv $processing_dir/*.mp4 $dir

trap - EXIT

rm -Rf $tmp_dir

ln -sf "${dir}/${date}-60.mp4" "${dir}/latest-60.mp4"
ln -sf "${dir}/${date}-480.mp4" "${dir}/latest-480.mp4"
ln -sf "$log_file" "${dir}/latest-output.txt"

if [ $(( 10#$start_minute % $DAILY_TIMELAPSE_UPLOAD_INTERVAL )) -eq 0 ] || [ "$1" == "sunset" ]; then
    tik=$SECONDS

    echo "Uploading latest daily timelapse..." | tee -a $log_file
    timelapse_video_id=$(upload_stream_video "${dir}/${date}-480.mp4")

    echo "Latest timelapse video id ${timelapse_video_id}" | tee -a $log_file

    wait_for_video_ready_to_stream $timelapse_video_id "latest-video-id"
    url=$(generate_stream_video_downloads $timelapse_video_id)
    put_kv_value "latest-timelapse-download-url" $url

    if [ -f "${dir}/latest_timelapse_video_id.txt" ]; then
        latest_timelapse_video_id=$(cat "${dir}/latest_timelapse_video_id.txt")
        echo $latest_timelapse_video_id > "${dir}/previous_timelapse_video_id.txt"
    fi

    echo $timelapse_video_id > "${dir}/latest_timelapse_video_id.txt"

    if [ "$1" == "sunset" ]; then
        echo "Swapping clip for full timelapse for end of day" | tee -a $log_file
        put_kv_value "latest-clip-video-id" $timelapse_video_id
    fi

    print_stats $tik "Latest timelapse upload"
else
    echo "Skipping latest timelapse processing and upload" | tee -a $log_file
fi

mv $processing_dir/*.mp4 $dir

trap - EXIT

rm -Rf $tmp_dir

ln -sf "${dir}/${date}-60.mp4" "${dir}/latest-60.mp4"
ln -sf "${dir}/${date}-960.mp4" "${dir}/latest-960.mp4"
ln -sf "$log_file" "${dir}/latest-output.txt"

print_stats $start "Total processing"

