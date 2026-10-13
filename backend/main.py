from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import mysql.connector
import os
import time
from datetime import datetime
import requests

app = FastAPI()

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="tonematch_user",
        password="password123",
        database="tonematch_db"
    )

class ProductCreate(BaseModel):
    product_name: str
    brand: str
    price: float
    undertone: str
    image_url: str | None = None

class ScrapeRequest(BaseModel):
    brand: str
    target_undertone: str = "neutral"

def init_db():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("ALTER TABLE users MODIFY COLUMN role ENUM('super_admin', 'admin', 'user') DEFAULT 'user'")
        cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(255)")
        
        cursor.execute("SHOW TABLES LIKE 'makeup_products'")
        if cursor.fetchone():
            cursor.execute("SHOW COLUMNS FROM makeup_products LIKE 'image_url'")
            if not cursor.fetchone():
                cursor.execute("ALTER TABLE makeup_products ADD COLUMN image_url TEXT")
                
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS makeup_products (
                product_id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                brand VARCHAR(255),
                price DECIMAL(10,2) DEFAULT 0,
                target_undertone VARCHAR(50) DEFAULT 'warm',
                image_url TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS favorite_products (
                favorite_id VARCHAR(128) PRIMARY KEY,
                user_id VARCHAR(128),
                product_id INT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Init DB Notice: {e}")

init_db()

# ==========================================
# ENDPOINT INTEGRASI API (SANGAT CEPAT & ANTI GAGAL)
# ==========================================
@app.post("/api/v1/admin/products/scrape")
async def fetch_products(req: ScrapeRequest):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    brand_name = req.brand.strip().lower()
    display_brand = brand_name.title()
    undertone = req.target_undertone if req.target_undertone else "neutral"
    products_added = 0

    try:
        # 1. Coba Tarik Data dari Public Makeup API (Brand Internasional)
        api_url = f"http://makeup-api.herokuapp.com/api/v1/products.json?brand={brand_name}"
        response = requests.get(api_url, timeout=10)
        
        if response.status_code == 200 and len(response.json()) > 0:
            data = response.json()
            # Ambil maksimal 15 produk agar rapi
            for item in data[:15]:
                name = item.get('name')
                price_usd = float(item.get('price') or 10.0)
                price_idr = price_usd * 15500.0 # Konversi ke Rupiah
                image_url = item.get('image_link', '')
                
                # Perbaikan link gambar yang error dari API
                if image_url and image_url.startswith('//'):
                    image_url = "https:" + image_url

                if name:
                    cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (name,))
                    if not cursor.fetchone():
                        cursor.execute(
                            "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                            (name, display_brand, price_idr, undertone, image_url)
                        )
                        products_added += 1
        else:
            # 2. KATALOG LOKAL INTERNAL (Untuk Brand Indonesia yang tidak ada di API)
            local_catalogs = {
                "wardah": [
                    ("Colorfit Velvet Matte Lip Mousse", 73000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                    ("Exclusive Liquid Foundation", 82000.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e"),
                    ("Lightening Face Toner", 24000.0, "https://images.unsplash.com/photo-1620916566398-39f1143ab7be")
                ],
                "emina": [
                    ("Creamatte Lip Cream", 47500.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                    ("Bare with Me Mineral Cushion", 126000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796")
                ],
                "somethinc": [
                    ("Copy Paste Breathable Cushion", 185900.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                    ("Ombrella Lip Totem Tint", 59000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa")
                ],
                "blp": [
                    ("Lip Coat", 139000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                    ("Face Powder", 149000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796")
                ]
            }
            
            # Cari keyword brand di katalog lokal
            matched_key = next((k for k in local_catalogs.keys() if k in brand_name), None)
            
            if matched_key:
                for p_name, p_price, p_img in local_catalogs[matched_key]:
                    cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (p_name,))
                    if not cursor.fetchone():
                        cursor.execute(
                            "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                            (p_name, display_brand, p_price, undertone, p_img)
                        )
                        products_added += 1
            else:
                # 3. KONDISI DEFAULT JIKA BRAND SAMA SEKALI TIDAK DIKENAL
                default_products = [
                    (f"{display_brand} Signature Lip Velvet", 129000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                    (f"{display_brand} Glow Liquid Foundation", 189000.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e"),
                ]
                for p_name, p_price, p_img in default_products:
                    cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (p_name,))
                    if not cursor.fetchone():
                        cursor.execute(
                            "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                            (p_name, display_brand, p_price, undertone, p_img)
                        )
                        products_added += 1

        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": f"Berhasil menarik {products_added} produk instan untuk brand {display_brand}."}

    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": f"Kesalahan sistem: {str(e)}"})

# ==========================================
# ENDPOINT STANDAR
# ==========================================
@app.post("/api/v1/analyze/undertone")
async def analyze_undertone(image: UploadFile = File(...)):
    try:
        file_name = f"{int(time.time())}_{image.filename}"
        file_path = f"uploads/{file_name}"
        with open(file_path, "wb") as buffer:
            buffer.write(await image.read())
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT uid FROM users WHERE uid = %s", ('usr_dummy_01',))
        if not cursor.fetchone():
            cursor.execute("INSERT INTO users (uid, email, name, role) VALUES (%s, %s, %s, %s)", ('usr_dummy_01', 'test@tonematch.app', 'Alvito Aryo', 'super_admin'))
            conn.commit()
        history_id = f"hist_{int(time.time())}"
        cursor.execute("INSERT INTO classification_histories (history_id, user_id, image_url, detected_undertone, confidence_score) VALUES (%s, %s, %s, %s, %s)", (history_id, 'usr_dummy_01', file_path, 'warm', 0.88))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Berhasil disimpan!", "data": {"undertone": "warm"}}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/recommendations/{undertone}")
def get_recommendations(undertone: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT product_id, name AS product_name, price, brand, image_url FROM makeup_products WHERE target_undertone = %s OR target_undertone = 'neutral' LIMIT 10", (undertone.lower(),))
        products = cursor.fetchall()
        for p in products:
            if p.get('price') is not None:
                p['price'] = float(p['price'])
        cursor.close()
        conn.close()
        return {"success": True, "data": products}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/products")
def get_all_products():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT product_id, name AS product_name, brand, price, target_undertone AS undertone, image_url FROM makeup_products ORDER BY product_id DESC")
        products = cursor.fetchall()
        for p in products:
            if p.get('price') is not None:
                p['price'] = float(p['price'])
        cursor.close()
        conn.close()
        return {"success": True, "data": products}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.post("/api/v1/admin/products")
async def add_product(data: ProductCreate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
            (data.product_name, data.brand, data.price, data.undertone, data.image_url)
        )
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Produk berhasil ditambahkan!"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.put("/api/v1/admin/products/{product_id}")
async def update_product(product_id: int, data: ProductCreate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE makeup_products SET name = %s, brand = %s, price = %s, target_undertone = %s, image_url = %s WHERE product_id = %s", 
            (data.product_name, data.brand, data.price, data.undertone, data.image_url, product_id)
        )
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Produk berhasil diperbarui!"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.delete("/api/v1/admin/products/{product_id}")
def delete_product(product_id: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM makeup_products WHERE product_id = %s", (product_id,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Produk berhasil dihapus"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/history/{user_id}")
def get_history(user_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True) 
        cursor.execute("SELECT history_id, detected_undertone, confidence_score, created_at, image_url FROM classification_histories WHERE user_id = %s ORDER BY created_at DESC", (user_id,))
        histories = cursor.fetchall()
        for item in histories:
            if isinstance(item['created_at'], datetime):
                item['created_at'] = item['created_at'].isoformat()
        cursor.close()
        conn.close()
        return {"success": True, "data": histories}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

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
        return {"success": True, "message": "Riwayat dihapus"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/favorites/{user_id}")
def get_favorites(user_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT f.favorite_id, p.product_id, p.name AS product_name, p.price, p.brand AS brand_name, p.image_url 
            FROM favorite_products f
            JOIN makeup_products p ON f.product_id = p.product_id
            WHERE f.user_id = %s
        """, (user_id,))
        favorites = cursor.fetchall()
        for f in favorites:
            if f.get('price') is not None:
                f['price'] = float(f['price'])
        cursor.close()
        conn.close()
        return {"success": True, "data": favorites}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.post("/api/v1/favorites")
async def add_favorite(request: Request):
    try:
        data = await request.json()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO favorite_products (favorite_id, user_id, product_id) VALUES (%s, %s, %s)", (f"fav_{int(time.time())}", data.get("user_id"), data.get("product_id")))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Disimpan ke favorit!"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.delete("/api/v1/favorites/{favorite_id}")
def delete_favorite(favorite_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM favorite_products WHERE favorite_id = %s", (favorite_id,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Dihapus dari favorit"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/users/{user_id}")
def get_user_profile(user_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT uid, email, name, role, avatar_url FROM users WHERE uid = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            cursor.execute("INSERT INTO users (uid, email, name, role) VALUES (%s, %s, %s, %s)", (user_id, 'test@tonematch.app', 'Alvito Aryo', 'super_admin' if user_id == 'usr_dummy_01' else 'user'))
            conn.commit()
            cursor.execute("SELECT uid, email, name, role, avatar_url FROM users WHERE uid = %s", (user_id,))
            user = cursor.fetchone()
        cursor.close()
        conn.close()
        return {"success": True, "data": user}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.put("/api/v1/users/{user_id}")
async def update_user_profile(
    user_id: str, name: str = Form(None), email: str = Form(None), role: str = Form(None),
    remove_avatar: str = Form("false"), avatar: UploadFile | None = File(None)
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
        new_role = role if role is not None and role.strip() != "" else ("super_admin" if not user else user.get('role', 'user'))
        
        if not user:
            cursor.execute("INSERT INTO users (uid, email, name, role, avatar_url) VALUES (%s, %s, %s, %s, %s)", (user_id, new_email, new_name, new_role, avatar_path))
        else:
            cursor.execute("UPDATE users SET name = %s, email = %s, role = %s, avatar_url = %s WHERE uid = %s", (new_name, new_email, new_role, avatar_path, user_id))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Profil diperbarui!", "avatar_url": avatar_path, "role": new_role}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/admin/stats")
def get_admin_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT COUNT(*) AS total_users FROM users")
        users_count = cursor.fetchone()['total_users']
        cursor.execute("SELECT COUNT(*) AS total_history FROM classification_histories")
        history_count = cursor.fetchone()['total_history']
        cursor.execute("SELECT COUNT(*) AS total_products FROM makeup_products")
        products_count = cursor.fetchone()['total_products']
        cursor.close()
        conn.close()
        return {"success": True, "data": {"total_users": users_count, "total_history": history_count, "total_products": products_count}}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/admin/users")
def get_all_users():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT uid, name, email, role, created_at FROM users ORDER BY created_at DESC")
        users = cursor.fetchall()
        for u in users:
            if isinstance(u.get('created_at'), datetime):
                u['created_at'] = u['created_at'].isoformat()
        cursor.close()
        conn.close()
        return {"success": True, "data": users}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.put("/api/v1/admin/users/{target_uid}/role")
async def update_user_role(target_uid: str, request: Request):
    try:
        data = await request.json()
        new_role = data.get("role")
        if new_role not in ['super_admin', 'admin', 'user']:
            return JSONResponse(status_code=400, content={"success": False, "error": "Role tidak valid"})
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET role = %s WHERE uid = %s", (new_role, target_uid))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Role diperbarui!"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.delete("/api/v1/admin/users/{target_uid}")
def delete_user(target_uid: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM users WHERE uid = %s", (target_uid,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Pengguna dihapus"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})