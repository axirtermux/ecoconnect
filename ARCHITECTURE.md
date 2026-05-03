# EcoConnect Architecture Documentation

## Overview

EcoConnect is a plastic bottle-based WiFi access system consisting of:
- **Frontend**: Progressive Web App (PWA) built with HTML/CSS/JavaScript
- **Backend**: PostgreSQL database for data persistence
- **Hardware**: ESP32 microcontroller with IR sensors and ultrasonic bin monitoring
- **API**: REST API for real-time communication between frontend and ESP32

---

## Database Schema (PostgreSQL)

### 1. User Management Tables

#### `users` Table
**Purpose**: Stores user accounts and authentication information

**Key Fields**:
- `id` (UUID): Primary key
- `username`, `email`: Unique identifiers
- `password_hash`: Encrypted password
- `role`: User permissions (user, admin, operator)
- `is_active`, `email_verified`: Account status flags

**Frontend Interaction**:
- Currently uses hardcoded admin credentials (`admin`/`eco2024`)
- Would integrate with backend authentication API
- Session management through `wifi_sessions` table

#### `user_profiles` Table
**Purpose**: Extended user information and preferences

**Key Fields**:
- `user_id` (UUID): Foreign key to users
- `avatar_url`, `bio`: Personalization
- `notification_preferences`: JSONB for flexible settings
- `privacy_settings`: User privacy controls

**Frontend Interaction**:
- Profile screen would display user data
- Settings would update notification preferences
- Avatar upload would store URL reference

---

### 2. Kiosk Device Management

#### `kiosks` Table
**Purpose**: Physical device information and configuration

**Key Fields**:
- `device_id`: ESP32 unique identifier
- `name`, `location_name`: Device identification
- `latitude`, `longitude`: GPS coordinates
- `status`: online/offline/maintenance/error
- `ssid`, `wifi_password`: Network configuration
- `firmware_version`: Software version tracking

**Frontend Interaction**:
- Connect screen probes device by IP
- Device status displayed on home screen
- Location data used for kiosk mapping
- Firmware version for update management

#### `kiosk_status` Table
**Purpose**: Real-time device metrics and monitoring

**Key Fields**:
- `kiosk_id` (UUID): Foreign key to kiosks
- `ir_sensor_status`: idle/ready/detected/waiting/error
- `current_batch`: Current batch count (0-5)
- `total_bottles`: Lifetime bottle count
- `bin_level`: Ultrasonic sensor reading (0-100%)
- `session_remaining`: Active WiFi session time
- `uptime_seconds`: Device uptime
- `heap_usage`: Memory usage
- `last_heartbeat`: Last communication timestamp

**Frontend Interaction**:
- **IR Sensor Status**: Displayed on home screen with visual indicator
- **Current Batch**: Shown in kiosk screen with slot visualization
- **Total Bottles**: Displayed in admin dashboard statistics
- **Bin Level**: 
  - Displayed on home screen with progress bar
  - Triggers SweetAlert when ≥90%
  - Color-coded (green/yellow/red)
- **Session Remaining**: Countdown timer on network screen
- **Last Heartbeat**: API status indicator (online/offline)

**Data Flow**:
```
ESP32 → API → Frontend (pollDevice() every 3s)
Frontend → applyDeviceStatus() → Update UI
```

---

### 3. Bottle Collection and Tracking

#### `bottle_collections` Table
**Purpose**: Records each individual bottle insertion

**Key Fields**:
- `kiosk_id` (UUID): Foreign key to kiosks
- `user_id` (UUID): Foreign key to users
- `batch_id` (UUID): Groups bottles in batches of 5
- `bottle_number`: Position in batch (1-5)
- `material_type`: PET or Non-PET
- `detection_method`: ir/manual/qr
- `is_valid`: IR sensor validation result
- `detection_confidence`: Sensor confidence percentage
- `weight_grams`, `volume_ml`: Physical measurements
- `collection_time`: Timestamp of insertion

**Frontend Interaction**:
- **Auto-insertion**: `startInsertionMode()` simulates 15-20 bottles
- **IR Detection**: `insertBottle()` called by auto-insertion timer
- **Batch Tracking**: Updates `S.batch` (0-5) in frontend state
- **Validation**: IR sensor would validate material type
- **Logging**: `addLog()` records each bottle in UI log

**Data Flow**:
```
User clicks "Insert Bottle" → startInsertionMode()
→ Sets target (15-20 bottles)
→ Auto-insertion timer calls insertBottle()
→ Updates S.bottles, S.batch
→ API POST /insert (if not simulation mode)
→ Database INSERT into bottle_collections
```

#### `bottle_batches` Table
**Purpose**: Groups of 5 bottles for WiFi rewards

**Key Fields**:
- `kiosk_id` (UUID): Foreign key to kiosks
- `user_id` (UUID): Foreign key to users
- `batch_number`: Sequential batch identifier
- `total_bottles`: Count (0-5)
- `status`: active/completed/expired/cancelled
- `start_time`: When first bottle inserted
- `completion_time`: When 5th bottle inserted
- `expiry_time`: 30-second timeout (start_time + 30s)
- `timeout_reason`: Why batch expired
- `wifi_minutes_earned`: Reward (1 minute per 5 bottles)

**Frontend Interaction**:
- **30-Second Window**: `startInsertionMode()` starts timer
- **Batch Counter**: Displayed in kiosk screen (X/5)
- **Timeout Logic**: `timeoutReset()` when timer expires
- **Completion**: When `S.batch >= 5`, resets and awards WiFi
- **Status Tracking**: Active/inactive based on timer

**Data Flow**:
```
startInsertionMode() → Start 30s timer
→ insertBottle() called repeatedly
→ When S.batch >= 5:
  → S.batch = 0
  → S.mins++
  → S.sessRemain += 60
  → startSess()
  → Database: UPDATE bottle_batches SET status='completed'
→ When timer expires:
  → timeoutReset()
  → S.batch = 0
  → Database: UPDATE bottle_batches SET status='expired'
```

---

### 4. WiFi Sessions and Rewards

#### `wifi_sessions` Table
**Purpose**: Tracks user internet access sessions

**Key Fields**:
- `user_id` (UUID): Foreign key to users
- `kiosk_id` (UUID): Foreign key to kiosks
- `batch_id` (UUID): Foreign key to bottle_batches
- `session_token`: Unique session identifier
- `device_mac`: User device MAC address
- `device_info`: JSONB with device details
- `status`: active/expired/terminated/paused
- `allocated_minutes`: Total WiFi time awarded
- `used_minutes`: Time consumed
- `remaining_minutes`: Computed (allocated - used)
- `start_time`, `end_time`: Session boundaries
- `data_usage_mb`: Data consumption tracking
- `connection_quality`: excellent/good/fair/poor
- `termination_reason`: Why session ended

**Frontend Interaction**:
- **Session Start**: `startSess()` when batch completes
- **Timer Display**: Countdown on network screen
- **Pause/Resume**: Session management controls
- **Speed Test**: `runSpeedTest()` simulates network speed
- **Session Log**: Displayed in admin dashboard

**Data Flow**:
```
Batch completes (5 bottles) → startSess()
→ S.sessActive = true
→ S.sessRemain += 60 (1 minute)
→ Display countdown timer
→ Database: INSERT into wifi_sessions
→ Database: INSERT into reward_transactions
→ When session ends:
  → Database: UPDATE wifi_sessions SET status='expired'
```

#### `reward_transactions` Table
**Purpose**: Tracks all reward allocations and deductions

**Key Fields**:
- `user_id` (UUID): Foreign key to users
- `kiosk_id` (UUID): Foreign key to kiosks
- `batch_id` (UUID): Foreign key to bottle_batches
- `transaction_type`: wifi_minutes/bonus_minutes/penalty/refund
- `amount`: Minutes added or deducted
- `balance_before`, `balance_after`: Account balance
- `description`: Transaction details
- `reference_id`: Related transaction ID

**Frontend Interaction**:
- **WiFi Minutes**: Awarded when batch completes
- **Bonus Minutes**: Promotional rewards
- **Penalties**: Invalid bottle detection
- **Refunds**: System errors
- **Transaction History**: Displayed in user profile

**Data Flow**:
```
Batch completes → INSERT reward_transactions
→ type: 'wifi_minutes'
→ amount: 1
→ balance_before: previous total
→ balance_after: previous + 1
→ User can view transaction history
```

---

### 5. System Logging and Analytics

#### `system_logs` Table
**Purpose**: Comprehensive logging for monitoring and debugging

**Key Fields**:
- `kiosk_id` (UUID): Foreign key to kiosks
- `user_id` (UUID): Foreign key to users
- `log_level`: DEBUG/INFO/WARN/ERROR/FATAL
- `category`: system/user/kiosk/bottle/wifi/security/maintenance
- `event_type`: Specific event identifier
- `message`: Human-readable description
- `details`: JSONB with additional data
- `ip_address`: Request source
- `user_agent`: Browser/device info
- `session_id`: Session identifier

**Frontend Interaction**:
- **addLog()**: Adds entries to UI log panel
- **Error Logging**: Captures API failures
- **User Actions**: Records button clicks, navigation
- **System Events**: Device connection, disconnection

**Data Flow**:
```
User action → addLog(message, details)
→ S.log.push({ message, details, timestamp })
→ Display in UI log panel
→ Would also send to API → INSERT system_logs
```

#### `analytics_events` Table
**Purpose**: User behavior and system performance analytics

**Key Fields**:
- `kiosk_id` (UUID): Foreign key to kiosks
- `user_id` (UUID): Foreign key to users
- `event_type`: Event identifier
- `event_data`: JSONB with event details
- `session_id`: Session identifier
- `ip_address`: Request source

**Frontend Interaction**:
- **Screen Views**: Track which screens are visited
- **Feature Usage**: Track button clicks, feature engagement
- **Session Duration**: Time spent in app
- **Error Tracking**: JavaScript errors

**Data Flow**:
```
User navigates → Track event
→ Send to API → INSERT analytics_events
→ Dashboard aggregates data
→ Admin views usage statistics
```

#### `daily_statistics` Table
**Purpose**: Aggregated daily statistics for reporting

**Key Fields**:
- `kiosk_id` (UUID): Foreign key to kiosks
- `stat_date`: Date of statistics
- `total_bottles_collected`: Daily bottle count
- `total_batches_completed`: Completed batches
- `total_wifi_minutes_allocated`: WiFi time awarded
- `total_wifi_minutes_used`: WiFi time consumed
- `unique_users`: Distinct users
- `average_session_duration`: Average session length
- `peak_usage_hour**: Busiest hour
- `system_uptime_percentage`: Device availability
- `error_count`: System errors
- `maintenance_minutes`: Downtime

**Frontend Interaction**:
- **Admin Dashboard**: Displays daily/weekly/monthly stats
- **Charts**: Visual representation of data
- **Trends**: Usage patterns over time
- **Reports**: Exportable statistics

**Data Flow**:
```
Trigger: update_daily_statistics() function
→ Runs on INSERT into bottle_collections
→ Aggregates data for current date
→ UPSERT into daily_statistics
→ Admin dashboard queries for display
```

---

### 6. Maintenance and Support

#### `maintenance_records` Table
**Purpose**: Kiosk maintenance and repair records

**Key Fields**:
- `kiosk_id` (UUID): Foreign key to kiosks
- `technician_id` (UUID): Foreign key to users
- `maintenance_type`: routine/repair/upgrade/emergency
- `description`: Work description
- `parts_replaced`: Components changed
- `cost`: Maintenance cost
- `duration_minutes`: Time spent
- `status`: scheduled/in_progress/completed/cancelled
- `scheduled_date`, `started_at`, `completed_at`: Timeline

**Frontend Interaction**:
- **Admin Dashboard**: View maintenance history
- **Schedule**: Plan future maintenance
- **Status Updates**: Track progress
- **Cost Tracking**: Budget management

#### `support_tickets` Table
**Purpose**: Customer support ticket management

**Key Fields**:
- `user_id` (UUID): Foreign key to users
- `kiosk_id` (UUID): Foreign key to kiosks
- `ticket_number`: Unique identifier
- `subject`, `description`: Issue details
- `category`: technical/account/billing/general
- `priority`: low/medium/high/urgent
- `status`: open/in_progress/resolved/closed/reopened
- `assigned_to`: Support staff
- `resolution`: Solution details

**Frontend Interaction**:
- **User Portal**: Submit support tickets
- **Admin Dashboard**: View and manage tickets
- **Status Updates**: Track progress
- **Notifications**: Alerts on ticket changes

---

## Frontend Features and Database Integration

### 1. Screen Navigation

**Screens**:
- Splash (intro)
- Connect (device connection)
- Home (dashboard)
- Kiosk (bottle insertion)
- Network (WiFi session)
- Profile (user settings)
- Admin Login (authentication)
- Admin Dashboard (management)

**Database Integration**:
- User navigation tracked in `analytics_events`
- Screen preferences stored in `user_profiles`
- Session data in `wifi_sessions`

### 2. Device Connection

**Function**: `probeDevice()`, `pollDevice()`

**Database Integration**:
- Updates `kiosk_status` table
- Logs connection events in `system_logs`
- Tracks device uptime in `kiosk_status.uptime_seconds`

**Data Flow**:
```
probeDevice() → Check device availability
→ If online: pollDevice() every 3s
→ applyDeviceStatus(data) → Update UI
→ Would update kiosk_status in database
```

### 3. Bottle Insertion

**Function**: `startInsertionMode()`, `insertBottle()`

**Database Integration**:
- Each bottle: INSERT into `bottle_collections`
- Batch completion: UPDATE `bottle_batches`
- Reward allocation: INSERT into `reward_transactions`
- Statistics update: Trigger `update_daily_statistics()`

**Data Flow**:
```
User clicks "Insert Bottle"
→ startInsertionMode() → Set target (15-20 bottles)
→ Auto-insertion timer (evenly spaced over 30s)
→ Each insertBottle() call:
  → S.bottles++, S.batch++
  → If S.batch >= 5:
    → S.batch = 0, S.mins++
    → S.sessRemain += 60
    → startSess()
  → Would INSERT into bottle_collections
  → Would UPDATE bottle_batches
  → Would INSERT into reward_transactions
→ Timer expires → timeoutReset()
→ Would UPDATE bottle_batches SET status='expired'
```

### 4. Bin Level Monitoring

**Function**: `updateBinLevel()`, `showBinAlert()`

**Database Integration**:
- Real-time data from `kiosk_status.bin_level`
- Alert events logged in `system_logs`
- Maintenance triggered when bin full

**Data Flow**:
```
ESP32 ultrasonic sensor → bin_level (0-100)
→ pollDevice() → applyDeviceStatus()
→ updateBinLevel() → Update UI
→ If bin_level >= 90:
  → showBinAlert() → SweetAlert notification
  → Log to system_logs
  → Create maintenance record
```

### 5. WiFi Session Management

**Function**: `startSess()`, `updateSessUI()`

**Database Integration**:
- Session start: INSERT into `wifi_sessions`
- Session end: UPDATE `wifi_sessions`
- Data usage: Update `wifi_sessions.data_usage_mb`
- Transaction log: INSERT into `reward_transactions`

**Data Flow**:
```
Batch completes (5 bottles) → startSess()
→ INSERT into wifi_sessions (status='active')
→ INSERT into reward_transactions (type='wifi_minutes')
→ Display countdown timer
→ When session ends:
  → UPDATE wifi_sessions (status='expired')
  → Log to system_logs
```

### 6. Admin Dashboard

**Function**: `adminFetchAll()`, `adminApplyStats()`

**Database Integration**:
- Queries `kiosk_status` for real-time metrics
- Queries `daily_statistics` for reports
- Queries `wifi_sessions` for session log
- Queries `bottle_collections` for bottle count

**Data Flow**:
```
Admin logs in → adminFetchAll()
→ Query database for statistics:
  - totalBottles: SUM(bottle_collections)
  - totalMins: SUM(wifi_sessions.allocated_minutes)
  - activeSessions: COUNT(wifi_sessions WHERE status='active')
  - dailyData: Query daily_statistics
  - weeklyData: Aggregate daily_statistics
  - sessionLog: Query wifi_sessions
→ adminApplyStats() → Update UI
```

### 7. Auto-Insertion Simulation

**Function**: `startInsertionMode()` with auto-insertion

**Database Integration**:
- Simulates 15-20 bottles for testing
- Would insert into `bottle_collections` when connected
- Batch tracking in `bottle_batches`
- Statistics in `daily_statistics`

**Data Flow**:
```
User clicks "Insert Bottle"
→ targetBottles = random(15-20)
→ Calculate interval = 30000ms / targetBottles
→ setInterval() → insertBottle() every interval
→ Each bottle:
  → S.bottles++, S.batch++
  → If S.batch >= 5:
    → Complete batch, award WiFi
  → Would INSERT into bottle_collections
→ After 30s → timeoutReset()
```

---

## API Endpoints (Frontend ↔ Database)

### Current Implementation (Simulation Mode)

**Frontend Only**:
- All data stored in JavaScript state (`S` object)
- No database connection
- Simulation mode for testing

### Required Backend API Endpoints

**Device Status**:
```
GET /status
Response: { ir, batch, bottles, sessRemain, binLevel, uptime, heap, ssid }
Database: SELECT FROM kiosk_status WHERE kiosk_id = ?
```

**Bottle Insertion**:
```
POST /insert
Body: { user_id, kiosk_id, material_type }
Database: 
  - INSERT into bottle_collections
  - UPDATE bottle_batches
  - Check for batch completion
  - INSERT into reward_transactions if complete
```

**Admin Statistics**:
```
GET /admin/stats
Headers: X-Admin-Key: password
Response: { totalBottles, totalMins, activeSessions, dailyData, weeklyData, sessionLog }
Database:
  - SELECT COUNT(*) FROM bottle_collections
  - SELECT SUM(allocated_minutes) FROM wifi_sessions
  - SELECT * FROM wifi_sessions WHERE status='active'
  - SELECT * FROM daily_statistics
```

**Admin Commands**:
```
POST /admin/cmd
Headers: X-Admin-Key: password
Body: { cmd: "reset_batch"|"clear_session"|"terminate_all" }
Database:
  - reset_batch: UPDATE bottle_batches SET status='cancelled'
  - clear_session: UPDATE wifi_sessions SET status='terminated'
  - terminate_all: UPDATE wifi_sessions SET status='terminated' WHERE status='active'
```

---

## Data Flow Diagram

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Frontend  │ (PWA - index.html)
│  (State S)  │
└──────┬──────┘
       │
       ├──────────────────┐
       │                  │
       ▼                  ▼
┌─────────────┐    ┌─────────────┐
│   ESP32     │    │  Backend    │
│  (Hardware) │    │   API       │
└──────┬──────┘    └──────┬──────┘
       │                  │
       │                  ▼
       │         ┌─────────────┐
       │         │ PostgreSQL  │
       │         │  Database   │
       │         └─────────────┘
       │
       └──────────────────┐
                          │
                          ▼
                    ┌─────────────┐
                    │   Admin     │
                    │  Dashboard  │
                    └─────────────┘
```

---

## Security Considerations

### Database Security
1. **Password Hashing**: All passwords hashed with bcrypt
2. **Prepared Statements**: Prevent SQL injection
3. **Authentication**: JWT tokens for API access
4. **Authorization**: Role-based access control (user/admin/operator)
5. **HTTPS**: Encrypted database connections
6. **Row-Level Security**: Multi-tenant data isolation

### Frontend Security
1. **Admin Credentials**: Currently hardcoded (should be moved to backend)
2. **API Keys**: Stored in localStorage (should use secure storage)
3. **XSS Protection**: Input sanitization
4. **CSRF Protection**: Token-based validation
5. **Content Security Policy**: Restrict external resources

---

## Performance Considerations

### Database Optimization
1. **Indexes**: Created on frequently queried columns
2. **Partitioning**: Large tables partitioned by date
3. **Connection Pooling**: Efficient connection management
4. **Caching**: Redis for frequently accessed data
5. **Query Optimization**: EXPLAIN ANALYZE for slow queries
6. **Archiving**: Old log data moved to cold storage

### Frontend Optimization
1. **Service Worker**: Offline support and caching
2. **Polling Interval**: 3-second balance between real-time and performance
3. **State Management**: Minimal re-renders
4. **Lazy Loading**: Load data on demand
5. **Debouncing**: Prevent excessive API calls

---

## Scaling Considerations

### Database Scaling
1. **Read Replicas**: Separate read/write databases
2. **Sharding**: Distribute data across multiple servers
3. **Queue Systems**: Async processing with RabbitMQ/Kafka
4. **Monitoring**: Track database size and growth
5. **Backup Strategy**: Regular automated backups

### Frontend Scaling
1. **CDN**: Static asset delivery
2. **Load Balancing**: Multiple app instances
3. **WebSocket**: Real-time updates instead of polling
4. **Progressive Enhancement**: Graceful degradation
5. **A/B Testing**: Feature flags for gradual rollout

---

## Future Enhancements

### Database
1. **User Authentication**: Full login/registration system
2. **Multi-Kiosk Support**: Centralized management
3. **Advanced Analytics**: Machine learning predictions
4. **Payment Integration**: Direct WiFi purchase
5. **Gamification**: Leaderboards and achievements

### Frontend
1. **Real Backend Integration**: Replace simulation with API calls
2. **Push Notifications**: Session expiry alerts
3. **Offline Mode**: Full offline capability
4. **Multi-language**: Internationalization
5. **Accessibility**: WCAG compliance

---

## Conclusion

The EcoConnect system consists of a sophisticated database schema designed to track all aspects of the bottle-for-WiFi exchange process. The frontend currently operates in simulation mode but is architected to integrate seamlessly with the database through REST API endpoints. The modular design allows for easy scaling and enhancement as the system grows.
