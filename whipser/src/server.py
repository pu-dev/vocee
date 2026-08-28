import tempfile
import time
from pathlib import Path

import mlx_whisper
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse

DEFAULT_MODEL = "mlx-community/whisper-large-v3-turbo"

app = FastAPI(title="whisper-openai-compat")


@app.post("/stt")
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

        kwargs = {"path_or_hf_repo": model, "temperature": temperature}
        if language:
            kwargs["language"] = language
        if prompt:
            kwargs["initial_prompt"] = prompt

        try:
            result = mlx_whisper.transcribe(tmp.name, **kwargs)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc

    text = result["text"].strip()

    if response_format == "text":
        return PlainTextResponse(text)

    if response_format == "verbose_json":
        return JSONResponse(
            {
                "task": "transcribe",
                "language": result.get("language"),
                "duration": None,
                "text": text,
                "segments": result.get("segments", []),
            }
        )

    return JSONResponse({"text": text})


@app.get("/ping")
async def ping():
    return {"ok": True, "time": time.time()}
