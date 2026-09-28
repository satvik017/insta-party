# InstaParty - Real-Time Instagram Reels Watch Party (Flutter)

A Flutter application that allows **two users to watch the same Instagram Reels simultaneously in real time**, featuring synchronized playback (play/pause/seek), live floating emoji reactions, watch party chat, and custom reel loading via In-App WebView.

---

## 🌟 Key Features

1. **Simultaneous Real-Time Playback Synchronization**:
   - Sub-second synchronization powered by **Firebase Realtime Database** (with automatic zero-config live relay fallback).
   - Instant synced **Play**, **Pause**, **Seek (-5s / +5s)**, and **Reel Switching**.
   - Built-in drift compensation: automatically checks video timestamps and re-aligns partner playback if video drifts beyond 1.5 seconds.
   - Echo-prevention logic: actions triggered by user A don't bounce back and cause stuttering loops.

2. **In-App Instagram WebView Player**:
   - Uses `webview_flutter` with a two-way JavaScript synchronization bridge.
   - Automatically supports:
     - **Embed View**: Clean, ad-free, clutter-free vertical reel view optimized for mobile.
     - **Full Web View**: Standard Instagram page with creator details.
     - **Custom Reel Links**: Paste any Instagram Reel URL (`https://www.instagram.com/reel/C8h7.../` or shortcode) to immediately stream to both users.

3. **Curated Trending Reels Library**:
   - Pre-loaded categories: *Nature, Comedy, Travel, Sports, Pets, Art*.
   - Allows users to start co-watching with 1 tap.

4. **Interactive Co-Watching Elements**:
   - **Floating Emoji Reactions** (❤️, 🔥, 😂, 😮, 👏): Real-time animated emoji bursts that rise across both users' screens with the sender's name.
   - **Live Watch Party Chat**: Real-time slide-up messaging sheet so users can talk without closing or interrupting the video.
   - **Host & Guest Controls**: Host can toggle "Host Only Control" or allow Co-Host shared controls.
   - **Easy Room Codes**: 6-character room codes (e.g., `SYNC-4892`) with one-tap copy and share.

5. **Built-in Dual-User Split-Screen Test Mode**:
   - Test two users syncing simultaneously on a single phone or emulator without needing two separate physical devices!

---

## 🏗️ Project Architecture

```
lib/
├── main.dart                          # App entry point & dark theme setup
├── models/
│   ├── party_room.dart                # PartyRoom, ChatMessage, Reaction models
│   └── reel_item.dart                 # Reel model, URL parsers, curated feed
├── services/
│   ├── sync_service.dart              # Abstract sync interface
│   ├── firebase_sync_service.dart     # Firebase Realtime Database implementation
│   ├── simulated_sync_service.dart    # High-speed local relay for instant testing
│   └── sync_manager.dart              # State manager & backend controller
├── theme/
│   └── app_theme.dart                 # Instagram gradient & dark aesthetics
├── widgets/
│   ├── synced_insta_webview.dart      # In-App WebView + JS Sync Bridge
│   ├── reaction_overlay.dart          # Animated floating emoji bursts
│   ├── party_chat_sheet.dart          # Live party chat bottom sheet
│   ├── reel_selector_sheet.dart       # Reel category picker & custom URL parser
│   └── sync_controls_overlay.dart     # Floating player HUD & partner status badge
└── screens/
    ├── home_screen.dart               # Host/Join dashboard & room code input
    ├── watch_party_screen.dart        # Main synchronized reel watch party screen
    └── dual_sync_demo_screen.dart     # Side-by-side 2-user sync simulator
```

---

## 🚀 How to Run the Application

### 1. Run on Android Emulator or Physical Device
```bash
flutter run
```
Or specify the device:
```bash
flutter run -d emulator-5554
```

### 2. Testing Two Users Simultaneously

You have two easy ways to test:

#### Option A: Split-Screen Dual-User Simulator (Instant, 1 device)
- On the Home screen, tap **"Dual-User Realtime Preview"**.
- This launches Host (User 1) and Guest (User 2) side-by-side on your screen.
- Tap **Play/Pause**, **Next Reel**, or send **❤️ / 🔥** reactions to observe both viewports reacting in real time!

#### Option B: Two Separate Devices / Windows
1. **Device 1 (Host)**: Tap **"Create Party Room"**. Note the 6-character code (e.g., `SYNC-9B2F`).
2. **Device 2 (Guest)**: Enter the code `SYNC-9B2F` into the Join box and tap **"Join"**.
3. Both users will now be locked into the exact same reel with synchronized play/pause, seek, and live chat!

---

## ☁️ Connecting Your Own Firebase Project

The app is already equipped with `FirebaseSyncService` using `firebase_database`:
1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a project.
2. Add an Android app with package name:
   `com.instasync.watchparty.insta_sync_party`
3. Download `google-services.json` and place it in:
   `android/app/google-services.json`
4. Under **Build > Realtime Database**, click **Create Database** and set rules to test mode:
   ```json
   {
     "rules": {
       "party_rooms": {
         ".read": true,
         ".write": true
       }
     }
   }
   ```
5. When `google-services.json` is detected, the app automatically switches to Firebase Realtime Database across all networks globally!
