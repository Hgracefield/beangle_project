from fastapi import APIRouter
from pydantic import BaseModel
import pymysql # mysql.connector
from fastapi.middleware.cors import CORSMiddleware
import config

router = APIRouter()

# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],  # 개발용
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )
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
db = connect()

cursor = db.cursor()

class AuthFastAPI(BaseModel):
    email: str
    password: str
    phone: str
    name: str

class GoogleAuthFastAPI(BaseModel):
    email: str
    name: str | None = None
    idToken: str

class FindIdRequest(BaseModel):
    name: str
    phone: str

class PasswordResetVerifyRequest(BaseModel):
    email: str
    name: str
    phone: str

class PasswordResetRequest(BaseModel):
    email: str
    name: str
    phone: str
    new_password: str

def _normalize_phone(phone: str) -> str:
    return ''.join(ch for ch in phone if ch.isdigit())

def _mask_email(email: str) -> str:
    if '@' not in email:
        return email

    local, domain = email.split('@', 1)
    if len(local) <= 2:
        masked_local = local[0] + '*' * max(len(local) - 1, 0)
    else:
        masked_local = local[:3] + '*' * (len(local) - 3)

    return f'{masked_local}@{domain}'

@router.post("/signup")
def signup(req: AuthFastAPI):

    query = """
    INSERT INTO user (user_name, user_email, user_password, user_phone)
    VALUES (%s, %s, %s, %s)
    """

    cursor.execute(query, (req.name, req.email, req.password, req.phone))
    db.commit()

    return {"success": True}

@router.post("/login")
def login(req: AuthFastAPI):

    query = "SELECT * FROM user WHERE user_email=%s AND user_password=%s"
    cursor.execute(query, (req.email, req.password))
    user = cursor.fetchone()

    if user:
        return {"success": True, "user_id": user[0]}
    else:
        return {"success": False}

@router.post("/google_login")
def google_login(req: GoogleAuthFastAPI):
    # TODO: Verify req.idToken with Google before trusting it.
    try:
        query = "SELECT * FROM user WHERE user_email=%s"
        cursor.execute(query, (req.email,))
        user = cursor.fetchone()

        if user:
            return {"success": True, "created": False, "user_id": user[0]}

        insert_query = """
        INSERT INTO user (user_name, user_email, user_password, user_phone)
        VALUES (%s, %s, %s, %s)
        """
        name = req.name or "GoogleUser"
        cursor.execute(insert_query, (name, req.email, "", ""))
        db.commit()
        return {"success": True, "created": True, "user_id": cursor.lastrowid}
    except Exception as e:
        print("google_login error:", e)
        return {"success": False, "error": str(e)}

@router.post("/find-id")
def find_id(req: FindIdRequest):
    try:
        query = """
        SELECT user_email, user_phone
        FROM user
        WHERE user_name=%s
        """
        cursor.execute(query, (req.name,))
        users = cursor.fetchall()

        normalized_phone = _normalize_phone(req.phone)
        for user_email, user_phone in users:
            if _normalize_phone(user_phone or '') == normalized_phone:
                return {
                    "success": True,
                    "email": user_email,
                    "masked_email": _mask_email(user_email or ''),
                }

        return {"success": False, "error": "user_not_found"}
    except Exception as e:
        print("find_id error:", e)
        return {"success": False, "error": str(e)}

@router.post("/verify-user-for-password-reset")
def verify_user_for_password_reset(req: PasswordResetVerifyRequest):
    try:
        query = """
        SELECT user_id, user_phone
        FROM user
        WHERE user_email=%s AND user_name=%s
        """
        cursor.execute(query, (req.email, req.name))
        user = cursor.fetchone()

        if not user:
            return {"success": False, "error": "user_not_found"}

        if _normalize_phone(user[1] or '') != _normalize_phone(req.phone):
            return {"success": False, "error": "user_not_found"}

        return {"success": True}
    except Exception as e:
        print("verify_user_for_password_reset error:", e)
        return {"success": False, "error": str(e)}

@router.post("/reset-password")
def reset_password(req: PasswordResetRequest):
    try:
        if len(req.new_password.strip()) < 6:
            return {"success": False, "error": "password_too_short"}

        query = """
        SELECT user_id, user_phone
        FROM user
        WHERE user_email=%s AND user_name=%s
        """
        cursor.execute(query, (req.email, req.name))
        user = cursor.fetchone()

        if not user:
            return {"success": False, "error": "user_not_found"}

        if _normalize_phone(user[1] or '') != _normalize_phone(req.phone):
            return {"success": False, "error": "user_not_found"}

        update_query = """
        UPDATE user
        SET user_password=%s
        WHERE user_id=%s
        """
        cursor.execute(update_query, (req.new_password, user[0]))
        db.commit()
        return {"success": True}
    except Exception as e:
        db.rollback()
        print("reset_password error:", e)
        return {"success": False, "error": str(e)}
