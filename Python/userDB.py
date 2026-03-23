from fastapi import APIRouter
import pymysql
import config
from pydantic import BaseModel

router = APIRouter()

class LoginRequest(BaseModel):
    email: str
    password: str

class User(BaseModel):
    user_id: int
    user_email: str
    user_password: str
    user_name: str
    user_phone: str

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
        select count(user_id)
        from user
        where user_email = %s
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
async def login_user(request: LoginRequest):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        select user_id,
               user_email,
               user_password,
               user_name,
               user_phone,
               user_address
        from user
        where user_email = %s and user_password = %s
        """
        curs.execute(sql, (request.email, request.password))
        rows = curs.fetchall()

        result = [{
            'user_id': row[0],
            'user_email': row[1],
            'user_password': row[2],
            'user_name': row[3],
            'user_phone': row[4],
            'user_address': row[5]
        } for row in rows]

        return {'results': result}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {'result': 'Error'}
    finally:
        conn.close()

@router.post("/googleLogin")
async def google_login(request: LoginRequest):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        select user_id,
               user_email,
               user_password,
               user_name,
               user_phone,
               user_address
        from user
        where user_email = %s
        """
        curs.execute(sql, (request.email,))
        rows = curs.fetchall()

        result = [{
            'user_id': row[0],
            'user_email': row[1],
            'user_password': row[2],
            'user_name': row[3],
            'user_phone': row[4],
            'user_address': row[5]
        } for row in rows]

        return {'results': result}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {'result': 'Error'}
    finally:
        conn.close()

@router.post("/insert")
async def insert(user: User):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        insert into user
        (user_email, user_password, user_name, user_phone)
        values (%s, %s, %s, %s)
        """
        curs.execute(sql, (
            user.user_email,
            user.user_password,
            user.user_name,
            user.user_phone
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
async def update(user: User):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        update user set
            user_password = %s,
            user_name = %s,
            user_phone = %s
        where user_id = %s
        """
        curs.execute(sql, (
            user.user_password,
            user.user_name,
            user.user_phone,
            user.user_id
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
        sql = "select * from user"
        curs.execute(sql)
        rows = curs.fetchall()

        result = [{
            'user_id': row[0],
            'user_email': row[1],
            'user_password': row[2],
            'user_name': row[3],
            'user_phone': row[4]
        } for row in rows]

        return {'results': result}
    finally:
        conn.close()