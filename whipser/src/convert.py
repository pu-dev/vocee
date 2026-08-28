import argparse
import mlx_whisper


def main():
    parser = argparse.ArgumentParser(description="Transcribe an audio file to text using mlx-whisper.")
    parser.add_argument("audio_file", help="Path to the webm (or other ffmpeg-readable) audio file")
    parser.add_argument(
        "--model",
        default="mlx-community/whisper-large-v3-turbo",
        help="Hugging Face repo of the mlx-whisper model to use",
    )
    args = parser.parse_args()

    result = mlx_whisper.transcribe(args.audio_file, path_or_hf_repo=args.model)
    print(result["text"])


if __name__ == "__main__":
    main()
