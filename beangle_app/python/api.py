from fastapi import FastAPI
from router.reservation import router as reservation_router
import pymysql
# from database.database import Dbconn

app = FastAPI()
app.include_router(reservation_router,prefix='/reservation',tags=['reservations'])



if __name__ == "__main__" :
  import uvicorn
  uvicorn.run(app,host='127.0.0.1',port=8000)