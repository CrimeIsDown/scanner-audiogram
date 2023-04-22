#!/bin/bash
set -ex

cd $(dirname "${BASH_SOURCE[0]}")

if [[ "$1" =~ ^https?:\/\/ ]]; then
    cd audiograms
    wget $1
    FILE="audiograms/$(basename $1)"
    cd ..
else
    FILE=$1
fi

if ! [ -s "${FILE%.*}.srt" ]; then
    openai api audio.transcribe -f $FILE --response-format srt --language en > ${FILE%.*}.srt
fi
code ${FILE%.*}.srt

read -p "Press enter once done editing." _

RESOLUTION=1280
ffmpeg -i $1 \
    -filter_complex "showwavespic=s=$(($RESOLUTION*3))x150:split_channels=1:colors=00ff00|00ff00" \
    -frames:v 1 \
    -y \
    ${FILE%.*}.png
DURATION=$(printf '%.*f' 0 $(ffprobe -show_entries format=duration -v error -of default=noprint_wrappers=1:nokey=1 $FILE))
ffprobe -loglevel warning -show_entries format_tags -of json $FILE | jq -r '.format.tags.title // empty' > ${FILE%.*}.txt

ffmpeg -i $FILE \
    -loop 1 -i background.png \
    -i progress.png \
    -i ${FILE%.*}.png \
    -filter_complex "[1]drawtext=fontsize=72:textfile=${FILE%.*}.txt:x=(w-text_w)/2:y=(h-325-text_h):fontcolor=white:shadowy=2:shadowx=2:shadowcolor=black[text];[text][3]overlay=x=-w*(t/$DURATION)+W/2:y=H-(h*2)[waveform];[waveform][2]overlay=x=-W/2:y=H-(h*2),subtitles=${FILE%.*}.srt:force_style='Fontsize=20'" \
    -shortest \
    -c:v libx264 -pix_fmt yuv420p \
    -y \
    ${FILE%.*}.mp4
ffplay ${FILE%.*}.mp4
