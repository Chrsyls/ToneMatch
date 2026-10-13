from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import mysql.connector
import os
import time
from datetime import datetime
import requests
import urllib.parse
from bs4 import BeautifulSoup

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

def determine_undertone(product_name: str, index: int = 0) -> str:
    name_lower = product_name.lower()
    warm_keywords = ['warm', 'golden', 'honey', 'peach', 'tan', 'amber', 'caramel', 'yellow', 'sand', 'bronze']
    cool_keywords = ['cool', 'pink', 'rose', 'blue', 'fair', 'porcelain', 'ash', 'ruby', 'berry', 'magenta']
    neutral_keywords = ['neutral', 'ivory', 'natural', 'nude', 'buff', 'classic', 'medium', 'universal']
    
    for kw in warm_keywords:
        if kw in name_lower:
            return 'warm'
    for kw in cool_keywords:
        if kw in name_lower:
            return 'cool'
    for kw in neutral_keywords:
        if kw in name_lower:
            return 'neutral'
            
    distribution = ['warm', 'cool', 'neutral']
    return distribution[index % len(distribution)]


@app.post("/api/v1/admin/products/scrape")
async def fetch_products(req: ScrapeRequest):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    brand_query = req.brand.strip().lower()
    display_brand = req.brand.strip().title()
    products_added = 0

    try:
        api_url = f"http://makeup-api.herokuapp.com/api/v1/products.json?brand={brand_query}"
        response = requests.get(api_url, timeout=8)
        
        if response.status_code == 200 and len(response.json()) > 0:
            data = response.json()
            for idx, item in enumerate(data[:20]):
                name = item.get('name')
                price_usd = float(item.get('price') or 12.0)
                price_idr = price_usd * 15500.0
                image_url = item.get('image_link', '')
                if image_url and image_url.startswith('//'):
                    image_url = "https:" + image_url

                if name:
                    smart_undertone = determine_undertone(name, idx)
                    cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (name,))
                    if not cursor.fetchone():
                        cursor.execute(
                            "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                            (name, display_brand, price_idr, smart_undertone, image_url)
                        )
                        products_added += 1

        extended_local_catalogs = {
            "wardah": [
                ("Colorfit Velvet Matte Lip Mousse", 73000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                ("Exclusive Liquid Foundation Warm Sand", 82000.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e"),
                ("Lightening Face Toner", 24000.0, "https://images.unsplash.com/photo-1620916566398-39f1143ab7be"),
                ("Colorfit Fresh Matte Lip Ink Rose", 65000.0, "https://images.unsplash.com/photo-1631729371254-42c2892f0e6e"),
                ("Lightening Liquid Concealer Ivory", 41000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796")
            ],
            "emina": [
                ("Creamatte Lip Cream Peach", 47500.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                ("Bare with Me Mineral Cushion Natural", 126000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                ("Glossy Stain Lip Tint Berry", 49000.0, "https://images.unsplash.com/photo-1631729371254-42c2892f0e6e"),
                ("Daily Matte Loose Powder", 62000.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e")
            ],
            "somethinc": [
                ("Copy Paste Breathable Cushion Golden", 185900.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                ("Ombrella Lip Totem Tint Rose", 59000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                ("Holyshield! Sunscreen Corrector", 149000.0, "https://images.unsplash.com/photo-1620916566398-39f1143ab7be"),
                ("Diamond Phyto Serum", 139000.0, "https://images.unsplash.com/photo-1556228720-195a672e8a03")
            ],
            "blp": [
                ("Lip Coat Butter Peach", 139000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                ("Face Powder Medium Beige", 149000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                ("Eye Brow Definition", 120000.0, "https://images.unsplash.com/photo-1631729371254-42c2892f0e6e")
            ],
            "skintific": [
                ("5X Ceramide Barrier Repair Gel", 139000.0, "https://images.unsplash.com/photo-1556228720-195a672e8a03"),
                ("Cover All Perfect Cushion Ivory", 169000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                ("All Day Light Sunscreen Mist", 109000.0, "https://images.unsplash.com/photo-1620916566398-39f1143ab7be")
            ],
            "make over": [
                ("Powerstay Matte Powder Foundation Warm", 175000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                ("Hydrastay Liquid Whip Foundation Rose", 165000.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e"),
                ("Rouge Power Matte Lip Cream", 129000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa")
            ],
            "esqa": [
                ("Flawless Liquid Concealer Natural", 145000.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e"),
                ("Goddess Eyeshadow Palette", 195000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                ("Slick Lip Tint Berry", 125000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa")
            ],
            "mop": [
                ("Mother of Pearl Blur Setting Powder", 159000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796"),
                ("MOP Eyeshadow Palette Golden", 289000.0, "https://images.unsplash.com/photo-1631729371254-42c2892f0e6e"),
                ("Anti Socialite Liquid Lipstick", 129000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa")
            ]
        }

        matched_key = next((k for k in extended_local_catalogs.keys() if k in brand_query), None)
        
        if matched_key:
            for idx, (p_name, p_price, p_img) in enumerate(extended_local_catalogs[matched_key]):
                smart_undertone = determine_undertone(p_name, idx)
                cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (p_name,))
                if not cursor.fetchone():
                    cursor.execute(
                        "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                        (p_name, display_brand, p_price, smart_undertone, p_img)
                    )
                    products_added += 1

        if products_added == 0 and len(response.json()) == 0:
            dynamic_defaults = [
                (f"{display_brand} Signature Matte Golden Lipstick", 129000.0, "https://images.unsplash.com/photo-1586495777744-4413f21062fa"),
                (f"{display_brand} Perfect Glow Pink Foundation", 189000.0, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e"),
                (f"{display_brand} Translucent Neutral Setting Powder", 115000.0, "https://images.unsplash.com/photo-1512496015851-a90fb38ba796")
            ]
            for idx, (p_name, p_price, p_img) in enumerate(dynamic_defaults):
                smart_undertone = determine_undertone(p_name, idx)
                cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (p_name,))
                if not cursor.fetchone():
                    cursor.execute(
                        "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                        (p_name, display_brand, p_price, smart_undertone, p_img)
                    )
                    products_added += 1

        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": f"Berhasil menambah {products_added} produk untuk {display_brand}."}

    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": f"Kesalahan sistem: {str(e)}"})


@app.get("/api/v1/recommendations/{undertone}")
def get_recommendations(undertone: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        # HANYA mengambil produk yang persis sesuai dengan undertone terdeteksi
        cursor.execute("""
            SELECT p.product_id, p.name AS product_name, p.price, p.brand, p.image_url, p.target_undertone AS undertone,
                   CASE WHEN f.favorite_id IS NOT NULL THEN 1 ELSE 0 END AS is_saved
            FROM makeup_products p
            LEFT JOIN favorite_products f ON p.product_id = f.product_id AND f.user_id = 'usr_dummy_01'
            WHERE p.target_undertone = %s
            LIMIT 20
        """, (undertone.lower(),))
        products = cursor.fetchall()
        for p in products:
            if p.get('price') is not None:
                p['price'] = float(p['price'])
            p['is_saved'] = bool(p['is_saved'])
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

@app.delete("/api/v1/favorites/{user_id}/{product_id}")
def delete_favorite_by_product(user_id: str, product_id: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM favorite_products WHERE user_id = %s AND product_id = %s", (user_id, product_id))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Dihapus dari favorit"}
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
def update_user_profile(
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
                buffer.write(avatar.file.read())
        
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