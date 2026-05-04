# EcoConnect Process Flow Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [User Onboarding Flow](#user-onboarding-flow)
3. [Device Connection Flow](#device-connection-flow)
4. [Bottle Insertion Flow](#bottle-insertion-flow)
5. [WiFi Session Flow](#wifi-session-flow)
6. [Bin Monitoring Flow](#bin-monitoring-flow)
7. [Admin Operations Flow](#admin-operations-flow)
8. [Error Handling Flow](#error-handling-flow)
9. [Data Synchronization Flow](#data-synchronization-flow)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    ECOCONNECT SYSTEM                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  User    │───▶│ Frontend │───▶│  ESP32   │              │
│  │ (Mobile) │    │   (PWA)  │    │ (Device) │              │
│  └──────────┘    └────┬─────┘    └────┬─────┘              │
│                      │                 │                     │
│                      │                 │                     │
│                      ▼                 ▼                     │
│              ┌───────────────────────────────┐              │
│              │      PostgreSQL Database       │              │
│              │   (Users, Kiosks, Bottles,     │              │
│              │    Sessions, Logs, Analytics)  │              │
│              └───────────────────────────────┘              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## User Onboarding Flow

### Process: New User Registration

```
START
  │
  ▼
User opens EcoConnect PWA
  │
  ▼
Display Splash Screen (2.7s)
  │
  ▼
Show Connect Screen
  │
  ▼
User clicks "Connect to Kiosk"
  │
  ▼
┌─────────────────────────────┐
│ Probe Device Availability   │
│ - Check ESP32 connectivity  │
│ - Verify device is online   │
└─────────────────────────────┘
  │
  ├─▶ Device Offline
  │     │
  │     ▼
  │  Show "Device Offline" message
  │     │
  │     ▼
  │  Retry connection
  │
  └─▶ Device Online
        │
        ▼
  ┌─────────────────────────────┐
  │ Auto-connect to Device      │
  │ - Establish connection      │
  │ - Load device configuration │
  └─────────────────────────────┘
        │
        ▼
  Navigate to Home Screen
        │
        ▼
  Display User Dashboard
        │
        ▼
END
```

### Database Interactions

**Tables Involved:**
- `users` - Create user record (if registration implemented)
- `kiosks` - Read device information
- `kiosk_status` - Update last heartbeat
- `system_logs` - Log connection event

**SQL Operations:**
```sql
-- Log connection
INSERT INTO system_logs (kiosk_id, log_level, category, event_type, message)
VALUES (?, 'INFO', 'system', 'device_connect', 'User connected to kiosk');

-- Update kiosk status
UPDATE kiosk_status 
SET last_heartbeat = CURRENT_TIMESTAMP, ir_sensor_status = 'ready'
WHERE kiosk_id = ?;
```

---

## Device Connection Flow

### Process: Establishing Connection to ESP32

```
START
  │
  ▼
User opens app
  │
  ▼
┌─────────────────────────────┐
│ Check localStorage for       │
│ saved API configuration     │
└─────────────────────────────┘
  │
  ├─▶ No saved config
  │     │
  │     ▼
  │  Use default: http://192.168.4.1:80
  │
  └─▶ Saved config exists
        │
        ▼
  Use saved API base and port
        │
        ▼
┌─────────────────────────────┐
│ probeDevice()               │
│ - Send GET /status request  │
│ - Timeout: 2 seconds         │
└─────────────────────────────┘
  │
  ├─▶ Request fails
  │     │
  │     ▼
  │  Set deviceOnline = false
  │     │
  │     ▼
  │  Show "ESP32 offline" status
  │     │
  │     ▼
  │  Enable simulation mode
  │
  └─▶ Request succeeds
        │
        ▼
  Parse response data:
  - ir: sensor status
  - batch: current batch count
  - bottles: total bottles
  - sessRemain: session time
  - binLevel: bin capacity
  - uptime: device uptime
  - heap: memory usage
        │
        ▼
  Set deviceOnline = true
        │
        ▼
┌─────────────────────────────┐
│ applyDeviceStatus(data)     │
│ - Update S object state     │
│ - Refresh UI elements       │
│ - Update bin level display  │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│ Start polling interval      │
│ - Every 3000ms (3 seconds)  │
│ - Call pollDevice()         │
└─────────────────────────────┘
  │
  ▼
END
```

### Database Interactions

**Tables Involved:**
- `kiosks` - Read device info
- `kiosk_status` - Update with real-time data
- `system_logs` - Log connection events

**Data Flow:**
```
Frontend (pollDevice)
  │
  ▼
ESP32 API (/status)
  │
  ▼
Backend API
  │
  ▼
PostgreSQL
  │
  ├─ UPDATE kiosk_status SET bin_level = ?, total_bottles = ?
  ├─ INSERT INTO system_logs (event_type: 'heartbeat')
  └─ SELECT FROM kiosks WHERE device_id = ?
```

---

## Bottle Insertion Flow

### Process: Auto-Insertion of 15-20 Bottles

```
START
  │
  ▼
User navigates to Kiosk Screen
  │
  ▼
Display Kiosk Interface
  │
  ▼
User clicks "Insert Bottle" button
  │
  ▼
┌─────────────────────────────┐
│ startInsertionMode()        │
└─────────────────────────────┘
  │
  ├─▶ Timer already running
  │     │
  │     ▼
  │  Show "Insertion in progress"
  │     │
  │     ▼
  │  END
  │
  └─▶ Timer not running
        │
        ▼
  Generate random target: 15-20 bottles
        │
        ▼
  Set totalAutoInserted = 0
        │
        ▼
  Start 30-second countdown timer
        │
        ▼
  Calculate insertion interval:
  interval = 30000ms / targetBottles
        │
        ▼
  Disable "Insert Bottle" button
        │
        ▼
  Show toast: "Auto-inserting X bottles"
        │
        ▼
┌─────────────────────────────┐
│ Start auto-insertion timer   │
│ - Execute every interval ms  │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│ insertBottle() called       │
└─────────────────────────────┘
  │
  ├─▶ Timer not running
  │     │
  │     ▼
  │  Show warning message
  │     │
  │     ▼
  │  END
  │
  └─▶ Timer running
        │
        ▼
  Increment S.bottles++
        │
        ▼
  Increment S.batch++
        │
        ▼
  Increment totalAutoInserted++
        │
        ▼
  Update slot visualization
        │
        ▼
  Set IR status to 'detected'
        │
        ▼
  Add log entry
        │
        ▼
  ┌─────────────────────────┐
  │ Check if batch complete  │
  │ (S.batch >= 5)          │
  └─────────────────────────┘
    │
    ├─▶ No (batch < 5)
    │     │
    │     ▼
    │  Update UI
    │     │
    │     ▼
    │  Continue timer
    │
    └─▶ Yes (batch == 5)
          │
          ▼
    Reset S.batch = 0
          │
          ▼
    Increment S.mins++
          │
          ▼
    Add 60 seconds to S.sessRemain
          │
          ▼
    Show toast: "5 bottles = 1 min WiFi"
          │
          ▼
    ┌─────────────────────────┐
    │ startSess()             │
    │ - Start WiFi session     │
    │ - Update session UI     │
    └─────────────────────────┘
          │
          ▼
    Update UI
          │
          ▼
    Continue timer
  │
  ▼
┌─────────────────────────────┐
│ Check if all bottles done   │
│ (totalAutoInserted >= target)│
└─────────────────────────────┘
  │
  ├─▶ No (more bottles to insert)
  │     │
  │     ▼
  │  Wait for next interval
  │     │
  │     ▼
  │  Loop back to insertBottle()
  │
  └─▶ Yes (all bottles inserted)
        │
        ▼
  Clear auto-insertion timer
        │
        ▼
  Wait for 30-second timer to expire
        │
        ▼
┌─────────────────────────────┐
│ timeoutReset()              │
│ - Stop all timers           │
│ - Reset S.batch = 0         │
│ - Enable button              │
└─────────────────────────────┘
  │
  ▼
END
```

### Database Interactions

**Tables Involved:**
- `bottle_collections` - Insert each bottle record
- `bottle_batches` - Update batch status
- `reward_transactions` - Insert reward record
- `wifi_sessions` - Create session on batch completion
- `daily_statistics` - Triggered by bottle insertion

**SQL Operations:**
```sql
-- Insert bottle record
INSERT INTO bottle_collections (
  kiosk_id, user_id, batch_id, bottle_number,
  material_type, detection_method, is_valid, collection_time
) VALUES (?, ?, ?, ?, 'PET', 'ir', true, CURRENT_TIMESTAMP);

-- Update batch
UPDATE bottle_batches 
SET total_bottles = total_bottles + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- Check batch completion
SELECT total_bottles FROM bottle_batches WHERE id = ?;

-- If batch complete (5 bottles)
UPDATE bottle_batches 
SET status = 'completed',
    wifi_minutes_earned = 1,
    completion_time = CURRENT_TIMESTAMP
WHERE id = ?;

-- Insert reward transaction
INSERT INTO reward_transactions (
  user_id, kiosk_id, batch_id, transaction_type,
  amount, balance_before, balance_after
) VALUES (?, ?, ?, 'wifi_minutes', 1, ?, ?);

-- Create WiFi session
INSERT INTO wifi_sessions (
  user_id, kiosk_id, batch_id, session_token,
  allocated_minutes, status, start_time
) VALUES (?, ?, ?, uuid_generate_v4(), 1, 'active', CURRENT_TIMESTAMP);
```

---

## WiFi Session Flow

### Process: Managing WiFi Access Session

```
START
  │
  ▼
Batch completes (5 bottles)
  │
  ▼
┌─────────────────────────────┐
│ startSess()                 │
└─────────────────────────────┘
  │
  ▼
Set S.sessActive = true
  │
  ▼
Add 60 seconds to S.sessRemain
  │
  ▼
Generate session token
  │
  ▼
┌─────────────────────────────┐
│ updateSessUI()              │
│ - Update countdown timer    │
│ - Show session status       │
│ - Display remaining time    │
└─────────────────────────────┘
  │
  ▼
Navigate to Network Screen
  │
  ▼
Display Session Information:
  - Allocated minutes
  - Used minutes
  - Remaining minutes
  - Connection quality
  - Data usage
  │
  ▼
┌─────────────────────────────┐
│ Start session countdown     │
│ - Decrement every second     │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│ User can:                   │
│ - Pause session             │
│ - Resume session            │
│ - Run speed test            │
│ - View network details      │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│ Check session status        │
└─────────────────────────────┘
  │
  ├─▶ Session paused
  │     │
  │     ▼
  │  Stop countdown
  │     │
  │     ▼
  │  Show "Paused" status
  │     │
  │     ▼
  │  Wait for resume
  │
  ├─▶ Session resumed
  │     │
  │     ▼
  │  Restart countdown
  │     │
  │     ▼
  │  Show "Active" status
  │
  └─▶ Session expired (time = 0)
        │
        ▼
  Set S.sessActive = false
        │
        ▼
  Show "Session expired" toast
        │
        ▼
  Log session end event
        │
        ▼
  Navigate to Home Screen
        │
        ▼
END
```

### Database Interactions

**Tables Involved:**
- `wifi_sessions` - Create and update session
- `reward_transactions` - Log WiFi minute allocation
- `system_logs` - Log session events
- `analytics_events` - Track session duration

**SQL Operations:**
```sql
-- Create session
INSERT INTO wifi_sessions (
  user_id, kiosk_id, batch_id, session_token,
  allocated_minutes, status, start_time
) VALUES (?, ?, ?, uuid_generate_v4(), 1, 'active', CURRENT_TIMESTAMP);

-- Update session (pause/resume)
UPDATE wifi_sessions 
SET status = ?,
    last_activity = CURRENT_TIMESTAMP
WHERE session_token = ?;

-- End session
UPDATE wifi_sessions 
SET status = 'expired',
    end_time = CURRENT_TIMESTAMP,
    termination_reason = 'time_expired'
WHERE session_token = ?;

-- Log session event
INSERT INTO system_logs (
  user_id, kiosk_id, log_level, category,
  event_type, message, details
) VALUES (?, ?, 'INFO', 'wifi', 'session_end', ?, ?);
```

---

## Bin Monitoring Flow

### Process: Ultrasonic Sensor Monitoring

```
START
  │
  ▼
ESP32 ultrasonic sensor reads distance
  │
  ▼
Convert distance to percentage (0-100%)
  │
  ▼
┌─────────────────────────────┐
│ pollDevice() called        │
│ (every 3 seconds)          │
└─────────────────────────────┘
  │
  ▼
ESP32 sends data via API
  │
  ▼
Frontend receives bin_level value
  │
  ▼
┌─────────────────────────────┐
│ applyDeviceStatus()         │
│ - Update S.binLevel         │
│ - Call updateBinLevel()     │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│ updateBinLevel()            │
└─────────────────────────────┘
  │
  ▼
Update progress bar width
  │
  ▼
Update percentage display
  │
  ▼
┌─────────────────────────────┐
│ Determine bin status        │
└─────────────────────────────┘
  │
  ├─▶ bin_level < 75%
  │     │
  │     ▼
  │  Status: "Normal"
  │     │
  │     ▼
  │  Color: Green
  │     │
  │     ▼
  │  Reset binAlertShown = false
  │
  ├─▶ 75% ≤ bin_level < 90%
  │     │
  │     ▼
  │  Status: "Warning"
  │     │
  │     ▼
  │  Color: Yellow
  │     │
  │     ▼
  │  Reset binAlertShown = false
  │
  └─▶ bin_level ≥ 90%
        │
        ▼
  Status: "Critical"
        │
        ▼
  Color: Red
        │
        ▼
  ┌─────────────────────────┐
  │ Check if alert shown    │
  │ (binAlertShown)         │
  └─────────────────────────┘
    │
    ├─▶ Alert already shown
    │     │
    │     ▼
    │  Skip alert
    │
    └─▶ Alert not shown
          │
          ▼
    Set binAlertShown = true
          │
          ▼
    ┌─────────────────────────┐
    │ showBinAlert()           │
    │ - Display SweetAlert     │
    │ - Show warning message   │
    │ - Highlight urgency      │
    └─────────────────────────┘
          │
          ▼
    Log alert event
          │
          ▼
    Create maintenance record
          │
          ▼
END
```

### Database Interactions

**Tables Involved:**
- `kiosk_status` - Update bin_level
- `system_logs` - Log alert events
- `maintenance_records` - Create maintenance request
- `daily_statistics` - Track bin fills

**SQL Operations:**
```sql
-- Update bin level
UPDATE kiosk_status 
SET bin_level = ?,
    last_heartbeat = CURRENT_TIMESTAMP
WHERE kiosk_id = ?;

-- Log alert
INSERT INTO system_logs (
  kiosk_id, log_level, category, event_type,
  message, details
) VALUES (?, 'WARN', 'kiosk', 'bin_full_alert', ?, ?);

-- Create maintenance record
INSERT INTO maintenance_records (
  kiosk_id, maintenance_type, description,
  status, scheduled_date
) VALUES (?, 'emergency', 'Bin nearly full - requires emptying', 
  'scheduled', CURRENT_TIMESTAMP + INTERVAL '1 hour');

-- Update daily statistics
UPDATE daily_statistics 
SET error_count = error_count + 1
WHERE kiosk_id = ? AND stat_date = CURRENT_DATE;
```

---

## Admin Operations Flow

### Process: Admin Authentication and Dashboard

```
START
  │
  ▼
User long-presses "About" button (1.5s)
  │
  ▼
┌─────────────────────────────┐
│ openAdminLogin()            │
└─────────────────────────────┘
  │
  ▼
Navigate to Admin Login Screen
  │
  ▼
Display login form
  │
  ▼
User enters username and password
  │
  ▼
User clicks "Sign In to Dashboard"
  │
  ▼
┌─────────────────────────────┐
│ adminLogin()                │
└─────────────────────────────┘
  │
  ▼
Validate credentials:
  - Username: 'admin'
  - Password: 'eco2024'
  │
  ├─▶ Invalid credentials
  │     │
  │     ▼
  │  Show "Invalid credentials" error
  │     │
  │     ▼
  │  Stay on login screen
  │
  └─▶ Valid credentials
        │
        ▼
  Set S.adminLoggedIn = true
        │
        ▼
  Navigate to Admin Dashboard
        │
        ▼
┌─────────────────────────────┐
│ adminFetchAll()             │
│ - Fetch all statistics      │
│ - Poll every 5 seconds      │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│ Fetch from API:             │
│ - /admin/stats              │
│ - Headers: X-Admin-Key      │
└─────────────────────────────┘
  │
  ▼
Parse response data:
  - totalBottles
  - totalMins
  - activeSessions
  - dailyData
  - weeklyData
  - sessionLog
  │
  ▼
┌─────────────────────────────┐
│ adminApplyStats(data)       │
│ - Update UI elements        │
│ - Render charts             │
│ - Display session log       │
└─────────────────────────────┘
  │
  ▼
Display Dashboard with:
  - Kiosk status
  - Bottle statistics
  - WiFi session statistics
  - System uptime
  - Recent sessions
  │
  ▼
┌─────────────────────────────┐
│ Admin can:                  │
│ - Refresh data              │
│ - Reset current batch        │
│ - Clear active session      │
│ - Terminate all sessions    │
│ - View logs                 │
│ - Logout                    │
└─────────────────────────────┘
  │
  ├─▶ Refresh data
  │     │
  │     ▼
  │  Call adminFetchAll()
  │
  ├─▶ Reset batch
  │     │
  │     ▼
  │  sendAdminCmd('reset_batch')
  │
  ├─▶ Clear session
  │     │
  │     ▼
  │  sendAdminCmd('clear_session')
  │
  ├─▶ Terminate all
  │     │
  │     ▼
  │  sendAdminCmd('terminate_all')
  │
  └─▶ Logout
        │
        ▼
  adminLogout()
        │
        ▼
  Set S.adminLoggedIn = false
        │
        ▼
  Navigate to Admin Login
        │
        ▼
END
```

### Database Interactions

**Tables Involved:**
- `users` - Validate admin credentials
- `kiosk_status` - Read real-time metrics
- `bottle_collections` - Count total bottles
- `wifi_sessions` - Query active sessions
- `daily_statistics` - Read aggregated data
- `system_logs` - Log admin actions

**SQL Operations:**
```sql
-- Validate admin
SELECT id, username, password_hash, role 
FROM users 
WHERE username = 'admin' AND role = 'admin';

-- Get statistics
SELECT 
  COUNT(*) as totalBottles,
  SUM(bb.wifi_minutes_earned) as totalMins,
  COUNT(DISTINCT ws.user_id) as activeSessions
FROM bottle_collections bc
LEFT JOIN bottle_batches bb ON bc.batch_id = bb.id
LEFT JOIN wifi_sessions ws ON ws.status = 'active';

-- Get daily data
SELECT stat_date, total_bottles_collected, total_batches_completed
FROM daily_statistics
WHERE stat_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY stat_date;

-- Get session log
SELECT session_token, status, allocated_minutes, 
       start_time, end_time, termination_reason
FROM wifi_sessions
ORDER BY start_time DESC
LIMIT 10;

-- Reset batch
UPDATE bottle_batches 
SET status = 'cancelled', timeout_reason = 'admin_reset'
WHERE kiosk_id = ? AND status = 'active';

-- Clear session
UPDATE wifi_sessions 
SET status = 'terminated', termination_reason = 'admin_clear'
WHERE session_token = ?;

-- Terminate all
UPDATE wifi_sessions 
SET status = 'terminated', termination_reason = 'admin_terminate_all'
WHERE status = 'active';

-- Log admin action
INSERT INTO system_logs (
  user_id, log_level, category, event_type,
  message, details
) VALUES (?, 'INFO', 'admin', ?, ?, ?);
```

---

## Error Handling Flow

### Process: Handling System Errors

```
START
  │
  ▼
Error occurs in system
  │
  ▼
┌─────────────────────────────┐
│ Identify error type         │
└─────────────────────────────┘
  │
  ├─▶ Device connection error
  │     │
  │     ▼
  │  ┌─────────────────────────┐
  │  │ Show "Device Offline"   │
  │  │ - Set deviceOnline =    │
  │  │   false                 │
  │  │ - Enable simulation     │
  │  │   mode                  │
  │  └─────────────────────────┘
  │     │
  │     ▼
  │  Log error to system_logs
  │     │
  │     ▼
  │  Continue with simulation
  │
  ├─▶ API request timeout
  │     │
  │     ▼
  │  ┌─────────────────────────┐
  │  │ Show "Request Timeout"  │
  │  │ toast                   │
  │  └─────────────────────────┘
  │     │
  │     ▼
  │  Log error with details
  │     │
  │     ▼
  │  Retry request (max 3 times)
  │
  ├─▶ Invalid bottle detection
  │     │
  │     ▼
  │  ┌─────────────────────────┐
  │  │ Show "Invalid Material" │
  │  │ toast                   │
  │  └─────────────────────────┘
  │     │
  │     ▼
  │  Do not increment batch
  │     │
  │     ▼
  │  Log rejection event
  │
  ├─▶ Session expiry
  │     │
  │     ▼
  │  ┌─────────────────────────┐
  │  │ Show "Session Expired"   │
  │  │ toast                   │
  │  └─────────────────────────┘
  │     │
  │     ▼
  │  Terminate session
  │     │
  │     ▼
  │  Log session end
  │
  └─▶ Critical system error
        │
        ▼
  ┌─────────────────────────┐
  │ Show "System Error"     │
  │ modal                   │
  └─────────────────────────┘
        │
        ▼
  Log as FATAL error
        │
        ▼
  Create support ticket
        │
        ▼
  Notify administrators
        │
        ▼
END
```

### Database Interactions

**Tables Involved:**
- `system_logs` - Log all errors
- `support_tickets` - Create ticket for critical errors
- `analytics_events` - Track error rates

**SQL Operations:**
```sql
-- Log error
INSERT INTO system_logs (
  kiosk_id, user_id, log_level, category,
  event_type, message, details, ip_address
) VALUES (?, ?, 'ERROR', 'system', ?, ?, ?, ?);

-- Create support ticket for critical errors
INSERT INTO support_tickets (
  user_id, kiosk_id, ticket_number, subject,
  description, category, priority, status
) VALUES (?, ?, generate_ticket_number(), ?, ?, 'technical', 'urgent', 'open');

-- Track error analytics
INSERT INTO analytics_events (
  kiosk_id, user_id, event_type, event_data
) VALUES (?, ?, 'error_occurred', ?);
```

---

## Data Synchronization Flow

### Process: Keeping Frontend and Database in Sync

```
START
  │
  ▼
Frontend state changes
  │
  ▼
┌─────────────────────────────┐
│ Determine sync strategy     │
└─────────────────────────────┘
  │
  ├─▶ Real-time data (bin level)
  │     │
  │     ▼
  │  Poll every 3 seconds
  │     │
  │     ▼
  │  GET /status from ESP32
  │     │
  │     ▼
  │  Update S object
  │     │
  │     ▼
  │  Update UI
  │
  ├─▶ User actions (bottle insert)
  │     │
  │     ▼
  │  Immediate API call
  │     │
  │     ▼
  │  POST /insert
  │     │
  │     ▼
  │  Wait for confirmation
  │     │
  │     ▼
  │  Update local state
  │
  └─▶ Admin operations
        │
        ▼
  Poll every 5 seconds
        │
        ▼
  GET /admin/stats
        │
        ▼
  Update dashboard
  │
  ▼
┌─────────────────────────────┐
│ Conflict Resolution        │
└─────────────────────────────┘
  │
  ├─▶ Local state newer
  │     │
  │     ▼
  │  Push to database
  │
  ├─▶ Database state newer
  │     │
  │     ▼
  │  Pull to local state
  │
  └─▶ Conflict (both changed)
        │
        ▼
  Use timestamp comparison
        │
        ▼
  Keep most recent change
        │
        ▼
  Log conflict event
        │
        ▼
END
```

### Database Interactions

**Tables Involved:**
- All tables with `updated_at` timestamps
- `system_logs` - Log sync events

**Sync Strategy:**
```sql
-- Get last sync timestamp
SELECT MAX(updated_at) FROM kiosk_status WHERE kiosk_id = ?;

-- Pull changes since last sync
SELECT * FROM kiosk_status 
WHERE kiosk_id = ? AND updated_at > ?
ORDER BY updated_at;

-- Push local changes
UPDATE kiosk_status 
SET bin_level = ?, total_bottles = ?, updated_at = CURRENT_TIMESTAMP
WHERE kiosk_id = ?;

-- Log sync event
INSERT INTO system_logs (
  kiosk_id, log_level, category, event_type,
  message, details
) VALUES (?, 'DEBUG', 'system', 'data_sync', ?, ?);
```

---

## Summary

The EcoConnect system follows these key process flows:

1. **User Onboarding**: Simple connection to kiosk device
2. **Device Connection**: Polling-based real-time communication
3. **Bottle Insertion**: Auto-insertion simulation with batch tracking
4. **WiFi Session**: Time-based session management
5. **Bin Monitoring**: Threshold-based alerting system
6. **Admin Operations**: Role-based access control
7. **Error Handling**: Graceful degradation and logging
8. **Data Synchronization**: Polling with conflict resolution

All flows are designed to:
- Provide real-time feedback to users
- Maintain data consistency
- Handle errors gracefully
- Log all events for auditing
- Scale to multiple kiosks and users
