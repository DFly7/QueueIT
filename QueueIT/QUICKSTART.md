# QueueUp iOS - Quick Start Guide

Get the QueueUp iOS app running in 5 minutes!

## 🚀 Prerequisites

- **Xcode 15+** installed
- **iOS 17+** device or simulator
- **Backend running** (see QueueITbackend/README.md)
- **Network access** to backend

---

## ⚡ Quick Setup (Development)

### Step 1: Configure Backend URL

Open `QueueIT/QueueIT/QueueITApp.swift` and update:

```swift
// Line 18-19
private let backendURL = URL(string: "http://localhost:8000")!
```

**Options:**
- Local: `http://localhost:8000`
- ngrok: `https://your-ngrok-url.ngrok.io`
- Deployed: `https://your-backend.fly.io`

### Step 2: Start Backend

```bash
cd QueueITbackend
source venv/bin/activate
uvicorn app.main:app --reload
```

Verify backend is running:
```bash
curl http://localhost:8000/api/v1/ping
# Should return: {"message": "pong"}
```

### Step 3: Run iOS App

1. Open `QueueIT/QueueIT.xcodeproj` in Xcode
2. Select target device (iPhone 15 Pro simulator recommended)
3. Press `Cmd + R` to build and run

---

## 📱 First Run Experience

### 1. Sign In (Mock Auth)
- Tap "Sign In"
- Enter any email (e.g., `test@example.com`)
- Tap "Continue"

### 2. Create Your First Session
- Tap "Create Session"
- Enter a join code (e.g., `PARTY2024`)
- Tap "Create Session"

### 3. Search and Add Music
- Tap the floating "+" button
- Search for a song (e.g., "Mr. Brightside")
- Tap "+" to add to queue
- Watch the success animation!

### 4. Vote on Songs
- Tap ↑ or ↓ arrows on queue items
- Watch vote count animate
- Queue re-sorts automatically

### 5. Test Real-Time (Two Devices)
1. Create session on Device 1
2. Note the join code
3. Join session on Device 2 with the code
4. Add a song on Device 1 → see it appear on Device 2!
5. Vote on Device 2 → see votes update on Device 1!

---

## 🔧 Configuration Options

### Backend URL (QueueITApp.swift)
```swift
// Development (local)
private let backendURL = URL(string: "http://localhost:8000")!

// Development (network simulator)
private let backendURL = URL(string: "http://127.0.0.1:8000")!

// Development (ngrok)
private let backendURL = URL(string: "https://abc123.ngrok.io")!

// Production
private let backendURL = URL(string: "https://api.queueup.app")!
```

### Supabase (For Production Auth)
```swift
private let supabaseURL = "https://your-project.supabase.co"
private let supabaseAnonKey = "your-anon-key-here"
```

---

## 🐛 Troubleshooting

### "Cannot connect to backend"
**Problem:** API calls failing
**Solution:**
1. Verify backend is running: `curl http://localhost:8000/api/v1/ping`
2. Check backend URL in QueueITApp.swift
3. If using simulator, use `127.0.0.1` instead of `localhost`
4. Check CORS settings in backend (should allow localhost)

### "Search returns no results"
**Problem:** Spotify search failing
**Solution:**
1. Backend needs valid Spotify credentials
2. Check backend logs for Spotify API errors
3. Verify `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` in backend .env

### "WebSocket not connecting"
**Problem:** Real-time updates not working
**Solution:**
1. WebSocket endpoint may not be implemented yet in backend
2. Check console logs for WebSocket connection errors
3. Backend needs to implement `/api/v1/sessions/{id}/realtime`

### "Mock authentication not working"
**Problem:** Sign in button does nothing
**Solution:**
- Mock auth is intentional for development
- After entering email, you should be signed in immediately
- Check console for any error messages

### "Session create/join fails with 401"
**Problem:** Authentication errors
**Solution:**
1. Backend may require real JWT tokens
2. Check backend auth middleware configuration
3. For development, backend should skip JWT verification or accept mock tokens

---

## 🏗️ Project Structure

```
QueueIT/
├── QueueIT.xcodeproj          # Xcode project
└── QueueIT/
    ├── Models/                 # Data models
    │   ├── User.swift
    │   ├── Session.swift
    │   └── AddSongRequest.swift
    ├── Services/               # Business logic
    │   ├── AuthService.swift
    │   ├── QueueAPIService.swift
    │   ├── SessionCoordinator.swift
    │   └── WebSocketService.swift
    ├── Views/                  # UI screens
    │   ├── RootView.swift
    │   ├── WelcomeView.swift
    │   ├── SessionView.swift
    │   ├── Components/
    │   │   ├── NowPlayingCard.swift
    │   │   └── QueueItemCard.swift
    │   └── ...
    ├── Theme/                  # Design system
    │   └── AppTheme.swift
    ├── QueueITApp.swift        # App entry point
    └── Track.swift             # Legacy search model
```

---

## 🧪 Test Scenarios

### Basic Flow
1. ✅ Sign in with any email
2. ✅ Create session with code "TEST123"
3. ✅ Search for "Wonderwall"
4. ✅ Add song to queue
5. ✅ Upvote the song
6. ✅ Leave session

### Multi-User Flow
1. ✅ Device 1: Create session "PARTY"
2. ✅ Device 2: Join session "PARTY"
3. ✅ Device 1: Add song
4. ✅ Device 2: See song appear in queue
5. ✅ Device 2: Vote on song
6. ✅ Device 1: See vote count update

### Host Controls
1. ✅ Create session (you are host)
2. ✅ Add multiple songs
3. ✅ Tap crown icon → Host Controls
4. ✅ Toggle lock queue
5. ✅ Skip current track

---

## 📝 Environment Variables (Backend)

Ensure your backend `.env` has:

```bash
ENVIRONMENT=development
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLIC_ANON_KEY=your-anon-key
SPOTIFY_CLIENT_ID=your-spotify-client-id
SPOTIFY_CLIENT_SECRET=your-spotify-client-secret
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8000
```

---

## 🎯 Next Steps

Once you have the app running:

### For Development
1. ✅ Test all screens and flows
2. ✅ Try multi-device real-time updates
3. ✅ Experiment with the design system
4. ✅ Add custom features or screens

### For Production
1. 🔧 Integrate Supabase Swift SDK
2. 🔧 Replace mock auth with real email/magic link
3. 🔧 Configure production backend URL
4. 🔧 Add QR code generation/scanning
5. 🔧 Implement Spotify SDK for playback
6. 🔧 Add analytics and crash reporting

---

## 📚 Documentation

- **README.md** - Complete feature documentation
- **IMPLEMENTATION_NOTES.md** - Technical implementation details
- **FEATURES_SUMMARY.md** - Visual feature overview
- **Backend API Docs** - `../QueueITbackend/docs/API_CONTRACTS.md`

---

## 🆘 Need Help?

### Check Console Logs
In Xcode, view the console (`Cmd + Shift + Y`) for:
- API request/response logs
- WebSocket connection status
- Error messages

### Backend Logs
In your backend terminal:
- Watch for incoming requests
- Check for authentication errors
- Verify Spotify API calls

### Common Issues
- **Build errors**: Clean build folder (`Cmd + Shift + K`)
- **Simulator issues**: Reset simulator (Device → Erase All Content)
- **Network issues**: Check firewall/VPN settings

---

## ✅ Success Checklist

You're ready when:
- ✅ Backend returns 200 on `/api/v1/ping`
- ✅ iOS app builds without errors
- ✅ Can sign in (mock auth)
- ✅ Can create a session
- ✅ Can search for songs
- ✅ Can add songs to queue
- ✅ Can vote on songs
- ✅ Queue updates in real-time (with multiple devices)

---

**Happy coding! 🎉 Let's make collaborative music amazing!**


