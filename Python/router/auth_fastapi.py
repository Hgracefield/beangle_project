from fastapi import FastAPI
from pydantic import BaseModel
import mysql.connector
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

db = mysql.connector.connect(
    host="127.0.0.1",
    user="root",
    password="Qwer1234!",
    database="cycle-predict",
    port=3307,
    auth_plugin='mysql_native_password' 
)

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

@app.post("/signup")
def signup(req: AuthFastAPI):

    query = """
    INSERT INTO user (user_name, user_email, user_password, user_phone)
    VALUES (%s, %s, %s, %s)
    """

    cursor.execute(query, (req.name, req.email, req.password, req.phone))
    db.commit()

    return {"success": True}

@app.post("/login")
def login(req: AuthFastAPI):

    query = "SELECT * FROM user WHERE user_email=%s AND user_password=%s"
    cursor.execute(query, (req.email, req.password))
    user = cursor.fetchone()

    if user:
        return {"success": True, "user_id": user[0]}
    else:
        return {"success": False}

@app.post("/google_login")
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


@app.get("/users/{user_id}")
def get_user(user_id: int):
    query = """
    SELECT user_id, user_name, user_email, user_phone
    FROM user
    WHERE user_id=%s
    """
    cursor.execute(query, (user_id,))
    user = cursor.fetchone()

    if not user:
        return {"success": False, "error": "user_not_found"}

    return {
        "success": True,
        "user": {
            "user_id": user[0],
            "name": user[1] or "",
            "email": user[2] or "",
            "phone": user[3] or "",
        },
    }


@app.put("/users/{user_id}")
def update_user(user_id: int, req: AuthFastAPI):
    try:
        check_query = "SELECT user_id FROM user WHERE user_id=%s"
        cursor.execute(check_query, (user_id,))
        existing = cursor.fetchone()

        if not existing:
            return {"success": False, "error": "user_not_found"}

        if req.password.strip():
            query = """
            UPDATE user
            SET user_name=%s, user_email=%s, user_password=%s, user_phone=%s
            WHERE user_id=%s
            """
            cursor.execute(
                query,
                (req.name, req.email, req.password, req.phone, user_id),
            )
        else:
            query = """
            UPDATE user
            SET user_name=%s, user_email=%s, user_phone=%s
            WHERE user_id=%s
            """
            cursor.execute(
                query,
                (req.name, req.email, req.phone, user_id),
            )

        db.commit()
        return {"success": True}
    except Exception as e:
        db.rollback()
        print("update_user error:", e)
        return {"success": False, "error": str(e)}


if __name__ == "__main__":
    uvicorn.run(app, host="172.16.250.217", port=8000)
