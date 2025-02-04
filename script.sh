#!/usr/bin/env bash
set -e

info() {
  echo "$@" >&2
}

die() {
  echo "$0:" "$@" >&2
  exit 1
}

if [[ -n "$FSS_FFMPEG_PATH" ]]; then
  ffmpeg_path="$FSS_FFMPEG_PATH"
elif command -v ffmpeg; then
  ffmpeg_path="$(command -v ffmpeg)"
else
  die "Could not find ffmpeg; install it or set FSS_FFMPEG_PATH"
fi

if [[ ! -e "$ffmpeg_path" ]]; then
  die "ffmpeg does not exist: $ffmpeg_path"
fi

if [[ -d "$ffmpeg_path" ]]; then
  if [[ -f "$ffmpeg_path/ffmpeg" ]]; then
    ffmpeg_path="$ffmpeg_path/ffmpeg"
  elif [[ -f "$ffmpeg_path/bin/ffmpeg" ]]; then
    ffmpeg_path="$ffmpeg_path/bin/ffmpeg"
  else
    die "Could not find ffmpeg in $ffmpeg_path"
  fi
fi

if [[ ! -x "$ffmpeg_path" ]]; then
  die "ffmpeg is not executable: $ffmpeg_path"
fi

if [[ -n "$FSS_FFPROBE_PATH" ]]; then
  ffprobe_path="$FSS_FFPROBE_PATH"
elif [[ -n "$FSS_FFMPEG_PATH" ]]; then
  ffprobe_path="$FSS_FFMPEG_PATH"
  if [[ ! -d "$ffprobe_path" ]]; then
    ffprobe_path="$(dirname "$ffprobe_path")"
  fi
elif command -v ffprobe; then
  ffprobe_path="$(command -v ffprobe)"
else
  ffprobe_path="$(dirname "$ffmpeg_path")"
fi

if [[ ! -e "$ffprobe_path" ]]; then
  die "ffprobe does not exist: $ffprobe_path"
fi

if [[ -d "$ffprobe_path" ]]; then
  if [[ -f "$ffprobe_path/ffprobe" ]]; then
    ffprobe_path="$ffprobe_path/ffprobe"
  elif [[ -f "$ffprobe_path/bin/ffprobe" ]]; then
    ffprobe_path="$ffprobe_path/bin/ffprobe"
  else
    die "Could not find ffprobe in $ffprobe_path"
  fi
fi

if [[ ! -x "$ffprobe_path" ]]; then
  die "ffprobe is not executable: $ffprobe_path"
fi

if [[ -n "$FSS_JQ_PATH" ]]; then
  jq_path="$FSS_JQ_PATH"
elif command -v jq; then
  jq_path="$(command -v jq)"
else
  die "Could not find jq. install it or set FFS_JQ_PATH"
fi

if [[ ! -e "$jq_path" ]]; then
  die "jq does not exist: $jq_path"
fi

if [[ -d "$jq_path" ]]; then
  if [[ -f "$jq_path/jq" ]]; then
    jq_path="$jq_path/jq"
  elif [[ -f "$jq_path/bin/jq" ]]; then
    jq_path="$jq_path/bin/jq"
  else
    die "Could not find jq in $jq_path"
  fi
fi

if [[ ! -x "$jq_path" ]]; then
  die "jq is not executable: $jq_path"
fi


info "ffmpeg: $ffmpeg_path"
info "ffprobe: $ffprobe_path"
info "jq: $jq_path"

ffmpeg() {
  "$ffmpeg_path" "$@"
}

ffprobe() {
  "$ffprobe_path" "$@"
}

jq() {
  "$jq_path" "$@"
}


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
