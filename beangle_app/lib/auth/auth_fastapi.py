from fastapi import FastAPI
from pydantic import BaseModel
import mysql.connector
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="qwer1234",
    database="beangle_app"
)

cursor = db.cursor()

class AuthFastAPI(BaseModel):
    email: str
    password: str
    phone: str
    name: str

@app.post("/signup")
def signup(req: AuthFastAPI):

    query = """
    INSERT INTO users (user_name, user_email, user_password, user_phone)
    VALUES (%s, %s, %s, %s)
    """

    cursor.execute(query, (req.name, req.email, req.password, req.phone))
    db.commit()

    return {"success": True}

@app.post("/login")
def login(req: AuthFastAPI):

    query = "SELECT * FROM users WHERE user_email=%s AND user_password=%s"
    cursor.execute(query, (req.email, req.password))
    user = cursor.fetchone()

    if user:
        return {"success": True}
    else:
        return {"success": False}