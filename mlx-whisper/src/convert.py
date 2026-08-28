import argparse
import time

import mlx_whisper

MODEL_SIZES = {
    "medium": "mlx-community/whisper-medium",
    "large": "mlx-community/whisper-large-v3-mlx",
    "turbo": "mlx-community/whisper-large-v3-turbo",
}


def main():
    parser = argparse.ArgumentParser(description="Transcribe an audio file to text using mlx-whisper.")
    parser.add_argument("audio_file", help="Path to the webm (or other ffmpeg-readable) audio file")
    model_group = parser.add_mutually_exclusive_group()
    model_group.add_argument(
        "--size",
        choices=MODEL_SIZES.keys(),
        help="Mlx-whisper model size to use (medium, large, or turbo)",
    )
    model_group.add_argument(
        "--model",
        default="mlx-community/whisper-large-v3-turbo",
        help="Mlx-whisper model repo id to use",
    )
    args = parser.parse_args()
    model = MODEL_SIZES[args.size] if args.size else args.model

    start = time.perf_counter()
    result = mlx_whisper.transcribe(args.audio_file, path_or_hf_repo=model)
    elapsed = time.perf_counter() - start

    print(result["text"])
    print(f"------------------------------")
    print(f"Transcription took {elapsed:.2f}s")
    print(f"------------------------------")

if __name__ == "__main__":
    main()
