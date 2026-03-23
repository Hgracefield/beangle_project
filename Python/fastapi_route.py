from fastapi import FastAPI
from userDB import router as user_router
import config

app = FastAPI()
app.include_router(user_router, prefix='/user', tags=['user'])  


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=config.FASTAPI_HOST, port=8000)