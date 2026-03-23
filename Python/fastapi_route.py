from fastapi import FastAPI
from userDB import router as user_router
import config
from router.reservation import router as reservation_router

app = FastAPI()
app.include_router(user_router, prefix='/user', tags=['user'])  
app.include_router(reservation_router,prefix='/reservation',tags=['reservations'])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=config.FASTAPI_HOST, port=8000)