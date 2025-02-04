#!/usr/bin/env bash
set -e
set -o inherit_errexit

info() {
  echo "$@" >&2
}

die() {
  echo "$0:" "$@" >&2
  exit 1
}

config_path="ffmpeg-chapter-split-config.sh"
if [[ -n "$FCS_CONFIG_PATH" ]]; then
  config_path="$FCS_CONFIG_PATH"
fi

find_template() {
  template_basename="config-template.sh"
  if [[ -n "$FCS_CONFIG_TEMPLATE_PATH" ]]; then
    template_fn="$FCS_CONFIG_TEMPLATE_PATH"
  elif [[ -e "$template_basename" ]]; then
    template_fn="$template_basename"
  else
    template_fn="$(mktemp --suffix=ffmpeg-chapter-split-config-template.sh)"
    url="https://raw.githubusercontent.com/shelvacu/ffmpeg-chapter-split/refs/heads/master/$template_basename"
    info "Trying curl..."
    curl "$url" --output "$template_fn" || true
    if [[ ! -e "$template_fn" ]]; then
      info "Trying wget..."
      wget "$url" --output-document="$template_fn"
    fi
  fi
  if [[ ! -f "$template_fn" ]]; then
    die "Could not find template config"
  fi
  echo "$template_fn"
}

if [[ ! -e "$config_path" ]]; then
  info "could not find config at $config_path"
  full_config_path="$(readlink -f "$config_path")"
  read -p "Would you like to create a new config file at $full_config_path? [Y/n]" -n 1 -r
  echo
  if [[ "$REPLY" != "Y" ]] && [[ "$REPLY" != "y" ]] && [[ -n "$REPLY" ]]; then
    die "no config file"
  fi
  template_fn="$(find_template)"
  cp "$template_fn" "$full_config_path"
  die "New config created at $full_config_path. Edit and re-run"
fi

# shellcheck source=config-template.sh
source "$config_path"

if [[ -n "$edited_config" ]]; then
  die "Invalid config"
elif [[ "$edited_config" != 1 ]]; then
  die "Edit $config_path and re-run (edited_config != 1)"
fi

if [[ -n "$FCS_FFMPEG_PATH" ]]; then
  ffmpeg_path="$FCS_FFMPEG_PATH"
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

if [[ -n "$FCS_FFPROBE_PATH" ]]; then
  ffprobe_path="$FCS_FFPROBE_PATH"
elif [[ -n "$FCS_FFMPEG_PATH" ]]; then
  ffprobe_path="$FCS_FFMPEG_PATH"
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

if [[ -n "$FCS_JQ_PATH" ]]; then
  jq_path="$FCS_JQ_PATH"
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

chapters_json="$(ffprobe -hide_banner -v warning -output_format json -show_chapters "$input_fn")"

jq_raw() {
  jq_expr="$1"
  echo "$chapters_json" | jq "$jq_expr" -r
}

chapter_count="$(jq_raw ".chapters|length")"
if (( "$chapter_count" == 0 )); then
  echo "$0: no chapters in $input_fn" >&2
  exit 1
fi
for (( i=0; i < "$chapter_count"; i++ )); do
  chapter_start="$(jq_raw ".chapters[$i].start_time")"
  chapter_end="$(jq_raw ".chapters[$i].end_time")"
  if [[ "$chapter_start" == "$chapter_end" ]]; then
    # Some files have chapters as ranges of timestamps, other files have empty ranges and the chapters mark a point in time.
    if (( "$i" + 1 == "$chapter_count" )); then
      chapter_end=
    else
      chapter_end="$(jq_raw ".chapters[$((i+1))].end_time")"
    fi
  fi
  input_args=(-ss "$chapter_start")
  if [[ -n "$chapter_end" ]]; then
    input_args+=(-to "$chapter_end")
  fi
  input_args+=("${input_options[@]}")
  # shellcheck disable=SC2059
  output_fn="$(printf "$output_format" "$i")"
  ffmpeg \
    -hide_banner -v warning \
    "${input_args[@]}" -i "$input_fn" \
    "${output_options[@]}" "$output_fn"
done
