# QueueIT - Sunday Demo Requirements (MVP)
**Deadline:** Sunday, March 15th, 2026

## Goal
One host connects their device to a speaker and plays music (Apple Music or Spotify). Everyone at the function joins the room, queues songs, votes on what plays next — and the queue dynamically reorders based on votes.

## Use Case
- **Host:** Subscribed to Apple Music or Spotify, connects phone/device to speaker, plays the shared queue.
- **Guests:** Join via room code, add songs, vote. No playback on their devices — they control what the host plays.

---

## Core Requirements

### 1. Room & Join
- [x] Host creates room (unique join code).
- [x] Guests join via code.
- [ ] Polish: Join Room screen is clear and reliable for demo.

### 2. Queue with Voting
- [x] Users add songs to shared queue.
- [x] Users vote (up/down) on queue items.
- [x] Queue sorts by votes (highest first) → next song to play is the top-voted queued item.
- [x] Real-time sync so everyone sees queue + vote changes.
- [ ] Polish: Queue UI clearly shows order and vote counts.

### 3. Host Playback
- [x] Host plays Apple Music via MusicKit.
- [x] When song ends, backend advances to next (highest-voted song).
- [ ] **Spotify host option:** If host has Spotify (not Apple Music), they can play via Spotify.
- [ ] Host connects to speaker — device audio output (no app change needed for wired/BT speakers).

### 4. Search (Match Host’s Provider)
- [x] Apple Music search (when host uses Apple Music).
- [ ] Spotify search in app (when host uses Spotify).
- [ ] *Stretch:* Host picks provider at room creation; search uses that provider.

### 5. Minimal UI
- [ ] Join Room screen (enter code).
- [ ] Active queue with vote buttons.
- [ ] Host: player controls (play, pause, skip).
- [ ] Guests: view queue, add songs, vote — no playback controls.

---

## Out of Scope (for this MVP)
- Guest device playback (everyone listens via host’s speaker).
- Cross-platform sync (Host Apple + Guest Spotify both playing).
- Song-matching/resolution across platforms (needed only for above).

---

## Priority Order for Sunday
1. **Verify & polish:** Join Room, queue display, voting — make demo flow smooth.
2. **Spotify host path:** If host uses Spotify, enable search + playback for that flow.
3. **Edge cases:** Skip, empty queue, leave room.

---
*Done is better than perfect. Ship it.*
