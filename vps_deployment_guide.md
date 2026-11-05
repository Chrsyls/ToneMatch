# 🚀 ToneMatch VPS Setup & Migration Guide

Panduan lengkap ini digunakan untuk melakukan setup baru atau memindahkan (*migration*) backend dan database **ToneMatch** ke Virtual Private Server (VPS) yang baru (Ubuntu 22.04 LTS / 24.04 LTS disarankan).

---

## 📋 Prasyarat Sistem
Pastikan VPS Anda memiliki komponen berikut terinstal:
- **OS:** Ubuntu Linux (22.04 / 24.04)
- **Database:** MySQL Server / MariaDB
- **Runtime:** Python 3.10+ (untuk FastAPI/Flask Backend) & Node.js / Flutter SDK (jika melakukan build APK di VPS)
- **Web Server / Proxy:** Nginx & UFW (Firewall)

---

## 🛠️ Langkah 1: Update Sistem & Instalasi Dependensi Dasar
Masuk ke VPS via SSH, lalu jalankan perintah berikut untuk memperbarui paket sistem:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl git build-essential ufw nginx python3-pip python3-venv mariadb-server -y
```

---

## 🗄️ Langkah 2: Setup Database MySQL di VPS Baru

1. Masuk ke console MySQL:
   ```bash
   sudo mysql -u root -p
   ```

2. Jalankan skrip database menggunakan file `schema.sql` yang telah disediakan, atau buat secara manual:
   ```sql
   CREATE DATABASE IF NOT EXISTS tonematch_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'tonematch_user'@'localhost' IDENTIFIED BY 'password123';
   GRANT ALL PRIVILEGES ON tonematch_db.* TO 'tonematch_user'@'localhost';
   FLUSH PRIVILEGES;
   EXIT;
   ```

3. Impor skrip tabel:
   ```bash
   sudo mysql -u root -p tonematch_db < schema.sql
   ```

---

## 🐍 Langkah 3: Setup Backend API (FastAPI / Node.js)

1. Buat direktori aplikasi di VPS (contoh: `/var/www/`):
   ```bash
   sudo mkdir -p /var/www/
   sudo chown -R $USER:$USER /var/www/
   cd /var/www/
   git clone https://github.com/Chrsyls/ToneMatch.git /var/www/tonematch
   ```

2. Clone atau salin source code backend Anda ke direktori ini.

3. Buat dan aktifkan Virtual Environment Python:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

4. Instal pustaka yang dibutuhkan:
   ```bash
   pip install --upgrade pip
   pip install fastapi uvicorn pymysql sqlalchemy pydantic python-multipart requests
   ```

5. Buat file konfigurasi `.env` di dalam folder backend:
   ```env
   DB_HOST=localhost
   DB_PORT=3306
   DB_USER=tonematch_user
   DB_PASSWORD=password123
   DB_NAME=tonematch_db
   PORT=8000
   ```

---

## ⚙️ Langkah 4: Menjalankan Backend sebagai Systemd Service (Background Service)

Agar backend berjalan otomatis dan aktif kembali jika VPS direstart:

1. Buat file service systemd:
   ```bash
   sudo nano /etc/systemd/system/tonematch.service
   ```

2. Masukkan konfigurasi berikut (sesuaikan path direktori dan username):
   ```ini
   [Unit]
   Description=ToneMatch FastAPI Backend Service
   After=network.target mysql.service

   [Service]
   User=wasis
   Group=www-data
   # Ubah WorkingDirectory ke dalam subfolder backend
   WorkingDirectory=/var/www/tonematch/backend

   # Tambahkan Environment PATH agar module dikenali
   Environment="PATH=/var/www/tonematch/venv/bin"

   # ExecStart tetap memanggil uvicorn dari venv root, tetapi menjalankannya di folder backend
   ExecStart=/var/www/tonematch/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4

   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

3. Aktifkan dan jalankan service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl start tonematch
   sudo systemctl enable tonematch
   sudo systemctl status tonematch
   ```

---

## 🌐 Langkah 5: Konfigurasi Nginx & Firewall (UFW)

1. Buka port yang diperlukan di Firewall VPS:
   ```bash
   sudo ufw allow 22
   sudo ufw allow 80
   sudo ufw allow 443
   sudo ufw allow 8000
   sudo ufw enable
   ```

2. (Opsional) Buat konfigurasi Reverse Proxy Nginx untuk domain/IP Anda:
   ```bash
   sudo nano /etc/nginx/sites-available/tonematch
   ```
   Isi konfigurasi:
   ```nginx
   server {
       listen 80;
       server_name 100.116.85.88; # Ganti dengan domain/IP VPS Anda

       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       }
   }
   ```

3. Aktifkan situs Nginx dan *restart*:
   ```bash
   sudo ln -s /etc/nginx/sites-available/tonematch /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

---

## 📱 Langkah 6: Penyesuaian di Aplikasi Flutter
Pastikan alamat IP/Domain backend pada file Flutter Anda sudah disesuaikan dengan IP VPS baru:
- Contoh pada `home_screen.dart` / `result_screen.dart`:
  ```dart
  final String localBaseUrl = 'http://IP_VPS_BARU:8000';
  ```

Selesai! VPS baru Anda kini siap melayani permintaan dari aplikasi ToneMatch.