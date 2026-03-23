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

