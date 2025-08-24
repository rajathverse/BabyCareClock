# 🍼 Milu Care Clock

A beautiful Progressive Web App (PWA) for tracking baby care activities and medication schedules.

## ✨ Features

- **📱 Mobile-Optimized**: Perfect touch targets and responsive design
- **⏰ Smart Reminders**: Visual indicators and notifications for due activities
- **🔄 Flexible Scheduling**: Custom intervals from 30 minutes to 7 days
- **📊 Activity Tracking**: Medicine and care activity management
- **💜 Beautiful Design**: Purple-themed UI with custom baby photo icon
- **📱 PWA Ready**: Install on any device for native app experience

## 🚀 Live App

Visit: **https://milucareclock.com**

## 📱 Installation

### Mobile (iOS/Android):
1. Open https://milucareclock.com in your browser
2. Tap "Add to Home Screen" when prompted
3. Enjoy the native app experience with Milu's photo as the icon!

### Desktop:
1. Visit https://milucareclock.com
2. Click the install prompt or use browser's "Install App" option
3. Access from your desktop/taskbar

## 🎯 How to Use

1. **Add Activities**: Click "+" to add feeding, medicine, or custom care activities
2. **Set Schedules**: Choose frequency (every 2 hours, 4 hours, etc.)
3. **Track Progress**: Mark activities complete with one tap
4. **Visual Cues**: 
   - 🟢 Green = Recently completed
   - 🟡 Yellow = Due soon (15 min warning)
   - 🔴 Red = Overdue

## 🔔 Notifications

- **Desktop/Android**: Full notification support with 15-minute warnings
- **iOS**: Visual indicators and PWA notifications when installed
- **Always**: In-app visual status and alerts

## 🏗️ Technical Details

- **Frontend**: Vanilla HTML/CSS/JavaScript
- **Storage**: LocalStorage for offline capability
- **Hosting**: AWS S3 + CloudFront + Route53
- **PWA**: Service Worker + Web App Manifest
- **Icons**: Custom baby photo + SVG fallback

## 📂 Project Structure

```
├── baby-care-scheduler.html    # Main application
├── manifest.json              # PWA configuration
├── sw.js                     # Service worker for offline
└── icons/
    ├── app-icon.jpg          # Custom baby photo icon
    └── baby-icon.svg         # SVG fallback icon
```

## 💝 Made with Love

Created for tracking Milu's care schedule with love and attention to detail.

---

**🍼 Happy Baby Care Tracking! 👶**
