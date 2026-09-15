from pathlib import Path
import sys

import uvicorn

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

import config
from fastapi_route import app


if __name__ == "__main__":
    uvicorn.run(app, host=config.FASTAPI_HOST, port=8000)
