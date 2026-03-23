from fastapi import APIRouter
import pymysql
from fastapi.middleware.cors import CORSMiddleware

import config
from pydantic import BaseModel

router = APIRouter()

class LoginRequest(BaseModel):
    email: str
    password: str

class worker(BaseModel):
    worker_id: int
    worker_email: str
    worker_password: str
    worker_name: str

def connect():
    return pymysql.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        database=config.DB_NAME,
        charset=config.DB_CHARSET,
        autocommit=False
    )

@router.get("/exist")
async def exist(email: str):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        select count(worker_id)
        from worker
        where worker_email = %s
        """
        curs.execute(sql, (email,))
        row = curs.fetchone()
        return {'result': row[0]}
    except Exception as ex:
        print("Error :", ex)
        return {'result': 'Error'}
    finally:
        conn.close()

@router.post("/login")
async def login_worker(request: LoginRequest):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        select worker_id,
               worker_email,
               worker_password,
               worker_name
        from worker
        where worker_email = %s and worker_password = %s
        """
        curs.execute(sql, (request.email, request.password))
        rows = curs.fetchall()


        result = [{
            'worker_id': row[0],
            'worker_email': row[1],
            'worker_password': row[2],
            'worker_name': row[3]
        } for row in rows]

        return {'success' : True,'results': result}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {"success": False, 'result': 'Error'}
    finally:
        conn.close()

@router.post("/insert")
async def insert(worker: worker):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        insert into worker
        (worker_email, worker_password, worker_name)
        values (%s, %s, %s)
        """
        curs.execute(sql, (
            worker.worker_email,
            worker.worker_password,
            worker.worker_name
        ))
        conn.commit()
        return {'result': 'OK'}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {'result': 'Error'}
    finally:
        conn.close()

@router.post("/update")
async def update(worker: worker):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        update worker set
            worker_password = %s,
            worker_name = %s
        where worker_email = %s
        """
        curs.execute(sql, (
            worker.worker_password,
            worker.worker_name,
            worker.worker_email
        ))
        conn.commit()
        return {'result': 'OK'}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {'result': 'Error'}
    finally:
        conn.close()

@router.get("/select")
async def select():
    conn = connect()
    curs = conn.cursor()
    try:
        sql = "select * from worker"
        curs.execute(sql)
        rows = curs.fetchall()

        result = [{
            'worker_id': row[0],
            'worker_email': row[1],
            'worker_password': row[2],
            'worker_name': row[3]
        } for row in rows]

        return {'results': result}
    finally:
        conn.close()