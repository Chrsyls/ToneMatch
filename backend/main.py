from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
import mysql.connector
import os
import time
from datetime import datetime

app = FastAPI()

# Memastikan folder uploads ada
os.makedirs("uploads", exist_ok=True)

# Membuka akses folder "uploads" agar bisa diakses oleh Flutter via URL
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="tonematch_user",
        password="password123", # Sesuaikan jika Anda mengganti password
        database="tonematch_db"
    )

# Inisialisasi kolom avatar_url jika belum ada di tabel users
def init_db():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(255)")
        conn.commit()
        cursor.close()
        conn.close()
    except Exception:
        pass

init_db()

@app.post("/api/v1/analyze/undertone")
async def analyze_undertone(image: UploadFile = File(...)):
    try:
        file_name = f"{int(time.time())}_{image.filename}"
        file_path = f"uploads/{file_name}"
        
        with open(file_path, "wb") as buffer:
            buffer.write(await image.read())

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT uid FROM users WHERE uid = 'usr_dummy_01'")
        if not cursor.fetchone():
            cursor.execute("INSERT INTO users (uid, email, name) VALUES ('usr_dummy_01', 'test@tonematch.app', 'Alvito Aryo')")
            conn.commit()

        history_id = f"hist_{int(time.time())}"
        query = "INSERT INTO classification_histories (history_id, user_id, image_url, detected_undertone, confidence_score) VALUES (%s, %s, %s, %s, %s)"
        cursor.execute(query, (history_id, 'usr_dummy_01', file_path, 'warm', 0.88))
        conn.commit()

        cursor.close()
        conn.close()
        return {"success": True, "message": "Berhasil disimpan ke MySQL!", "data": {"undertone": "warm"}}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/recommendations/{undertone}")
def get_recommendations(undertone: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        query = """
            SELECT p.product_id, p.name AS product_name, p.price, b.name AS brand_name 
            FROM makeup_products p 
            JOIN brands b ON p.brand_id = b.brand_id 
            WHERE p.target_undertone = %s OR p.target_undertone = 'neutral'
            LIMIT 10
        """
        cursor.execute(query, (undertone.lower(),))
        products = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return {"success": True, "data": products}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/history/{user_id}")
def get_history(user_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True) 
        
        query = "SELECT history_id, detected_undertone, confidence_score, created_at, image_url FROM classification_histories WHERE user_id = %s ORDER BY created_at DESC"
        cursor.execute(query, (user_id,))
        histories = cursor.fetchall()
        
        for item in histories:
            if isinstance(item['created_at'], datetime):
                item['created_at'] = item['created_at'].isoformat()
                
        cursor.close()
        conn.close()
        
        return {"success": True, "data": histories}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# --- CRUD: DELETE HISTORY ---
@app.delete("/api/v1/history/{history_id}")
def delete_history(history_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT image_url FROM classification_histories WHERE history_id = %s", (history_id,))
        row = cursor.fetchone()
        if row and row[0] and os.path.exists(row[0]):
            os.remove(row[0])
            
        cursor.execute("DELETE FROM classification_histories WHERE history_id = %s", (history_id,))
        conn.commit()
        
        cursor.close()
        conn.close()
        return {"success": True, "message": "Riwayat berhasil dihapus"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# --- CRUD: READ FAVORITES ---
@app.get("/api/v1/favorites/{user_id}")
def get_favorites(user_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        query = """
            SELECT f.favorite_id, p.product_id, p.name AS product_name, p.price, b.name AS brand_name 
            FROM favorite_products f
            JOIN makeup_products p ON f.product_id = p.product_id
            JOIN brands b ON p.brand_id = b.brand_id
            WHERE f.user_id = %s
        """
        cursor.execute(query, (user_id,))
        favorites = cursor.fetchall()
        cursor.close()
        conn.close()
        return {"success": True, "data": favorites}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# --- CRUD: CREATE FAVORITE ---
@app.post("/api/v1/favorites")
async def add_favorite(data: dict):
    try:
        user_id = data.get("user_id")
        product_id = data.get("product_id")
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        favorite_id = f"fav_{int(time.time())}"
        query = "INSERT INTO favorite_products (favorite_id, user_id, product_id) VALUES (%s, %s, %s)"
        cursor.execute(query, (favorite_id, user_id, product_id))
        conn.commit()
        
        cursor.close()
        conn.close()
        return {"success": True, "message": "Produk berhasil disimpan ke favorit!"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# --- CRUD: DELETE FAVORITE ---
@app.delete("/api/v1/favorites/{favorite_id}")
def delete_favorite(favorite_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM favorite_products WHERE favorite_id = %s", (favorite_id,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Produk dihapus dari favorit"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# --- CRUD: GET USER PROFILE (Auto-Create jika belum ada) ---
@app.get("/api/v1/users/{user_id}")
def get_user_profile(user_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT uid, email, name, avatar_url FROM users WHERE uid = %s", (user_id,))
        user = cursor.fetchone()
        
        if not user:
            cursor.execute("INSERT INTO users (uid, email, name) VALUES (%s, %s, %s)", (user_id, 'test@tonematch.app', 'Alvito Aryo'))
            conn.commit()
            cursor.execute("SELECT uid, email, name, avatar_url FROM users WHERE uid = %s", (user_id,))
            user = cursor.fetchone()
            
        cursor.close()
        conn.close()
        return {"success": True, "data": user}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# --- CRUD: UPDATE USER PROFILE (Auto-Create & Upsert Support) ---
@app.put("/api/v1/users/{user_id}")
async def update_user_profile(
    user_id: str, 
    name: str = Form(None), 
    email: str = Form(None), 
    remove_avatar: str = Form("false"),
    avatar: UploadFile | None = File(None)
):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE uid = %s", (user_id,))
        user = cursor.fetchone()
        
        avatar_path = user.get('avatar_url') if user else None
        
        if remove_avatar == "true":
            avatar_path = None
        elif avatar and avatar.filename:
            file_name = f"avatar_{user_id}_{int(time.time())}_{avatar.filename}"
            avatar_path = f"uploads/{file_name}"
            with open(avatar_path, "wb") as buffer:
                buffer.write(await avatar.read())
        
        new_name = name if name is not None and name.strip() != "" else ("Alvito Aryo" if not user else user['name'])
        new_email = email if email is not None and email.strip() != "" else ("test@tonematch.app" if not user else user['email'])
        
        if not user:
            cursor.execute(
                "INSERT INTO users (uid, email, name, avatar_url) VALUES (%s, %s, %s, %s)",
                (user_id, new_email, new_name, avatar_path)
            )
        else:
            cursor.execute(
                "UPDATE users SET name = %s, email = %s, avatar_url = %s WHERE uid = %s", 
                (new_name, new_email, avatar_path, user_id)
            )
        conn.commit()
        
        cursor.close()
        conn.close()
        return {"success": True, "message": "Profil berhasil diperbarui!", "avatar_url": avatar_path}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})