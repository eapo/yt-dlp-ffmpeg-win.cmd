# yt-dlp-ffmpeg-win.cmd

Portable Windows batch downloader for YouTube — paste a URL, pick a format, save to NewPipe folder. FOSS only ([yt-dlp](https://github.com/yt-dlp/yt-dlp) + [ffmpeg](https://ffmpeg.org)).

**Repository:** https://github.com/eapo/yt-dlp-ffmpeg-win.cmd

## Requirements

- Windows 10 or later
- `curl` and `tar` (built into Windows 10+)
- Internet on first run (tools download automatically)

## Total Commander

Add item under **Start → Change Start Menu**:

1. Command: `cmd.exe /c ""C:\Program Files\portable\yt-dl\yt-dl.cmd""`
2. Parameters: `?%p` (optional)

Adjust the path if you keep the script elsewhere.

## Output folder

Downloads go to a `NewPipe` subfolder inside your **actual** Windows Downloads folder (read from registry, including if you moved Downloads to another drive):

```
<Your Downloads>\NewPipe
```

Files are named: `Title [videoId].ext`

## Keyboard shortcuts

| Step | Keys |
|------|------|
| URL | Paste URL + Enter; `Q` = quit |
| Format | `A` = best audio, `V` = best video+audio, `M` = pick video+audio IDs separately (ffmpeg merge to mp4), `C` = custom ID(s), `Q` = back |
| After download | `U` = update yt-dlp only, `D` = another URL, `S` = this README, `F` = open folder, `Q` = quit |

## Tools

- **yt-dlp** — downloaded into `tools\` on first use only (after you paste a URL)
- **ffmpeg** — uses existing install on PATH (e.g. `C:\ffmpeg\bin`); never auto-downloaded

Nothing is bundled in the repo; binaries stay local and are listed in `.gitignore`.

## License note

Respect site terms and copyright. This script is a convenience wrapper around third-party FOSS tools.
