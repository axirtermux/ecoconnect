# EcoConnect - Smart WiFi Kiosk

Plastic bottle-based WiFi access system for sustainable communities.

## 🌱 Features

- **PWA Support**: Installable on Android devices as a native app
- **Real-time Monitoring**: IR sensor detection and ultrasonic bin level tracking
- **Offline Capability**: Works without internet connection using service worker
- **Admin Dashboard**: Restricted access for system monitoring
- **Simultaneous Mode**: Rapid bottle insertion without timeout
- **SweetAlert Notifications**: Bin capacity alerts when full

## 📱 Installing on Android

### Method 1: Direct from Vercel (Recommended)

1. **Deploy to Vercel** (see Deployment section below)
2. Open the deployed URL in Chrome on your Android device
3. Tap the **three-dot menu** (⋮) in the top-right corner
4. Select **"Add to Home screen"** or **"Install app"**
5. The app will be installed on your home screen like a native app

### Method 2: Via QR Code

1. Deploy to Vercel
2. Generate a QR code for your Vercel URL using any QR code generator
3. Scan the QR code with your Android phone camera
4. Open in Chrome and follow Method 1 steps 3-5

## 🚀 Deployment to Vercel

### Prerequisites

- [Vercel Account](https://vercel.com/signup) (free)
- [Git](https://git-scm.com/) installed
- [GitHub](https://github.com/) account (recommended)

### Step-by-Step Deployment

#### Option 1: Using Vercel CLI (Recommended)

1. **Install Vercel CLI**
   ```bash
   npm install -g vercel
   ```

2. **Initialize Git Repository**
   ```bash
   cd c:\Users\ASUS TUF GAMING\Desktop\CAPSTONE\essumain\IT\mica_capstone\system
   git init
   git add .
   git commit -m "Initial commit"
   ```

3. **Deploy to Vercel**
   ```bash
   vercel
   ```
   - Follow the prompts (press Enter for defaults)
   - Select "No" for "Link to existing project"
   - Your app will be deployed instantly

4. **Add to Git (Optional)**
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/ecoconnect.git
   git push -u origin main
   ```

#### Option 2: Using Vercel Dashboard

1. **Push to GitHub**
   ```bash
   cd c:\Users\ASUS TUF GAMING\Desktop\CAPSTONE\essumain\IT\mica_capstone\system
   git init
   git add .
   git commit -m "Initial commit"
   # Create a new repository on GitHub first
   git remote add origin https://github.com/YOUR_USERNAME/ecoconnect.git
   git push -u origin main
   ```

2. **Deploy via Vercel Dashboard**
   - Go to [vercel.com](https://vercel.com)
   - Click "Add New Project"
   - Import your GitHub repository
   - Click "Deploy"
   - Wait for deployment to complete

3. **Configure Domain (Optional)**
   - Go to project settings in Vercel
   - Add a custom domain if desired

### Post-Deployment Configuration

1. **Update API Configuration**
   - Open your deployed app
   - Go to Profile → Settings → Device API Config
   - Enter your ESP32's IP address (e.g., `192.168.4.1`)
   - This will be saved to localStorage

2. **Test PWA Installation**
   - Open the app on Android Chrome
   - Verify "Add to Home screen" option appears
   - Install and test offline functionality

## 🔧 Configuration

### ESP32 Integration

The app expects your ESP32 to expose these API endpoints:

```
GET  /status       → { ir, batch, bottles, sessRemain, binLevel, uptime, heap, ssid }
POST /insert       → trigger bottle insert (for testing)
POST /admin/cmd    → body: { cmd: "reset_batch"|"clear_session"|"terminate_all" }
GET  /admin/stats  → { totalBottles, totalMins, activeSessions, dailyData, weeklyData, sessionLog }
```

### Admin Credentials

- **Username**: `admin`
- **Password**: `eco2024`

To access admin panel: Long-press the "About" button in the app.

## 📂 Project Structure

```
system/
├── index.html          # Main application
├── manifest.json       # PWA manifest
├── sw.js              # Service worker for offline support
├── vercel.json        # Vercel configuration
├── icon-192.png       # App icon (192x192)
├── icon-512.png       # App icon (512x512)
└── README.md          # This file
```

## 🌐 Environment Variables

No environment variables needed. The app uses localStorage for configuration.

## 🔒 Security Notes

- Admin credentials are stored in the frontend (change for production)
- API calls are made over HTTP (use HTTPS in production)
- Consider implementing backend authentication for admin features

## 📱 PWA Requirements Met

- ✅ Manifest file with all required fields
- ✅ Service worker for offline support
- ✅ Icons in multiple sizes (192x192, 512x512)
- ✅ Standalone display mode
- ✅ Theme color and background color
- ✅ Shortcuts for quick access

## 🐛 Troubleshooting

### App won't install on Android

- Ensure you're using Chrome browser
- Check that the site is served over HTTPS (Vercel provides this)
- Verify manifest.json is accessible at `/manifest.json`
- Clear browser cache and try again

### Service worker not registering

- Open Chrome DevTools → Application → Service Workers
- Check for errors in the console
- Ensure sw.js is in the root directory

### API connection issues

- Verify ESP32 is on the same network as the device
- Check ESP32 IP address in app settings
- Ensure ESP32 is powered and running

## 📝 License

This project is part of a capstone project for sustainable community development.

## 🤝 Contributing

This is a capstone project. For questions or suggestions, please contact the development team.

## 📞 Support

For deployment issues:
- Check Vercel deployment logs
- Verify all files are uploaded
- Ensure manifest.json and sw.js are in the root directory

## 🔄 Updates

To update the deployed app:

```bash
# Make changes locally
git add .
git commit -m "Update description"
git push

# Vercel will auto-deploy on push
```

## 📊 Analytics

Vercel provides built-in analytics for your deployment. Check the Vercel dashboard for:
- Page views
- Unique visitors
- Geographic distribution
- Device breakdown
