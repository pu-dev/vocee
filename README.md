# voice-scribe

Record audio, transcribe it via a Whisper-compatible STT server, and get the text — as a menu bar app or from the command line.

## CLI

Build and ad-hoc sign the CLI tool:

```
./build-cli.sh
```

Run it:

```
.build/debug/voicescribe-cli
```

It starts recording immediately, shows a live level meter, and stops when you press Enter (or Ctrl+C). The transcript is printed to stdout and copied to the clipboard.

Optionally install it to your PATH:

```
cp .build/debug/voicescribe-cli /usr/local/bin/voicescribe
```

Pass `-p` (or `--paste`) to also paste the transcript into the active window afterwards (simulates Cmd+V):

```
voicescribe -p
```

This requires granting Accessibility permission (System Settings → Privacy & Security → Accessibility) to whatever runs the binary — your terminal app, or the binary itself if run directly.

Configuration is via environment variables (same as the menu bar app):

- `STT_BASE_URL` — base URL of the STT server (default `http://127.0.0.1:8990/api/openai_compat`)
- `STT_MODEL` — model name (default `mlx-community/whisper-large-v3-turbo`)
- `STT_API_KEY` — bearer token, if required

## Menu bar app

```
./build-app.sh
open VoiceScribe.app
```
