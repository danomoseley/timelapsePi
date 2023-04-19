#!/bin/bash
set -e
umask 002

libx264_preset="medium"
# Lower CRF = higher quality, 17 should be effectively lossless and 23 is default
libx264_crf="17"

libx264_preset_web="medium"
libx264_crf_web="23"

snip_microseconds=89300

dir=$(cd $(dirname $0); pwd -P)
source $dir/config.cfg

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
echo "Starting FFmpeg processing (preset: ${libx264_preset}, crf: ${libx264_crf})..." | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -f concat -safe 0 -i $processing_dir/${date}-list.txt -filter_complex "[0:v]split=5[in1][in2][in3][in4][in5];[in1]setpts=PTS/60[out1];[in2]setpts=PTS/120[out2];[in3]setpts=PTS/240[out3];[in4]setpts=PTS/60[out4];[in5]setpts=PTS/960[out5]" -map "[out1]" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -ss "${snip_microseconds}us" -f mp4 "${processing_dir}/${date}-60.mp4" -map "[out2]" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -ss "$((snip_microseconds/2))us" -f mp4 "${processing_dir}/${date}-120.mp4" -map "[out3]" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -ss "$((snip_microseconds/4))us" -f mp4 "${processing_dir}/${date}-240.mp4" -map "[out4]" -c:v libx264 -preset "$libx264_preset_web" -crf "$libx264_crf_web" -an -ss "$((snip_microseconds))us" -f mp4 "${processing_dir}/${date}-60-web.mp4" -map "[out5]" -c:v libx264 -preset "$libx264_preset_web" -crf "$libx264_crf_web" -an -ss "$((snip_microseconds/16))us" -f mp4 "${processing_dir}/${date}-960-web.mp4" | tee -a $log_file
print_stats $tik "FFmpeg"

append_new_video "60"
append_new_video "120"
append_new_video "240"
append_new_video "60-web"
append_new_video "960-web"

nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-60.mp4" -c copy "${processing_dir}/latest-clip-60.mp4" | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-120.mp4" -c copy "${processing_dir}/latest-clip-120.mp4" | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-240.mp4" -c copy "${processing_dir}/latest-clip-240.mp4" | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-60-web.mp4" -c copy "${processing_dir}/latest-clip-60-web.mp4" | tee -a $log_file

mv $processing_dir/*.mp4 $dir

trap - EXIT

rm -Rf $tmp_dir

ln -sf "${dir}/${date}-60.mp4" "${dir}/latest-60.mp4"
ln -sf "${dir}/${date}-120.mp4" "${dir}/latest-120.mp4"
ln -sf "${dir}/${date}-240.mp4" "${dir}/latest-240.mp4"
ln -sf "${dir}/${date}-60-web.mp4" "${dir}/latest-60-web.mp4"
ln -sf "${dir}/${date}-960-web.mp4" "${dir}/latest-960-web.mp4"
ln -sf "$log_file" "${dir}/latest-output.txt"

delete_stream_video () {
    video_id=$1
    echo "Deleting Cloudflare Stream video (id: ${video_id})" | tee -a $log_file
    response=$(curl -s --request DELETE --url https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/${video_id} --header 'Content-Type: application/json' --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}")
    success=$(jq -r '.success' <<<"$response")
    echo "Success: ${success}" | tee -a $log_file
}

put_kv_value () {
    key=$1
    value=$2
    response=$(curl -s --request PUT --url https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/storage/kv/namespaces/${CLOUDFLARE_KV_NAMESPACE_ID}/values/${TIMELAPSE_IDENTIFIER}-${key} --header 'Content-Type: multipart/form-data' --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}" --form metadata={} --form value=$value)

    success=$(jq -r '.success' <<<"$response")

    echo "KV success: ${success}" | tee -a $log_file
}

wait_for_video_ready_to_stream () {
    video_id=$1
    ready_to_stream=false

    while [ "${ready_to_stream}" != "true" ]; do
        response=$(curl -s -X GET --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}" --url https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/${video_id} --header 'Content-Type: application/json')
        ready_to_stream=$(jq -r '.result.readyToStream' <<<"$response")
        if [ "${ready_to_stream}" != "true" ]; then
            echo "Waiting for video (${video_id}) to be ready to stream..." | tee -a $log_file
            sleep 5
        fi
    done
}

upload_stream_video () {
    filename=$1
    response=$(curl --limit-rate 625k -X POST --header "Authorization: Bearer ${CLOUDFLARE_AUTH_TOKEN}" -F file=@$dir/$filename https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream)
    video_id=$(jq -r '.result.uid' <<<"$response")
    echo $video_id
}

upload_tik=$SECONDS

echo "Starting upload to Cloudflare Stream..." | tee -a $log_file

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

    clip_video_id=$(upload_stream_video "latest-clip-60-web.mp4")

    echo "Latest clip video id ${clip_video_id}" | tee -a $log_file
    
    wait_for_video_ready_to_stream $clip_video_id

    put_kv_value "latest-clip-video-id" $clip_video_id

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

    timelapse_video_id=$(upload_stream_video "latest-960-web.mp4")

    echo "Latest timelapse video id ${timelapse_video_id}" | tee -a $log_file

    wait_for_video_ready_to_stream $timelapse_video_id

    put_kv_value "latest-video-id" $timelapse_video_id

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
    echo "Skipping latest timelapse upload" | tee -a $log_file
fi

print_stats $upload_tik "Upload"

print_stats $start "Total processing"

