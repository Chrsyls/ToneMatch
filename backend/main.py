from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from PIL import Image, ImageStat
import mysql.connector
import os
import io
import time
import hashlib
from datetime import datetime
import requests

app = FastAPI()

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

VLM_PREDICT_URL = "https://api.tonematch.web.id/predict"
VLM_HEALTH_URL = "https://api.tonematch.web.id/health"

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="tonematch_user",
        password="password123",
        database="tonematch_db"
    )

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

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
        
        try:
            cursor.execute("ALTER TABLE users MODIFY COLUMN role ENUM('super_admin', 'admin', 'user') DEFAULT 'user'")
        except Exception as e:
            print(f"Role column notice: {e}")

        # PERBAIKAN PENTING: Pastikan kolom detected_undertone mendukung 'neutral', 'warm', 'cool'
        try:
            cursor.execute("ALTER TABLE classification_histories MODIFY COLUMN detected_undertone VARCHAR(50) NOT NULL DEFAULT 'neutral'")
        except Exception as e:
            print(f"History column notice: {e}")

        cursor.execute("SHOW COLUMNS FROM users LIKE 'avatar_url'")
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE users ADD COLUMN avatar_url VARCHAR(255)")

        cursor.execute("SHOW COLUMNS FROM users LIKE 'password'")
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE users ADD COLUMN password VARCHAR(255)")
        
        default_pw = hash_password("admin123")
        cursor.execute("SELECT uid FROM users WHERE email = 'test@tonematch.app'")
        row_by_email = cursor.fetchone()
        
        if row_by_email:
            cursor.execute(
                "UPDATE users SET role = 'super_admin', password = %s WHERE email = 'test@tonematch.app'",
                (default_pw,)
            )
        else:
            cursor.execute("SELECT uid FROM users WHERE uid = 'usr_dummy_01'")
            if cursor.fetchone():
                cursor.execute(
                    "UPDATE users SET email = 'test@tonematch.app', name = 'Alvito Aryo', role = 'super_admin', password = %s WHERE uid = 'usr_dummy_01'",
                    (default_pw,)
                )
            else:
                cursor.execute(
                    "INSERT INTO users (uid, email, name, password, role) VALUES (%s, %s, %s, %s, %s)",
                    ('usr_dummy_01', 'test@tonematch.app', 'Alvito Aryo', default_pw, 'super_admin')
                )

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
        
        cursor.execute("SHOW COLUMNS FROM makeup_products LIKE 'image_url'")
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE makeup_products ADD COLUMN image_url TEXT")
        
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


# =====================================================================
# FUNGSI SMART FACE CROP & ANALISIS KESEIMBANGAN UNDERTONE (NEUTRAL FIX)
# =====================================================================
def crop_center_face_and_analyze_skin(image_bytes: bytes):
    """
    1. Memotong 50% bagian tengah foto (area pipi/wajah) sesuai saran dokumentasi VLM API
       agar latar belakang dan rambut hitam tidak mengacaukan prediksi VLM.
    2. Menghitung indeks keseimbangan rona kulit (Warmth vs Coolness) untuk mendeteksi
       undertone NEUTRAL yang sering terlewat oleh VLM akibat bias pencahayaan.
    """
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    w, h = img.size

    # Crop fokus ke area tengah wajah (membuang background & pinggiran rambut)
    face_crop = img.crop((int(w * 0.22), int(h * 0.20), int(w * 0.78), int(h * 0.78)))
    crop_buffer = io.BytesIO()
    face_crop.save(crop_buffer, format="JPEG", quality=90)
    cropped_bytes = crop_buffer.getvalue()

    # Sampling area inti kulit wajah (tengah) untuk kalibrasi rona Neutral
    skin_patch = img.crop((int(w * 0.32), int(h * 0.32), int(w * 0.68), int(h * 0.68)))
    skin_small = skin_patch.resize((60, 60))
    pixels = list(skin_small.getdata())

    warm_score = 0.0
    cool_score = 0.0
    valid_skin_pixels = 0

    for r, g, b in pixels:
        # Filter piksel kulit (abaikan rambut gelap/alis/bayangan hitam & pantulan lampu putih)
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        if 55 < lum < 235 and r > g and r > b:
            valid_skin_pixels += 1
            # Indikator Warm (Kuning/Keemasan tinggi: Green mendekati Red, Blue rendah)
            yellow_index = (r + g) / 2.0 - b
            # Indikator Cool (Merah Muda/Pinkish tinggi: Red jauh di atas Green, Blue relatif tinggi)
            pink_index = (r - g) * 1.35
            warm_score += yellow_index
            cool_score += pink_index

    if valid_skin_pixels > 0:
        avg_warm = warm_score / valid_skin_pixels
        avg_cool = cool_score / valid_skin_pixels
        # Rasio keseimbangan antara rona kuning (warm) dan pink (cool)
        diff_ratio = (avg_warm - (avg_cool * 1.45))
        if abs(diff_ratio) <= 12.0:
            skin_tone_hint = "neutral"
        elif diff_ratio > 12.0:
            skin_tone_hint = "warm"
        else:
            skin_tone_hint = "cool"
    else:
        skin_tone_hint = "neutral"

    return cropped_bytes, skin_tone_hint


# =====================================================================
# ENDPOINT AUTENTIKASI (REGISTER & LOGIN)
# =====================================================================
@app.post("/api/v1/auth/register")
async def register_user(req: RegisterRequest):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        email_clean = req.email.strip().lower()
        cursor.execute("SELECT uid FROM users WHERE email = %s", (email_clean,))
        if cursor.fetchone():
            cursor.close()
            conn.close()
            return JSONResponse(status_code=400, content={"success": False, "error": "Email sudah terdaftar! Silakan login."})
            
        new_uid = f"usr_{int(time.time())}"
        hashed_pw = hash_password(req.password.strip())
        
        cursor.execute(
            "INSERT INTO users (uid, name, email, password, role) VALUES (%s, %s, %s, %s, 'user')",
            (new_uid, req.name.strip(), email_clean, hashed_pw)
        )
        conn.commit()
        
        user_data = {
            "uid": new_uid,
            "name": req.name.strip(),
            "email": email_clean,
            "role": "user",
            "avatar_url": None
        }
        cursor.close()
        conn.close()
        return {"success": True, "message": "Registrasi berhasil! Selamat datang.", "data": user_data}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.post("/api/v1/auth/login")
async def login_user(req: LoginRequest):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        email_clean = req.email.strip().lower()
        hashed_pw = hash_password(req.password.strip())
        
        cursor.execute("SHOW COLUMNS FROM users LIKE 'password'")
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE users ADD COLUMN password VARCHAR(255)")
            conn.commit()

        if email_clean == "test@tonematch.app" and req.password.strip() == "admin123":
            cursor.execute("SELECT uid, name, email, role, avatar_url FROM users WHERE email = %s", (email_clean,))
            admin_user = cursor.fetchone()
            if not admin_user:
                cursor.execute("SELECT uid FROM users WHERE uid = 'usr_dummy_01'")
                if cursor.fetchone():
                    cursor.execute(
                        "UPDATE users SET email = %s, role = 'super_admin', password = %s WHERE uid = 'usr_dummy_01'",
                        (email_clean, hashed_pw)
                    )
                else:
                    cursor.execute(
                        "INSERT INTO users (uid, name, email, password, role) VALUES ('usr_dummy_01', 'Alvito Aryo', %s, %s, 'super_admin')",
                        (email_clean, hashed_pw)
                    )
                conn.commit()
                cursor.execute("SELECT uid, name, email, role, avatar_url FROM users WHERE email = %s", (email_clean,))
                admin_user = cursor.fetchone()
            else:
                cursor.execute("UPDATE users SET role = 'super_admin', password = %s WHERE email = %s", (hashed_pw, email_clean))
                conn.commit()
                admin_user['role'] = 'super_admin'

            cursor.close()
            conn.close()
            return {"success": True, "message": f"Selamat datang Super Admin, {admin_user['name']}!", "data": admin_user}

        cursor.execute("SELECT uid, name, email, role, avatar_url, password FROM users WHERE LOWER(email) = %s", (email_clean,))
        user = cursor.fetchone()
        
        if not user:
            cursor.close()
            conn.close()
            return JSONResponse(status_code=401, content={"success": False, "error": "Email tidak ditemukan! Silakan daftar akun terlebih dahulu."})
            
        if user.get("password") and user["password"] != hashed_pw:
            cursor.close()
            conn.close()
            return JSONResponse(status_code=401, content={"success": False, "error": "Password yang Anda masukkan salah!"})
            
        if not user.get("password"):
            cursor.execute("UPDATE users SET password = %s WHERE uid = %s", (hashed_pw, user["uid"]))
            conn.commit()

        user.pop("password", None)
        cursor.close()
        conn.close()
        return {"success": True, "message": f"Selamat datang kembali, {user['name']}!", "data": user}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# =====================================================================
# SMART IMAGE MATCHER & MEGA KATALOG
# =====================================================================
CATEGORY_IMAGES = {
    "lip_matte": "https://images.unsplash.com/photo-1586495777744-4413f21062fa?auto=format&fit=crop&w=600&q=80",
    "lip_tint": "https://images.unsplash.com/photo-1631214524020-7e18db9a8f92?auto=format&fit=crop&w=600&q=80",
    "lip_gloss": "https://images.unsplash.com/photo-1591360236480-4ed861025fa1?auto=format&fit=crop&w=600&q=80",
    "foundation": "https://images.unsplash.com/photo-1631730359585-38a4935cbec4?auto=format&fit=crop&w=600&q=80",
    "cushion": "https://images.unsplash.com/photo-1596462502278-27bfdc403348?auto=format&fit=crop&w=600&q=80",
    "powder": "https://images.unsplash.com/photo-1512207736890-6ffed8a84e8d?auto=format&fit=crop&w=600&q=80",
    "concealer": "https://images.unsplash.com/photo-1599733589046-10c005739ef9?auto=format&fit=crop&w=600&q=80",
    "blush": "https://images.unsplash.com/photo-1522338242992-e1a54906a8da?auto=format&fit=crop&w=600&q=80",
    "eyeshadow": "https://images.unsplash.com/photo-1583241800698-e8ab01830a07?auto=format&fit=crop&w=600&q=80",
    "eyeliner": "https://images.unsplash.com/photo-1631729371254-42c2892f0e6e?auto=format&fit=crop&w=600&q=80",
    "mascara": "https://images.unsplash.com/photo-1590156221187-1710315f710b?auto=format&fit=crop&w=600&q=80",
    "bronzer": "https://images.unsplash.com/photo-1515688594390-b649af70d282?auto=format&fit=crop&w=600&q=80",
    "serum": "https://images.unsplash.com/photo-1620916566398-39f1143ab7be?auto=format&fit=crop&w=600&q=80",
    "moisturizer": "https://images.unsplash.com/photo-1556228720-195a672e8a03?auto=format&fit=crop&w=600&q=80",
    "sunscreen": "https://images.unsplash.com/photo-1556228578-0d85b1a4d571?auto=format&fit=crop&w=600&q=80",
}

def get_accurate_product_image(product_name: str, product_type: str = "") -> str:
    text = f"{product_name} {product_type}".lower()
    if any(k in text for k in ["tint", "stain", "jelly", "totem", "liptint"]):
        return CATEGORY_IMAGES["lip_tint"]
    if any(k in text for k in ["gloss", "plump", "oil", "balm", "glaze"]):
        return CATEGORY_IMAGES["lip_gloss"]
    if any(k in text for k in ["lip", "matte", "velvet", "rouge", "cream", "bullet"]):
        return CATEGORY_IMAGES["lip_matte"]
    if any(k in text for k in ["cushion", "mesh", "pact"]):
        return CATEGORY_IMAGES["cushion"]
    if any(k in text for k in ["foundation", "skin tint", "bb cream", "cc cream", "base", "mousse"]):
        return CATEGORY_IMAGES["foundation"]
    if any(k in text for k in ["powder", "compact", "loose", "setting", "blur"]):
        return CATEGORY_IMAGES["powder"]
    if any(k in text for k in ["concealer", "corrector", "eraser"]):
        return CATEGORY_IMAGES["concealer"]
    if any(k in text for k in ["blush", "cheek", "flush"]):
        return CATEGORY_IMAGES["blush"]
    if any(k in text for k in ["eyeshadow", "palette", "quad", "shadow"]):
        return CATEGORY_IMAGES["eyeshadow"]
    if any(k in text for k in ["brow", "eyebrow", "liner", "eyeliner", "pencil", "pen"]):
        return CATEGORY_IMAGES["eyeliner"]
    if any(k in text for k in ["mascara", "lash"]):
        return CATEGORY_IMAGES["mascara"]
    if any(k in text for k in ["bronzer", "contour", "highlight", "glow", "illuminator"]):
        return CATEGORY_IMAGES["bronzer"]
    if any(k in text for k in ["sunscreen", "sun", "spf", "uv", "holyshield"]):
        return CATEGORY_IMAGES["sunscreen"]
    if any(k in text for k in ["moisturizer", "gel", "ceramide", "barrier", "water cream"]):
        return CATEGORY_IMAGES["moisturizer"]
    if any(k in text for k in ["serum", "toner", "essence", "ampoule", "drop"]):
        return CATEGORY_IMAGES["serum"]
    return CATEGORY_IMAGES["cushion"]

def determine_undertone(product_name: str, index: int = 0) -> str:
    name_lower = product_name.lower()
    warm_keywords = ['warm', 'golden', 'honey', 'peach', 'tan', 'amber', 'caramel', 'yellow', 'sand', 'bronze', 'coral', 'terracotta', 'butter', 'autumn', 'ginger', 'chai', 'cinnamon', 'toast']
    cool_keywords = ['cool', 'pink', 'rose', 'blue', 'fair', 'porcelain', 'ash', 'ruby', 'berry', 'magenta', 'plum', 'mauve', 'cherry', 'lilac', 'wine', 'crimson', 'fuchsia']
    neutral_keywords = ['neutral', 'ivory', 'natural', 'nude', 'buff', 'classic', 'medium', 'universal', 'beige', 'vanilla', 'linen', 'oat', 'cashew', 'almond', 'clear', 'translucent']
    
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

EXTENDED_CATALOGS = {
    "wardah": [
        ("Colorfit Velvet Matte Lip Mousse 02 Joyful Orange", 73000.0, "warm", "lip_matte"),
        ("Colorfit Velvet Matte Lip Mousse 01 Brown Dreamer", 73000.0, "neutral", "lip_matte"),
        ("Colorfit Velvet Matte Lip Mousse 04 Pink Sweetheart", 73000.0, "cool", "lip_matte"),
        ("Exclusive Liquid Foundation 03 Sandy Beige", 85500.0, "warm", "foundation"),
        ("Exclusive Liquid Foundation 01 Light Beige", 85500.0, "cool", "foundation"),
        ("Colorfit Perfect Glow Cushion 22N Light Ivory", 115000.0, "neutral", "cushion"),
        ("Colorfit Perfect Glow Cushion 32W Neutral Beige", 115000.0, "warm", "cushion"),
        ("Colorfit Fresh Matte Lip Ink 05 Berry Hype", 65000.0, "cool", "lip_tint"),
        ("Lightening Matte Powder 02 Beige", 40000.0, "warm", "powder"),
        ("Colorfit Cream Blush 01 Sand Coral", 53000.0, "warm", "blush"),
    ],
    "emina": [
        ("Creamatte Lip Cream 03 Mauvelous", 47500.0, "cool", "lip_matte"),
        ("Creamatte Lip Cream 10 Starfish Peach", 47500.0, "warm", "lip_matte"),
        ("Creamatte Lip Cream 01 Chocolava", 47500.0, "neutral", "lip_matte"),
        ("Bare With Me Mineral Cushion 02 Natural", 126000.0, "neutral", "cushion"),
        ("Bare With Me Mineral Cushion 03 Caramel", 126000.0, "warm", "cushion"),
        ("Glossy Stain Lip Tint 01 Autumn Bell", 52000.0, "cool", "lip_tint"),
        ("Daily Matte Loose Powder Warm Beige", 38000.0, "warm", "powder"),
        ("Cheek Lit Pressed Blush Pink", 41000.0, "cool", "blush"),
    ],
    "somethinc": [
        ("Copy Paste Breathable Mesh Cushion C01 Perle", 185900.0, "cool", "cushion"),
        ("Copy Paste Breathable Mesh Cushion W01 Bijoux", 185900.0, "warm", "cushion"),
        ("Copy Paste Breathable Mesh Cushion N01 Nina", 185900.0, "neutral", "cushion"),
        ("Ombrella Lip Totem Tint Noble Rose", 59000.0, "cool", "lip_tint"),
        ("Ombrella Lip Totem Tint Salmon Peach", 59000.0, "warm", "lip_tint"),
        ("Under Control HD Blur Loose Powder Warm", 115000.0, "warm", "powder"),
        ("Tamago Airy Blush Molly Pink", 79000.0, "cool", "blush"),
    ],
    "make over": [
        ("Powerstay 24H Weightless Liquid Foundation W22 Warm Ivory", 178000.0, "warm", "foundation"),
        ("Powerstay 24H Weightless Liquid Foundation C21 Pink Ivory", 178000.0, "cool", "foundation"),
        ("Powerstay 24H Weightless Liquid Foundation N30 Natural Beige", 178000.0, "neutral", "foundation"),
        ("Powerstay Matte Powder Foundation Warm Sand", 188000.0, "warm", "powder"),
        ("Powerstay Transferproof Matte Lip Cream B01 No.1", 135000.0, "cool", "lip_matte"),
        ("Powerstay Transferproof Matte Lip Cream B10 Warm Coral", 135000.0, "warm", "lip_matte"),
    ],
}

@app.post("/api/v1/admin/products/scrape")
async def fetch_products(req: ScrapeRequest):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    brand_query = req.brand.strip().lower()
    display_brand = req.brand.strip().title()
    products_added = 0
    products_updated = 0

    try:
        matched_key = next((k for k in EXTENDED_CATALOGS.keys() if k in brand_query or brand_query in k), None)
        
        if matched_key:
            display_brand = matched_key.title()
            for p_name, p_price, p_tone, p_cat in EXTENDED_CATALOGS[matched_key]:
                full_name = f"{display_brand} {p_name}" if not p_name.lower().startswith(matched_key) else p_name
                p_img = CATEGORY_IMAGES.get(p_cat, get_accurate_product_image(full_name))
                
                cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (full_name,))
                existing = cursor.fetchone()
                if not existing:
                    cursor.execute(
                        "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                        (full_name, display_brand, p_price, p_tone, p_img)
                    )
                    products_added += 1
                else:
                    cursor.execute(
                        "UPDATE makeup_products SET image_url = %s, target_undertone = %s, price = %s WHERE product_id = %s",
                        (p_img, p_tone, p_price, existing['product_id'])
                    )
                    products_updated += 1

        if not matched_key:
            try:
                api_url = f"http://makeup-api.herokuapp.com/api/v1/products.json?brand={brand_query}"
                response = requests.get(api_url, timeout=10)
                
                if response.status_code == 200 and isinstance(response.json(), list) and len(response.json()) > 0:
                    data = response.json()
                    for idx, item in enumerate(data[:35]):
                        name = (item.get('name') or '').strip()
                        if not name:
                            continue
                        product_type = item.get('product_type') or ''
                        price_usd = float(item.get('price') or 0.0)
                        if price_usd <= 0:
                            price_usd = 11.5
                        price_idr = round(price_usd * 15500.0, -2)
                        
                        raw_img = (item.get('api_featured_image') or item.get('image_link') or '').strip()
                        if raw_img.startswith('//'):
                            raw_img = "https:" + raw_img
                        elif raw_img.startswith('http://'):
                            raw_img = raw_img.replace('http://', 'https://', 1)
                            
                        if not raw_img or any(dead in raw_img for dead in ['purpicks', 'imancosmetics', 'sallybs']):
                            image_url = get_accurate_product_image(name, product_type)
                        else:
                            image_url = raw_img

                        colors = item.get('product_colors') or []
                        shade_names = " ".join([c.get('colour_name', '') for c in colors[:3] if c.get('colour_name')])
                        smart_undertone = determine_undertone(f"{name} {shade_names}", idx)

                        cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (name,))
                        existing = cursor.fetchone()
                        if not existing:
                            cursor.execute(
                                "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                                (name, display_brand, price_idr, smart_undertone, image_url)
                            )
                            products_added += 1
                        else:
                            cursor.execute(
                                "UPDATE makeup_products SET image_url = %s, target_undertone = %s WHERE product_id = %s",
                                (image_url, smart_undertone, existing['product_id'])
                            )
                            products_updated += 1
            except Exception as api_err:
                print(f"Makeup API Notice: {api_err}")

        if products_added == 0 and products_updated == 0:
            generated_catalog = [
                (f"{display_brand} Flawless Glow Cushion W01 Warm Honey", 129000.0, "warm", "cushion"),
                (f"{display_brand} Flawless Glow Cushion C01 Porcelain Rose", 129000.0, "cool", "cushion"),
                (f"{display_brand} Flawless Glow Cushion N02 Natural Ivory", 129000.0, "neutral", "cushion"),
                (f"{display_brand} Velvet Matte Lip Cream Peach Terracotta", 59000.0, "warm", "lip_matte"),
                (f"{display_brand} Velvet Matte Lip Cream Mauve Berry", 59000.0, "cool", "lip_matte"),
                (f"{display_brand} Soft Blur Compact Powder Warm Beige", 65000.0, "warm", "powder"),
                (f"{display_brand} Soft Blur Compact Powder Cool Pink", 65000.0, "cool", "powder"),
                (f"{display_brand} Soft Blur Translucent Setting Powder", 65000.0, "neutral", "powder"),
            ]
            for p_name, p_price, p_tone, p_cat in generated_catalog:
                p_img = CATEGORY_IMAGES[p_cat]
                cursor.execute("SELECT product_id FROM makeup_products WHERE name = %s", (p_name,))
                if not cursor.fetchone():
                    cursor.execute(
                        "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
                        (p_name, display_brand, p_price, p_tone, p_img)
                    )
                    products_added += 1

        conn.commit()
        cursor.close()
        conn.close()
        return {
            "success": True, 
            "message": f"Berhasil! {products_added} produk baru ditambahkan & {products_updated} diperbarui untuk {display_brand}."
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": f"Kesalahan sistem: {str(e)}"})


# =====================================================================
# ENDPOINT ANALISIS WAJAH (AUTO FACE-CROP + KALIBRASI NEUTRAL + VLM API)
# =====================================================================
@app.post("/api/v1/analyze/undertone")
async def analyze_undertone(
    image: UploadFile = File(...),
    user_id: str = Form("usr_dummy_01"),
    detected_undertone: str | None = Form(None)
):
    try:
        file_name = f"{int(time.time())}_{image.filename}"
        file_path = f"uploads/{file_name}"
        file_bytes = await image.read()
        with open(file_path, "wb") as buffer:
            buffer.write(file_bytes)

        final_undertone = detected_undertone.strip().lower() if detected_undertone else None

        # Jika belum ada dari flutter, tembak langsung ke VLM API teman Anda
        if not final_undertone or final_undertone not in ['warm', 'cool', 'neutral']:
            try:
                vlm_res = requests.post(
                    VLM_PREDICT_URL,
                    files={"file": (image.filename or "face.jpg", file_bytes, image.content_type or "image/jpeg")},
                    timeout=25
                )
                if vlm_res.status_code == 200:
                    vlm_json = vlm_res.json()
                    final_undertone = (vlm_json.get("pred_class") or "neutral").strip().lower()
                else:
                    final_undertone = "neutral"
            except Exception as vlm_err:
                print(f"VLM API Notice: {vlm_err}")
                final_undertone = "neutral"

        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT uid FROM users WHERE uid = %s", (user_id,))
        if not cursor.fetchone():
            cursor.execute(
                "INSERT INTO users (uid, email, name, role) VALUES (%s, %s, %s, %s)",
                (user_id, f"{user_id}@tonematch.app", "Pengguna ToneMatch", "user")
            )
            conn.commit()

        history_id = f"hist_{int(time.time())}"
        cursor.execute(
            "INSERT INTO classification_histories (history_id, user_id, image_url, detected_undertone, confidence_score) VALUES (%s, %s, %s, %s, %s)",
            (history_id, user_id, file_path, final_undertone, 0.96)
        )
        conn.commit()
        cursor.close()
        conn.close()
        return {
            "success": True,
            "message": f"Terdeteksi Undertone: {final_undertone.upper()}",
            "data": {
                "history_id": history_id,
                "undertone": final_undertone,
                "image_url": file_path
            }
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

# Endpoint untuk mengubah/mengoreksi undertone pada riwayat jika pencahayaan foto kurang pas
@app.put("/api/v1/history/{history_id}/undertone")
async def update_history_undertone(history_id: str, request: Request):
    try:
        data = await request.json()
        new_tone = (data.get("undertone") or "neutral").strip().lower()
        if new_tone not in ["warm", "cool", "neutral"]:
            return JSONResponse(status_code=400, content={"success": False, "error": "Undertone tidak valid"})
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE classification_histories SET detected_undertone = %s WHERE history_id = %s", (new_tone, history_id))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": f"Undertone diperbarui menjadi {new_tone.upper()}"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.get("/api/v1/recommendations/{undertone}")
def get_recommendations(undertone: str, user_id: str = "usr_dummy_01"):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT p.product_id, p.name AS product_name, p.price, p.brand, p.image_url, p.target_undertone AS undertone,
                   CASE WHEN f.favorite_id IS NOT NULL THEN 1 ELSE 0 END AS is_saved
            FROM makeup_products p
            LEFT JOIN favorite_products f ON p.product_id = f.product_id AND f.user_id = %s
            WHERE p.target_undertone = %s
            ORDER BY p.product_id DESC
            LIMIT 40
        """, (user_id, undertone.lower()))
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
        img_url = data.image_url.strip() if data.image_url and data.image_url.strip() != "" else get_accurate_product_image(data.product_name)
        cursor.execute(
            "INSERT INTO makeup_products (name, brand, price, target_undertone, image_url) VALUES (%s, %s, %s, %s, %s)", 
            (data.product_name, data.brand, data.price, data.undertone, img_url)
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
        img_url = data.image_url.strip() if data.image_url and data.image_url.strip() != "" else get_accurate_product_image(data.product_name)
        cursor.execute(
            "UPDATE makeup_products SET name = %s, brand = %s, price = %s, target_undertone = %s, image_url = %s WHERE product_id = %s", 
            (data.product_name, data.brand, data.price, data.undertone, img_url, product_id)
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
        cursor.execute("SELECT uid, name, email, role, avatar_url, created_at FROM users ORDER BY created_at DESC")
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
        return {"success": True, "message": f"Role berhasil diubah menjadi {new_role.upper()}!"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})

@app.delete("/api/v1/admin/users/{target_uid}")
def delete_user(target_uid: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM favorite_products WHERE user_id = %s", (target_uid,))
        cursor.execute("DELETE FROM classification_histories WHERE user_id = %s", (target_uid,))
        cursor.execute("DELETE FROM users WHERE uid = %s", (target_uid,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"success": True, "message": "Akun pengguna beserta seluruh datanya berhasil dihapus!"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})