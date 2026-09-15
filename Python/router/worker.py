from fastapi import APIRouter
import pymysql
from fastapi.middleware.cors import CORSMiddleware
import hashlib
import secrets
import smtplib
from datetime import datetime
from email.message import EmailMessage

import config
from pydantic import BaseModel

router = APIRouter()

class LoginRequest(BaseModel):
    email: str
    password: str

class SignUpWorker(BaseModel):
    worker_email: str
    worker_password: str
    worker_name: str    

class worker(BaseModel):
    worker_id: int
    worker_email: str
    worker_password: str
    worker_name: str

class MailAuthSendRequest(BaseModel):
    worker_email: str

class MailAuthVerifyRequest(BaseModel):
    worker_email: str
    code: str

class PasswordResetRequest(BaseModel):
    worker_email: str
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

MAIL_AUTH_EXPIRY_MINUTES = 5

def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()

def _generate_code() -> str:
    return f"{secrets.randbelow(1000000):06d}"

def _generate_temp_password(length: int = 8) -> str:
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(secrets.choice(alphabet) for _ in range(length))

def _send_mail(to_email: str, code: str) -> None:
    if not (config.SMTP_HOST and config.SMTP_PORT and config.SMTP_FROM):
        raise RuntimeError("SMTP is not configured")

    msg = EmailMessage()
    msg["Subject"] = "Your verification code"
    msg["From"] = config.SMTP_FROM
    msg["To"] = to_email
    msg.set_content(f"Your verification code is: {code}")

    with smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT) as server:
        if config.SMTP_USE_TLS:
            server.starttls()
        if config.SMTP_USER:
            server.login(config.SMTP_USER, config.SMTP_PASSWORD)
        server.send_message(msg)

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

@router.post("/mail-auth/send")
async def send_mail_auth(request: MailAuthSendRequest):
    conn = connect()
    curs = conn.cursor()
    try:
        code = _generate_code()
        code_hash = _hash_code(code)

        upsert_sql = """
        insert into worker_email_auth
            (worker_email, code_hash, expires_at, verified_at)
        values
            (%s, %s, date_add(now(), interval %s minute), null)
        on duplicate key update
            code_hash = values(code_hash),
            expires_at = values(expires_at),
            verified_at = null
        """
        curs.execute(upsert_sql, (
            request.worker_email,
            code_hash,
            MAIL_AUTH_EXPIRY_MINUTES
        ))

        _send_mail(request.worker_email, code)
        conn.commit()
        return {"result": "OK"}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {"result": "Error"}
    finally:
        conn.close()

@router.post("/mail-auth/verify")
async def verify_mail_auth(request: MailAuthVerifyRequest):
    conn = connect()
    curs = conn.cursor()
    try:
        select_sql = """
        select code_hash, expires_at
        from worker_email_auth
        where worker_email = %s
        """
        curs.execute(select_sql, (request.worker_email,))
        row = curs.fetchone()

        if not row:
            return {"result": "NOT_FOUND"}

        code_hash, expires_at = row
        if expires_at is None or datetime.now() > expires_at:
            return {"result": "EXPIRED"}

        if _hash_code(request.code) != code_hash:
            return {"result": "INVALID"}

        update_sql = """
        update worker_email_auth
        set verified_at = now()
        where worker_email = %s
        """
        curs.execute(update_sql, (request.worker_email,))
        conn.commit()
        return {"result": "OK"}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {"result": "Error"}
    finally:
        conn.close()

@router.post("/password-reset")
async def password_reset(request: PasswordResetRequest):
    conn = connect()
    curs = conn.cursor()
    try:
        find_sql = """
        select worker_id
        from worker
        where worker_email = %s and worker_name = %s
        """
        curs.execute(find_sql, (request.worker_email, request.worker_name))
        row = curs.fetchone()

        if not row:
            return {"result": "NOT_FOUND"}

        temp_password = _generate_temp_password()
        update_sql = """
        update worker
        set worker_password = %s
        where worker_id = %s
        """
        curs.execute(update_sql, (temp_password, row[0]))

        msg = EmailMessage()
        msg["Subject"] = "Temporary password"
        msg["From"] = config.SMTP_FROM
        msg["To"] = request.worker_email
        msg.set_content(f"Your temporary password is: {temp_password}")

        with smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT) as server:
            if config.SMTP_USE_TLS:
                server.starttls()
            if config.SMTP_USER:
                server.login(config.SMTP_USER, config.SMTP_PASSWORD)
            server.send_message(msg)

        conn.commit()
        return {"result": "OK"}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {"result": "Error"}
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
async def insert(worker: SignUpWorker):
    conn = connect()
    curs = conn.cursor()
    try:
        verify_sql = """
        select verified_at, expires_at
        from worker_email_auth
        where worker_email = %s
        """
        curs.execute(verify_sql, (worker.worker_email,))
        verify_row = curs.fetchone()

        if not verify_row:
            return {"result": "EMAIL_NOT_VERIFIED"}

        verified_at, expires_at = verify_row
        if verified_at is None or expires_at is None or datetime.now() > expires_at:
            return {"result": "EMAIL_NOT_VERIFIED"}

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
