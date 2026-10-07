-- Buat database jika belum ada
CREATE DATABASE IF NOT EXISTS tonematch_db;
USE tonematch_db;

-- 1. TABEL UTAMA & PENGGUNA
CREATE TABLE users (
    uid VARCHAR(128) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    role ENUM('super_admin', 'admin', 'user') DEFAULT 'user',
    avatar_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_preferences (
    user_id VARCHAR(128) PRIMARY KEY,
    skin_type VARCHAR(50),
    sensitivitas_kulit VARCHAR(50),
    favorite_brands JSON,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE TABLE ui_settings (
    setting_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    theme_mode ENUM('light', 'dark') DEFAULT 'light',
    layout_preferences VARCHAR(50) DEFAULT 'default',
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE TABLE user_sessions (
    session_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    device_info TEXT,
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
);

-- 2. TABEL KATALOG PRODUK & KATEGORI
CREATE TABLE brands (
    brand_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    logo_url TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE makeup_categories (
    category_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT
);

CREATE TABLE makeup_products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id VARCHAR(50),
    brand_id VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    brand VARCHAR(255), -- Disimpan langsung sebagai teks untuk fleksibilitas CRUD admin
    price DECIMAL(10,2) DEFAULT 0,
    target_undertone VARCHAR(50) DEFAULT 'warm',
    hex_color VARCHAR(10),
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES makeup_categories(category_id) ON DELETE SET NULL,
    FOREIGN KEY (brand_id) REFERENCES brands(brand_id) ON DELETE SET NULL
);

-- 3. TABEL TRANSAKSIONAL & INTERAKSI PENGGUNA
CREATE TABLE classification_histories (
    history_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    image_url TEXT,
    detected_undertone ENUM('cool', 'neutral', 'warm'),
    confidence_score FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE TABLE favorite_products (
    favorite_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    product_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES makeup_products(product_id) ON DELETE CASCADE
);

CREATE TABLE product_reviews (
    review_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    product_id INT,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    image_proof TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES makeup_products(product_id) ON DELETE CASCADE
);