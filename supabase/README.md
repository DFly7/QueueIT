## Supabase Schema, Policies, and Realtime

This folder contains the Postgres schema, RLS policy scaffolding, and Realtime configuration for QueueIT.

### Important Notes

- The included `schema.sql` mirrors the current working model. It is provided for reference and may require reordering and constraint adjustments before execution in a fresh database.
- RLS policies in `rls_policies.sql` are scaffolds. Review and adapt to your exact requirements before enabling.
- Realtime is enabled for multi-user synchronization of votes, queue changes, and session updates.

### Files

- `schema.sql`: Tables for users, sessions, queued_songs, songs, votes (as currently defined).
- `rls_policies.sql`: Suggested RLS policies to enforce access by session membership and user identity.
- `realtime.sql`: SQL to enable Realtime on required tables.

### Recommended Workflow

1. Apply `schema.sql` (adjusting order/constraints as necessary in your environment).
2. Seed any required baseline rows (optional).
3. Enable and verify RLS policies from `rls_policies.sql`.
4. Enable Realtime using `realtime.sql`.
5. Run integration tests against the protected endpoints.

---

## Realtime Configuration

QueueIT uses **Supabase Realtime** for real-time synchronization across multiple users in a session. When any user votes, adds a song, or the currently playing track changes, all other users receive updates automatically.

### Enabled Tables

The following tables are added to the `supabase_realtime` publication:

| Table | Purpose |
|-------|---------|
| `votes` | Sync vote counts across all session members |
| `queued_songs` | Sync queue additions, status changes (playing/played/skipped) |
| `sessions` | Sync current_song changes, session lock status |

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│  iOS App (User A)                  Supabase                            │
│  ┌──────────────┐                 ┌───────────┐                        │
│  │ Vote on song │────────────────▶│ Database  │                        │
│  └──────────────┘                 │  INSERT   │                        │
│                                   └─────┬─────┘                        │
│                                         │                              │
│                                         ▼                              │
│                                   ┌───────────┐                        │
│                                   │ Realtime  │                        │
│                                   │ Broadcast │                        │
│                                   └─────┬─────┘                        │
│                                         │                              │
│                    ┌────────────────────┼────────────────────┐         │
│                    ▼                    ▼                    ▼         │
│  iOS App (User A)              iOS App (User B)      iOS App (User C)  │
│  ┌──────────────┐              ┌──────────────┐      ┌──────────────┐  │
│  │ Already has  │              │ Receives     │      │ Receives     │  │
│  │ optimistic   │              │ vote update  │      │ vote update  │  │
│  │ UI update    │              │ via Realtime │      │ via Realtime │  │
│  └──────────────┘              └──────────────┘      └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### iOS Implementation

The iOS app subscribes to Realtime changes via `RealtimeService.swift`:

```swift
// Subscribe to session changes
let channel = client.realtimeV2.channel("session_\(sessionId)")

channel.onPostgresChange(AnyAction.self, schema: "public", table: "votes") { action in
    // Refresh session to get updated vote counts
}

channel.onPostgresChange(AnyAction.self, schema: "public", table: "queued_songs", 
                         filter: "session_id=eq.\(sessionId)") { action in
    // Refresh session to get updated queue
}

channel.onPostgresChange(AnyAction.self, schema: "public", table: "sessions",
                         filter: "id=eq.\(sessionId)") { action in
    // Refresh session for current_song changes
}

await channel.subscribe()
```

### Enabling Realtime (Already Done)

Realtime has been enabled on the production database. For new environments, run:

```sql
-- Enable Realtime on tables needed for multi-user sync
ALTER PUBLICATION supabase_realtime ADD TABLE votes, queued_songs, sessions;
```

Or via the Supabase Dashboard:
1. Go to Database → Publications
2. Find `supabase_realtime`
3. Toggle on: `votes`, `queued_songs`, `sessions`

### RLS and Realtime

Supabase Realtime respects Row Level Security policies. Users will only receive change events for rows they have SELECT access to. The existing RLS policies ensure:

- Users can see votes on songs in their current session
- Users can see queued_songs in their current session  
- Users can see their current session details

### Performance Considerations

- Realtime checks RLS policies for each change event per subscriber
- For high-traffic sessions, consider using Broadcast instead of Postgres Changes
- The current implementation uses a simple refresh strategy; future optimization could parse change payloads directly
