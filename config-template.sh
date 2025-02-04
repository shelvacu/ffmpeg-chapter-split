# What file to split; defaults to whatever is passed in as the first argument
export input_fn="$1"

#anything not exported is for your convenience and isn't used directly
input_basename="$(basename -- "$input_fn")"
input_extension=".${input_basename##*.}"

# The format passed to printf to determine the file name for each output chapter
export output_format="chapter-%03d.$input_extension"

# What options to pass to ffmpeg for the input, in addition to `-ss` and `-to` for seeking
# Note this is a bash array
export input_options=()

# What options to pass to ffmpeg for the output
# Note this is a bash array
export output_options=(-c copy)

# Change this to 1 when you're happy with these settings
export edited_config="0"
