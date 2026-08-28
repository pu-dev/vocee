# Vocee

A small macOS topbar utility, vibe-coded in Swift with a Whisper server in Python. Press **<Option+Space>** anywhere to start recording, press again to stop. Vocee transcribes the audio, copies the text to your clipboard, and pastes it straight into whatever window is active, in any app, system-wide.

> **Note:** Only works on Apple Silicon (arm64) Macs — not supported on Intel Macs.

## Installation

* Clone from GitHub.
* Compile and package the app into `Vocee.app`.

```bash
git clone git@github.com:pu-dev/vocee.git
cd vocee
./dev/setup
```

* Download the Whisper turbo MLX model from Hugging Face.

```bash
./dev/download-model
```
