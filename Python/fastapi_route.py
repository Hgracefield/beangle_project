from fastapi import FastAPI
from userDB import router as user_router
import config
from router.reservation import router as reservation_router
from router.user import router as user_router
from router.auth import router as auth_router
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
app.include_router(user_router, prefix='/auth', tags=['auth'])  
app.include_router(user_router, prefix='/users', tags=['user'])  
app.include_router(reservation_router,prefix='/reservation',tags=['reservations'])

# CORS 설정
app.add_middleware(
  CORSMiddleware,
  allow_origins=['*'], # 모든 도메인을 허용
  allow_credentials=True,
  allow_methods=['*'], # 모든 http메서드 허용. 
  allow_headers=['*'], # 모든 헤더 get,post... 
)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=config.FASTAPI_HOST, port=8000)