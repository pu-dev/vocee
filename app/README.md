# Vocee

A small macOS topbar utility, vibed in Swift with a Whisper server in Python. Press Option+Space to start recording, press again to stop — Vocee transcribes the audio, copies the text to your clipboard, and (if enabled in Settings) pastes it straight into whatever window is active, in any app.

> **Note:** Only works on Apple Silicon (arm64) Macs — not supported on Intel Macs.

## Installation

* Clone from github.
* Compiles and packages the app into `Vocee.app`.
* Downloads the Whisper turbo MLX model from Hugging Face.

```bash
git clone git@github.com:pu-dev/vocee.git
cd vocee
./dev/setup
./dev/download-model
```

