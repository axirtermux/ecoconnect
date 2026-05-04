-- EcoConnect Database Schema (MySQL/MariaDB)
-- Plastic bottle-based WiFi access system for sustainable communities
-- Created: 2025-05-04
-- Version: 1.0 (MySQL/MariaDB Compatible)

-- Create database
-- CREATE DATABASE ecoconnect;
-- USE ecoconnect;

-- =============================================
-- USER MANAGEMENT TABLES
-- =============================================

-- Users table - stores user accounts and authentication
CREATE TABLE users (
    id CHAR(36) PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'operator')),
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX idx_users_email (email),
    INDEX idx_users_username (username),
    INDEX idx_users_role (role),
    INDEX idx_users_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User profiles table - additional user information
CREATE TABLE user_profiles (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    avatar_url VARCHAR(500),
    bio TEXT,
    preferred_language VARCHAR(10) DEFAULT 'en',
    notification_preferences JSON DEFAULT '{"email": true, "sms": false, "push": true}',
    privacy_settings JSON DEFAULT '{"profile_visible": true, "stats_visible": true}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- KIOSK DEVICE MANAGEMENT
-- =============================================

-- Kiosks table - physical device information
CREATE TABLE kiosks (
    id CHAR(36) PRIMARY KEY,
    device_id VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    location_name VARCHAR(200),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address TEXT,
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'maintenance', 'error')),
    ssid VARCHAR(100),
    wifi_password VARCHAR(100),
    external_isp VARCHAR(100),
    firmware_version VARCHAR(50),
    hardware_version VARCHAR(50),
    installation_date DATE,
    last_maintenance DATE,
    next_maintenance DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_kiosks_device_id (device_id),
    INDEX idx_kiosks_status (status),
    INDEX idx_kiosks_location (latitude, longitude)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Kiosk status monitoring - real-time device metrics
CREATE TABLE kiosk_status (
    id CHAR(36) PRIMARY KEY,
    kiosk_id CHAR(36) NOT NULL,
    ir_sensor_status VARCHAR(20) DEFAULT 'idle' CHECK (ir_sensor_status IN ('idle', 'ready', 'detected', 'waiting', 'error')),
    current_batch INT DEFAULT 0 CHECK (current_batch >= 0 AND current_batch <= 5),
    total_bottles INT DEFAULT 0,
    bin_level INT DEFAULT 0 CHECK (bin_level >= 0 AND bin_level <= 100),
    session_remaining INT DEFAULT 0,
    uptime_seconds INT DEFAULT 0,
    heap_usage VARCHAR(20),
    cpu_temperature DECIMAL(5, 2),
    battery_level INT CHECK (battery_level >= 0 AND battery_level <= 100),
    last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE CASCADE,
    INDEX idx_kiosk_status_kiosk_id (kiosk_id),
    INDEX idx_kiosk_status_heartbeat (last_heartbeat),
    INDEX idx_kiosk_status_ir (ir_sensor_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- BOTTLE COLLECTION AND TRACKING
-- =============================================

-- Bottle collections - records each bottle insertion
CREATE TABLE bottle_collections (
    id CHAR(36) PRIMARY KEY,
    kiosk_id CHAR(36) NOT NULL,
    user_id CHAR(36),
    batch_id CHAR(36) NOT NULL,
    bottle_number INT NOT NULL CHECK (bottle_number >= 1 AND bottle_number <= 5),
    material_type VARCHAR(50) DEFAULT 'PET' CHECK (material_type IN ('PET', 'Non-PET')),
    detection_method VARCHAR(20) DEFAULT 'ir' CHECK (detection_method IN ('ir', 'manual', 'qr')),
    is_valid BOOLEAN DEFAULT FALSE,
    detection_confidence DECIMAL(5, 2) CHECK (detection_confidence >= 0 AND detection_confidence <= 100),
    weight_grams DECIMAL(8, 2),
    volume_ml DECIMAL(8, 2),
    bottle_color VARCHAR(50),
    manufacturer VARCHAR(100),
    collection_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_time TIMESTAMP NULL,
    notes TEXT,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_bottle_collections_kiosk_id (kiosk_id),
    INDEX idx_bottle_collections_user_id (user_id),
    INDEX idx_bottle_collections_batch_id (batch_id),
    INDEX idx_bottle_collections_collection_time (collection_time),
    INDEX idx_bottle_collections_material_type (material_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bottle batches - groups of 5 bottles for WiFi rewards
CREATE TABLE bottle_batches (
    id CHAR(36) PRIMARY KEY,
    kiosk_id CHAR(36) NOT NULL,
    user_id CHAR(36),
    batch_number INT NOT NULL,
    total_bottles INT DEFAULT 0 CHECK (total_bottles >= 0 AND total_bottles <= 5),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'expired', 'cancelled')),
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completion_time TIMESTAMP NULL,
    expiry_time TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL 30 SECOND),
    timeout_reason VARCHAR(50),
    wifi_minutes_earned INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_bottle_batches_kiosk_id (kiosk_id),
    INDEX idx_bottle_batches_user_id (user_id),
    INDEX idx_bottle_batches_status (status),
    INDEX idx_bottle_batches_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- WIFI SESSIONS AND REWARDS
-- =============================================

-- WiFi sessions - tracks user internet access sessions
CREATE TABLE wifi_sessions (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    kiosk_id CHAR(36) NOT NULL,
    batch_id CHAR(36),
    session_token VARCHAR(255) UNIQUE NOT NULL,
    device_mac VARCHAR(17),
    device_info JSON,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'expired', 'terminated', 'paused')),
    allocated_minutes INT NOT NULL,
    used_minutes INT DEFAULT 0,
    remaining_minutes INT GENERATED ALWAYS AS (allocated_minutes - used_minutes) STORED,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP NULL,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_usage_mb DECIMAL(10, 2) DEFAULT 0,
    connection_quality VARCHAR(20) DEFAULT 'good' CHECK (connection_quality IN ('excellent', 'good', 'fair', 'poor')),
    termination_reason VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE CASCADE,
    FOREIGN KEY (batch_id) REFERENCES bottle_batches(id) ON DELETE SET NULL,
    INDEX idx_wifi_sessions_user_id (user_id),
    INDEX idx_wifi_sessions_kiosk_id (kiosk_id),
    INDEX idx_wifi_sessions_status (status),
    INDEX idx_wifi_sessions_start_time (start_time),
    INDEX idx_wifi_sessions_session_token (session_token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Reward transactions - tracks all reward allocations
CREATE TABLE reward_transactions (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    kiosk_id CHAR(36) NOT NULL,
    batch_id CHAR(36),
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('wifi_minutes', 'bonus_minutes', 'penalty', 'refund')),
    amount INT NOT NULL,
    balance_before INT NOT NULL,
    balance_after INT NOT NULL,
    description TEXT,
    reference_id CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE CASCADE,
    FOREIGN KEY (batch_id) REFERENCES bottle_batches(id) ON DELETE SET NULL,
    INDEX idx_reward_transactions_user_id (user_id),
    INDEX idx_reward_transactions_kiosk_id (kiosk_id),
    INDEX idx_reward_transactions_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- SYSTEM LOGGING AND ANALYTICS
-- =============================================

-- System logs - comprehensive logging for monitoring and debugging
CREATE TABLE system_logs (
    id CHAR(36) PRIMARY KEY,
    kiosk_id CHAR(36),
    user_id CHAR(36),
    log_level VARCHAR(10) NOT NULL CHECK (log_level IN ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')),
    category VARCHAR(50) NOT NULL CHECK (category IN ('system', 'user', 'kiosk', 'bottle', 'wifi', 'security', 'maintenance')),
    event_type VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    details JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    session_id CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_system_logs_kiosk_id (kiosk_id),
    INDEX idx_system_logs_user_id (user_id),
    INDEX idx_system_logs_level (log_level),
    INDEX idx_system_logs_category (category),
    INDEX idx_system_logs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Analytics events - for tracking user behavior and system performance
CREATE TABLE analytics_events (
    id CHAR(36) PRIMARY KEY,
    kiosk_id CHAR(36),
    user_id CHAR(36),
    event_type VARCHAR(100) NOT NULL,
    event_data JSON,
    session_id CHAR(36),
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_analytics_events_kiosk_id (kiosk_id),
    INDEX idx_analytics_events_user_id (user_id),
    INDEX idx_analytics_events_type (event_type),
    INDEX idx_analytics_events_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daily statistics - aggregated data for reporting
CREATE TABLE daily_statistics (
    id CHAR(36) PRIMARY KEY,
    kiosk_id CHAR(36) NOT NULL,
    stat_date DATE NOT NULL,
    total_bottles_collected INT DEFAULT 0,
    total_batches_completed INT DEFAULT 0,
    total_wifi_minutes_allocated INT DEFAULT 0,
    total_wifi_minutes_used INT DEFAULT 0,
    unique_users INT DEFAULT 0,
    average_session_duration INT DEFAULT 0,
    peak_usage_hour INT,
    system_uptime_percentage DECIMAL(5, 2),
    error_count INT DEFAULT 0,
    maintenance_minutes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_kiosk_date (kiosk_id, stat_date),
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE CASCADE,
    INDEX idx_daily_statistics_kiosk_id (kiosk_id),
    INDEX idx_daily_statistics_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- MAINTENANCE AND SUPPORT
-- =============================================

-- Maintenance records
CREATE TABLE maintenance_records (
    id CHAR(36) PRIMARY KEY,
    kiosk_id CHAR(36) NOT NULL,
    technician_id CHAR(36),
    maintenance_type VARCHAR(50) NOT NULL CHECK (maintenance_type IN ('routine', 'repair', 'upgrade', 'emergency')),
    description TEXT NOT NULL,
    parts_replaced TEXT,
    cost DECIMAL(10, 2),
    duration_minutes INT,
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    scheduled_date TIMESTAMP NULL,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE CASCADE,
    FOREIGN KEY (technician_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_maintenance_records_kiosk_id (kiosk_id),
    INDEX idx_maintenance_records_technician_id (technician_id),
    INDEX idx_maintenance_records_status (status),
    INDEX idx_maintenance_records_scheduled_date (scheduled_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Support tickets
CREATE TABLE support_tickets (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36),
    kiosk_id CHAR(36),
    ticket_number VARCHAR(20) UNIQUE NOT NULL,
    subject VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('technical', 'account', 'billing', 'general')),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed', 'reopened')),
    assigned_to CHAR(36),
    resolution TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE SET NULL,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_support_tickets_user_id (user_id),
    INDEX idx_support_tickets_kiosk_id (kiosk_id),
    INDEX idx_support_tickets_status (status),
    INDEX idx_support_tickets_priority (priority),
    INDEX idx_support_tickets_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- TRIGGERS AND STORED PROCEDURES
-- =============================================

-- Trigger to update daily statistics on bottle collection
DELIMITER //
CREATE TRIGGER update_daily_stats_on_collection
AFTER INSERT ON bottle_collections
FOR EACH ROW
BEGIN
    INSERT INTO daily_statistics (
        kiosk_id, 
        stat_date, 
        total_bottles_collected, 
        total_batches_completed, 
        total_wifi_minutes_allocated,
        unique_users
    ) VALUES (
        NEW.kiosk_id,
        CURDATE(),
        1,
        IF(NEW.bottle_number = 5, 1, 0),
        IF(NEW.bottle_number = 5, 1, 0),
        IF(NEW.user_id IS NOT NULL, 1, 0)
    )
    ON DUPLICATE KEY UPDATE
        total_bottles_collected = total_bottles_collected + 1,
        total_batches_completed = total_batches_completed + IF(NEW.bottle_number = 5, 1, 0),
        total_wifi_minutes_allocated = total_wifi_minutes_allocated + IF(NEW.bottle_number = 5, 1, 0),
        unique_users = unique_users + IF(
            NEW.user_id IS NOT NULL AND NOT EXISTS (
                SELECT 1 FROM bottle_collections bc2 
                WHERE bc2.kiosk_id = NEW.kiosk_id 
                AND DATE(bc2.collection_time) = CURDATE() 
                AND bc2.user_id = NEW.user_id
                LIMIT 1
            ), 1, 0
        );
END//
DELIMITER ;

-- =============================================
-- VIEWS FOR COMMON QUERIES
-- =============================================

-- User summary view
CREATE VIEW user_summary AS
SELECT 
    u.id,
    u.username,
    u.full_name,
    u.email,
    u.created_at,
    u.last_login,
    COALESCE(stats.total_bottles, 0) as total_bottles_collected,
    COALESCE(stats.total_batches, 0) as total_batches_completed,
    COALESCE(stats.total_wifi_minutes, 0) as total_wifi_minutes_earned,
    COALESCE(stats.co2_saved_kg, 0) as co2_saved_kg
FROM users u
LEFT JOIN (
    SELECT 
        bc.user_id,
        COUNT(*) as total_bottles,
        COUNT(DISTINCT bc.batch_id) as total_batches,
        SUM(CASE WHEN bb.total_bottles = 5 THEN 1 ELSE 0 END) as total_wifi_minutes,
        COUNT(*) * 0.05 as co2_saved_kg
    FROM bottle_collections bc
    LEFT JOIN bottle_batches bb ON bc.batch_id = bb.id
    WHERE bc.is_valid = TRUE
    GROUP BY bc.user_id
) stats ON u.id = stats.user_id;

-- Kiosk performance view
CREATE VIEW kiosk_performance AS
SELECT 
    k.id,
    k.name,
    k.location_name,
    k.status,
    ks.bin_level,
    ks.total_bottles,
    ks.uptime_seconds,
    ks.last_heartbeat,
    COALESCE(today_stats.bottles_today, 0) as bottles_today,
    COALESCE(today_stats.batches_today, 0) as batches_today,
    COALESCE(today_stats.users_today, 0) as users_today,
    COALESCE(week_stats.bottles_week, 0) as bottles_week,
    COALESCE(month_stats.bottles_month, 0) as bottles_month
FROM kiosks k
LEFT JOIN kiosk_status ks ON k.id = ks.kiosk_id
LEFT JOIN (
    SELECT 
        kiosk_id,
        COUNT(*) as bottles_today,
        COUNT(DISTINCT batch_id) as batches_today,
        COUNT(DISTINCT user_id) as users_today
    FROM bottle_collections
    WHERE DATE(collection_time) = CURDATE()
    AND is_valid = TRUE
    GROUP BY kiosk_id
) today_stats ON k.id = today_stats.kiosk_id
LEFT JOIN (
    SELECT 
        kiosk_id,
        COUNT(*) as bottles_week
    FROM bottle_collections
    WHERE collection_time >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    AND is_valid = TRUE
    GROUP BY kiosk_id
) week_stats ON k.id = week_stats.kiosk_id
LEFT JOIN (
    SELECT 
        kiosk_id,
        COUNT(*) as bottles_month
    FROM bottle_collections
    WHERE collection_time >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    AND is_valid = TRUE
    GROUP BY kiosk_id
) month_stats ON k.id = month_stats.kiosk_id;

-- =============================================
-- SAMPLE DATA (Optional - for testing)
-- =============================================

-- Insert sample admin user
INSERT INTO users (id, username, email, password_hash, full_name, role, is_active, email_verified) VALUES
(UUID(), 'admin', 'admin@ecoconnect.local', '$2b$12$example_hash', 'System Administrator', 'admin', TRUE, TRUE);

-- Insert sample kiosk
INSERT INTO kiosks (id, device_id, name, location_name, latitude, longitude, address, status, ssid, firmware_version) VALUES
(UUID(), 'ESP32_ECO_001', 'EcoConnect Hub - San Julian Plaza', 'San Julian Plaza', 11.6099, 125.4340, 'San Julian Plaza, Eastern Samar', 'online', 'EcoConnect_Hub_01', '1.0.0');

-- Insert sample kiosk status
INSERT INTO kiosk_status (id, kiosk_id, ir_sensor_status, current_batch, total_bottles, bin_level, session_remaining, uptime_seconds, heap_usage) VALUES
(UUID(), (SELECT id FROM kiosks WHERE device_id = 'ESP32_ECO_001'), 'ready', 0, 0, 78, 0, 86400, '180KB');

-- =============================================
-- COMMENTS AND DOCUMENTATION
-- =============================================

-- Security considerations:
-- 1. All passwords should be hashed using bcrypt or similar
-- 2. Use prepared statements to prevent SQL injection
-- 3. Implement proper authentication and authorization
-- 4. Use SSL/TLS for all database connections
-- 5. Regular database backups and monitoring
-- 6. Implement row-level security for multi-tenant access if needed

-- Performance considerations:
-- 1. Monitor query performance and add indexes as needed
-- 2. Consider partitioning large tables by date
-- 3. Implement connection pooling
-- 4. Regular optimize table operations
-- 5. Archive old log data periodically

-- Scaling considerations:
-- 1. Consider read replicas for analytics queries
-- 2. Implement caching for frequently accessed data
-- 3. Use queue systems for async processing
-- 4. Monitor database size and plan for growth
