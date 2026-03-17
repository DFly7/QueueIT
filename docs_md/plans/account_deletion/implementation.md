# In-App Account Deletion — Implementation Notes

## What Was Built

Full implementation of the plan at `in-app_account_deletion_c7baab3d.plan.md`.

---

## Files Created

| File | Description |
|---|---|
| `supabase/migrations/20260322_delete_user_data_rpc.sql` | `delete_user_data(p_user_id)` SECURITY DEFINER function — atomically deletes all public user data in one transaction |
| `QueueIT/QueueIT/Views/AccountSheet.swift` | New sheet with user info, Sign Out, and Delete Account (with confirmation alert) |

---

## Files Modified

| File | Change |
|---|---|
| `QueueITbackend/app/core/config.py` | Added `supabase_service_role_key` setting |
| `QueueITbackend/ENV.example` | Added `SUPABASE_SERVICE_ROLE_KEY` comment |
| `QueueITbackend/app/repositories/user_repo.py` | Added `delete_account(user_id)` function — creates admin client, calls RPC, then `auth.admin.delete_user` |
| `QueueITbackend/app/api/v1/users.py` | Added `DELETE /api/v1/users/me` endpoint — returns 204, 503 if key not set |
| `QueueIT/QueueIT/Services/AuthService.swift` | Added `deleteAccount()` — calls backend DELETE, then `signOut()` on 204 |
| `QueueIT/QueueIT/Views/WelcomeView.swift` | "Account" button in user footer opens `AccountSheet`; observes `hostEndedSession` to show toast |
| `QueueIT/QueueIT/Views/SessionView.swift` | `person.circle` toolbar icon opens `AccountSheet` |
| `QueueIT/QueueIT/Services/SessionCoordinator.swift` | Added `hostEndedSession: Bool`; `refreshSession()` catches 404 → `handleSessionVanished()` resets state and raises flag |
| `docs/privacy.html` | Replaced "email us to request deletion" with "Account → Delete Account in-app" |
| `docs/support.html` | Updated delete-account FAQ with in-app steps |
| `docs_md/pre-launch-checklist.md` | Added "In-App Account Deletion" section with 6 checklist items |

---

## Architecture

```
AccountSheet (WelcomeView footer / SessionView toolbar)
  └─ authService.deleteAccount()
       ├─ DELETE /api/v1/users/me  (Bearer token)
       │    ├─ delete_account(user_id)
       │    │    ├─ admin_client.rpc("delete_user_data", ...)  ← atomic DB cleanup
       │    │    └─ admin_client.auth.admin.delete_user(id)    ← remove from auth.users
       │    └─ returns 204
       └─ authService.signOut()  ← clears local JWT immediately
```

**Host deletion → guest UX:**
```
Host deletes account
  └─ delete_user_data RPC deletes sessions table row
       └─ Supabase Realtime fires DELETE on sessions channel
            └─ RealtimeService.handleChange("sessions")
                 └─ SessionCoordinator.refreshSession()
                      └─ GET /sessions/current → 404
                           └─ handleSessionVanished()
                                ├─ clears all session state
                                └─ sets hostEndedSession = true
                                     └─ WelcomeView shows toast:
                                        "The host has ended this session."
```

---

## Deferred (Phase 2)

- **Sign in with Apple token revocation**: Apple's `/auth/revoke` endpoint requires fetching the provider refresh token from `auth.identities` via the admin API and constructing a signed JWT using the `.p8` key. The current implementation (Phase 1) shows an in-app note directing Apple users to revoke access via iOS Settings. This is acceptable for initial App Store submission.

---

## Production Setup Required

Before shipping, configure in Railway:

```
SUPABASE_SERVICE_ROLE_KEY=<service-role-key-from-supabase-dashboard>
```

And apply the migration to production Supabase:

```bash
supabase db push
```
