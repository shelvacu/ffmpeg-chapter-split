#!/usr/bin/env bash
set -e
video_with_chapters="$1"
video_basename="$(basename -- "$video_with_chapters")"
output_prefix="chapter-"
output_extension=".${video_basename##*.}"
chapters_json="$(ffprobe -hide_banner -v warning -output_format json -show_chapters "$video_with_chapters")"
chapter_count="$(echo "$chapters_json" | jq ".chapters|length")"
if (( "$chapter_count" == 0 )); then
  echo "$0: no chapters in $video_with_chapters" >&2
  exit 1
fi
for ((i=0; i < "$chapter_count"; i++ )); do
  chapter_start="$(echo "$chapters_json" | jq ".chapters[$i].start_time" -r)"
  chapter_end="$(echo "$chapters_json" | jq ".chapters[$i].end_time" -r)"
  if [[ "$chapter_start" == "$chapter_end" ]]; then
    # Some files have chapters as ranges of timestamps, other files have empty ranges and the chapters mark a point in time.
    if (( "$i" + 1 == "$chapter_count" )); then
      chapter_end=
    else
      chapter_end="$(echo "$chapters_json" | jq ".chapters[$((i+1))].end_time" -r)"
    fi
  fi
  input_args=(-ss "$chapter_start")
  if [[ -n "$chapter_end" ]]; then
    input_args+=(-to "$chapter_end")
  fi
  output_fn="${output_prefix}$(printf "%03d" "$i")${output_extension}"
  ffmpeg \
    -hide_banner -v warning \
    "${input_args[@]}" -i "$video_with_chapters" \
    -c copy "$output_fn"
done
