-- Buat database jika belum ada dan gunakan
CREATE DATABASE IF NOT EXISTS tonematch_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tonematch_db;

-- 1. TABEL UTAMA & PENGGUNA
CREATE TABLE IF NOT EXISTS users (
    uid VARCHAR(128) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    role ENUM('super_admin', 'admin', 'user') DEFAULT 'user',
    avatar_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_preferences (
    user_id VARCHAR(128) PRIMARY KEY,
    skin_type VARCHAR(50),
    sensitivitas_kulit VARCHAR(50),
    favorite_brands JSON,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ui_settings (
    setting_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    theme_mode ENUM('light', 'dark') DEFAULT 'light',
    layout_preferences VARCHAR(50) DEFAULT 'default',
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_sessions (
    session_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    device_info TEXT,
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2. TABEL KATALOG PRODUK & KATEGORI
CREATE TABLE IF NOT EXISTS brands (
    brand_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    logo_url TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS makeup_categories (
    category_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS makeup_products (
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
) ENGINE=InnoDB;

-- 3. TABEL TRANSAKSIONAL & INTERAKSI PENGGUNA
CREATE TABLE IF NOT EXISTS classification_histories (
    history_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    image_url TEXT,
    detected_undertone ENUM('cool', 'neutral', 'warm'),
    confidence_score FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS favorite_products (
    favorite_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    product_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES makeup_products(product_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_reviews (
    review_id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(128),
    product_id INT,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    image_proof TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES makeup_products(product_id) ON DELETE CASCADE
) ENGINE=InnoDB;