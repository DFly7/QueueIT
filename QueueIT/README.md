# QueueUp iOS App

**QueueUp** is a social, collaborative music queue app where groups create sessions, search for songs, vote on tracks, and enjoy a live-updating shared queue.

## 🎨 Design Philosophy

- **Party-Ready Aesthetic**: Vibrant gradients, smooth animations, energetic feel
- **Real-Time First**: Everything updates instantly via WebSocket
- **Group-Focused**: Built for collaboration and social interaction
- **Minimal Friction**: Create/join/add/vote flows are instant and intuitive

## 🏗️ Architecture

### Models
- **User**: Basic user profile with UUID and optional username
- **Session**: Session details, join code, host, timestamps
- **QueuedSongResponse**: Enriched queue item with song, votes, added_by
- **Track**: Spotify track with metadata (name, artist, album, duration, image)
- **Vote Models**: Request/response for upvoting/downvoting

### Services
- **AuthService**: Handles Supabase JWT authentication (mock for development)
- **QueueAPIService**: Complete REST client for all backend endpoints
- **SessionCoordinator**: Main state manager for session lifecycle and queue
- **WebSocketService**: Real-time updates for queue/votes/now-playing changes

### Views

#### Welcome & Auth
- **RootView**: Top-level coordinator (auth → welcome → session)
- **WelcomeView**: Entry point with Create/Join buttons
- **SimpleAuthView**: Mock authentication (replace with Supabase Auth SDK)

#### Session Flows
- **CreateSessionView**: Create session with custom join code
- **JoinSessionView**: Join session by code (QR scanner placeholder)
- **SessionView**: Main session screen with Now Playing + Queue

#### Components
- **NowPlayingCard**: Large, prominent display with album art and vote buttons
- **QueueItemCard**: Compact queue item with votes and track info
- **SearchAndAddView**: Enhanced search with instant feedback animations
- **HostControlsView**: Host-only controls (skip, lock queue)

### Theme
- **AppTheme**: Centralized design system with gradients, colors, typography, animations
- **View Modifiers**: Reusable styles (gradient buttons, cards, etc.)

## 🔧 Configuration

### 1. Update QueueITApp.swift

Edit the configuration constants in `QueueITApp.swift`:

```swift
private let supabaseURL = "https://your-project.supabase.co"
private let supabaseAnonKey = "your-anon-key"
private let backendURL = URL(string: "http://localhost:8000")! // or your deployed backend
```

### 2. Backend Setup

Ensure the FastAPI backend is running and accessible. See `QueueITbackend/README.md` for setup instructions.

### 3. Supabase Setup (Production)

For production, integrate the [Supabase Swift SDK](https://github.com/supabase/supabase-swift):

1. Add Supabase package via SPM
2. Replace `AuthService.mockSignIn()` with real Supabase auth flows
3. Handle token refresh and expiry
4. Update `QueueAPIService` to use Supabase client tokens

## 🚀 Features

### ✅ Implemented
- ✅ JWT-based authentication (mock for dev, Supabase-ready)
- ✅ Create/Join sessions with custom join codes
- ✅ Real-time session state management
- ✅ Spotify track search via backend proxy
- ✅ Add songs to queue with instant feedback
- ✅ Upvote/downvote with live updates
- ✅ Now Playing display with large album art
- ✅ Queue list with real-time sorting by votes
- ✅ Host controls (skip track, lock queue)
- ✅ WebSocket client for real-time updates
- ✅ Beautiful party-ready UI with gradients and animations
- ✅ Empty states and loading indicators

### 🔮 Future Enhancements
- QR code generation and scanning for join codes
- In-app playback (Spotify SDK integration)
- Skip vote progress indicator (50%+ threshold)
- User profiles and session history
- Push notifications for session events
- Social features (reactions, chat)

## 🎯 User Flows

### 1. Sign In
- User enters email → mock authentication → welcomed to app

### 2. Create Session
- User taps "Create Session" → enters join code → session created
- WebSocket connection established
- User is now host

### 3. Join Session
- User taps "Join Session" → enters join code → joined
- WebSocket connection established
- Queue and Now Playing load instantly

### 4. Add Music
- Tap floating "+" button → search for tracks → tap to add
- "Added to Queue!" animation plays
- Queue updates in real-time for all participants

### 5. Vote
- Tap up/down arrows on any queue item
- Vote count animates and updates
- Queue re-sorts by votes automatically

### 6. Host Controls
- Host taps crown icon → skip current track or lock queue
- Changes broadcast to all participants via WebSocket

## 📱 UI/UX Highlights

- **Dark Mode by Default**: Party-ready aesthetic with dark gradient backgrounds
- **Vibrant Gradients**: Pink/purple and cyan/green gradients throughout
- **Smooth Animations**: Bouncy, responsive micro-interactions on votes and adds
- **Large Album Art**: Prominent Now Playing card with 280x280 album art
- **Compact Queue Items**: Efficient layout with thumbnail, info, and vote buttons
- **Floating Add Button**: Accessible, prominent call-to-action
- **Real-Time Feedback**: Everything updates instantly without manual refresh

## 🧪 Testing

### Manual Testing Checklist
- [ ] Sign in flow (mock auth)
- [ ] Create session with valid join code
- [ ] Join session with valid code
- [ ] Search for tracks (requires backend running)
- [ ] Add track to queue
- [ ] Upvote/downvote queue items
- [ ] Verify queue sorting by votes
- [ ] Skip track as host
- [ ] Leave session
- [ ] WebSocket reconnection on network drop

### Backend API Testing
Ensure backend is running and accessible:
```bash
cd QueueITbackend
source venv/bin/activate
uvicorn app.main:app --reload
```

Test endpoints with:
- GET `/api/v1/spotify/search?q=test&limit=10` (with Bearer token)
- POST `/api/v1/sessions/create` (with Bearer token)
- GET `/api/v1/sessions/current` (with Bearer token)

## 🔐 Security Notes

- **Mock Auth**: Current implementation uses mock JWT for development
- **Token Storage**: Tokens stored in UserDefaults (use Keychain for production)
- **HTTPS**: Always use HTTPS/WSS in production
- **Token Refresh**: Implement token refresh logic for production

## 📚 Backend API Reference

See `QueueITbackend/docs/API_CONTRACTS.md` for complete API documentation.

### Key Endpoints
- `POST /api/v1/sessions/create` - Create new session
- `POST /api/v1/sessions/join` - Join by code
- `GET /api/v1/sessions/current` - Get full session state
- `POST /api/v1/songs/add` - Add song to queue
- `POST /api/v1/songs/{id}/vote` - Vote on queued song
- `PATCH /api/v1/sessions/control_session` - Host controls
- `GET /api/v1/spotify/search` - Search Spotify catalog

### WebSocket Events (Planned)
- `queue.updated` - Queue changed (add/remove)
- `votes.updated` - Vote counts changed
- `now_playing.updated` - Now playing track changed
- `session.updated` - Session metadata changed

## 🛠️ Development

### Requirements
- Xcode 15+
- iOS 17+ target
- Swift 5.9+
- Running QueueUp backend

### Project Structure
```
QueueIT/
├── Models/              # Data models matching backend schemas
├── Services/            # API client, auth, WebSocket, coordinator
├── Views/               # SwiftUI screens and components
│   ├── Components/      # Reusable UI components
│   └── ...              # Main view files
├── Theme/               # Design system and styles
└── QueueITApp.swift     # App entry point
```

### Adding New Features
1. Update backend schema/endpoints if needed
2. Add/update models to match backend contracts
3. Extend API service with new endpoint methods
4. Update SessionCoordinator if state management needed
5. Create/update SwiftUI views
6. Test integration with backend

## 📝 Notes

- **WebSocket URL**: Auto-converts http → ws, https → wss
- **Date Decoding**: Uses ISO8601 strategy to match backend
- **Field Aliasing**: Models use `CodingKeys` to match backend snake_case
- **Error Handling**: All API calls wrapped in do-catch with error publishing
- **Main Actor**: UI updates annotated with @MainActor for thread safety

## 🙋 Support

For issues or questions:
1. Check backend logs for API errors
2. Verify JWT token is valid and not expired
3. Ensure WebSocket connection is established
4. Check Xcode console for debug logs

---

**Built with ❤️ for collaborative music experiences.**


