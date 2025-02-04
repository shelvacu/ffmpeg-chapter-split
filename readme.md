# ffmpeg-chapter-split

Splits a video file into chapters using `ffmpeg`. Also requires `jq`.

Use:

```
curl https://github.com/shelvacu/ffmpeg-chapter-split/raw/refs/heads/master/ffmpeg-chapter-split.sh --output ffmpeg-chapter-split.sh
chmod u+x ffmpeg-chapter-split.sh
./ffmpeg-chapter-split.sh
```

follow prompts to create config file and re-run

For nix users:

```
nix run github:shelvacu/ffmpeg-chapter-split
```
