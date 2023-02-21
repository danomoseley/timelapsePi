#!/bin/bash
set -e

libx264_preset="medium"
# Lower CRF = higher quality, 17 should be effectively lossless and 23 is default
libx264_crf="17"
snip_microseconds=89300

dir=$(cd $(dirname $0); pwd -P)
start=$SECONDS

date=$(date '+%y%m%d')
log_file="$dir/$date-output.txt"

tmp_dir="$dir/$date"
if [ ! -d $tmp_dir ]; then
    mkdir $tmp_dir
fi

processing_dir="$tmp_dir/output"
if [ ! -d $processing_dir ]; then
    mkdir $processing_dir
fi

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
    echo "Nothing to do, exiting."
    exit
fi

tik=$SECONDS
echo "Starting FFmpeg processing (preset: ${libx264_preset}, crf: ${libx264_crf})..." | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -f concat -safe 0 -i $processing_dir/${date}-list.txt -filter_complex "[0:v]split=3[in1][in2][in3];[in1]setpts=PTS/60[out1];[in2]setpts=PTS/120[out2];[in3]setpts=PTS/240[out3]" -map "[out1]" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -ss "${snip_microseconds}us" -f mp4 "${processing_dir}/${date}-60.mp4" -map "[out2]" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -ss "$((snip_microseconds/2))us" -f mp4 "${processing_dir}/${date}-120.mp4" -map "[out3]" -c:v libx264 -preset "$libx264_preset" -crf "$libx264_crf" -an -ss "$((snip_microseconds/4))us" -f mp4 "${processing_dir}/${date}-240.mp4" | tee -a $log_file
print_stats $tik "FFmpeg"

append_new_video "60"
append_new_video "120"
append_new_video "240"

nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-60.mp4" -c copy "${processing_dir}/latest-clip-60.mp4" | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-120.mp4" -c copy "${processing_dir}/latest-clip-120.mp4" | tee -a $log_file
nice -19 ffmpeg -loglevel error -y -r 25 -sseof -10 -i "${processing_dir}/${date}-240.mp4" -c copy "${processing_dir}/latest-clip-240.mp4" | tee -a $log_file

mv $processing_dir/*.mp4 $dir

trap - EXIT

rm -Rf $tmp_dir

ln -sf "${dir}/${date}-60.mp4" "latest-60.mp4"
ln -sf "${dir}/${date}-120.mp4" "latest-120.mp4"
ln -sf "${dir}/${date}-240.mp4" "latest-240.mp4"
ln -sf "$log_file" "latest-output.txt"

print_stats $start "Total processing"
