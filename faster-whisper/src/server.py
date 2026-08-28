import tempfile
import time
from functools import lru_cache
from pathlib import Path

from faster_whisper import WhisperModel
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse

DEFAULT_MODEL = "large-v3"


def _resolve_device_and_compute_type() -> tuple[str, str]:
    try:
        import torch

        if torch.cuda.is_available():
            return "cuda", "float16"
    except ImportError:
        pass
    return "cpu", "int8"


DEVICE, COMPUTE_TYPE = _resolve_device_and_compute_type()

app = FastAPI(title="whisper-openai-compat")


@lru_cache(maxsize=2)
def get_model(model: str) -> WhisperModel:
    return WhisperModel(model, device=DEVICE, compute_type=COMPUTE_TYPE)


@app.post("/api/stt")
async def transcribe(
    file: UploadFile = File(...),
    model: str = Form(DEFAULT_MODEL),
    response_format: str = Form("json"),
    language: str = Form(None),
    prompt: str = Form(None),
    temperature: float = Form(0.0),
):
    suffix = Path(file.filename or "audio").suffix or ".webm"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
        tmp.write(await file.read())
        tmp.flush()

        kwargs = {"temperature": temperature}
        if language:
            kwargs["language"] = language
        if prompt:
            kwargs["initial_prompt"] = prompt

        try:
            whisper_model = get_model(model)
            segments, info = whisper_model.transcribe(tmp.name, **kwargs)
            segments = list(segments)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc

    text = "".join(segment.text for segment in segments).strip()

    if response_format == "text":
        return PlainTextResponse(text)

    if response_format == "verbose_json":
        return JSONResponse(
            {
                "task": "transcribe",
                "language": info.language,
                "duration": info.duration,
                "text": text,
                "segments": [
                    {
                        "id": segment.id,
                        "start": segment.start,
                        "end": segment.end,
                        "text": segment.text,
                    }
                    for segment in segments
                ],
            }
        )

    return JSONResponse({"text": text})


@app.get("/ping")
async def ping():
    return {"ok": True, "time": time.time()}
