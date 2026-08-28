import argparse

from faster_whisper import WhisperModel


def main():
    parser = argparse.ArgumentParser(description="Transcribe an audio file to text using faster-whisper.")
    parser.add_argument("audio_file", help="Path to the webm (or other ffmpeg-readable) audio file")
    parser.add_argument(
        "--model",
        default="large-v3",
        help="faster-whisper model size or CTranslate2 model path/repo to use",
    )
    args = parser.parse_args()

    model = WhisperModel(args.model)
    segments, _ = model.transcribe(args.audio_file)
    print("".join(segment.text for segment in segments).strip())


if __name__ == "__main__":
    main()
