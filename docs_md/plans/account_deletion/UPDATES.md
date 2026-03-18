# Account Deletion — Post-Implementation Fixes

Issues discovered and resolved during first end-to-end test on 2026-03-18.

---

## Fix 1 — `SUPABASE_SERVICE_ROLE_KEY` not set in dev environment

**Symptom:** `DELETE /api/v1/users/me` returned 503 with `"Account deletion is not available at this time"`.

**Cause:** The endpoint guards against a missing service role key (required to use the Supabase admin client). The key was absent from the backend `.env`.

**Fix:** Add `SUPABASE_SERVICE_ROLE_KEY=<service_role_key>` to `QueueITbackend/.env`. Key is in Supabase dashboard → Project Settings → API → service_role.

---

## Fix 2 — `delete_user_data` RPC not in PostgREST schema cache

**Symptom:** `PGRST202 — Could not find the function public.delete_user_data(p_user_id) in the schema cache`.

**Cause:** The migration file `20260322_delete_user_data_rpc.sql` was never applied to the database (function was absent from `information_schema.routines`).

**Fix:** Manually ran the `CREATE OR REPLACE FUNCTION` SQL in the Supabase SQL editor, then issued `NOTIFY pgrst, 'reload schema';` to flush the PostgREST cache.

---

## Fix 3 — FK violation on `users.previous_session_id`

**Symptom:** `23503 — update or delete on table "sessions" violates foreign key constraint "users_previous_session_id_fkey"`.

**Cause:** Step 1 of the RPC only nulled `current_session` on the deleting user. The `previous_session_id` column (also an FK to `sessions`) was left populated, blocking the session delete.

**Fix:** Updated step 1 to null both columns:
```sql
UPDATE users SET current_session = NULL, previous_session_id = NULL WHERE id = p_user_id;
```

---

## Fix 4 — FK violation on `users.current_session` for other participants

**Symptom:** `23503 — update or delete on table "sessions" violates foreign key constraint "users_current_session_fkey"` — referencing a **different** session ID than the deleting user's own row.

**Cause:** Other users who were participants in the host's sessions still had `current_session` / `previous_session_id` pointing at those sessions. Deleting the sessions while those references existed violated the FK.

**Fix:** Broadened step 1 to null out references on **all users** that point to any session hosted by the deleting user:
```sql
UPDATE users
SET current_session = NULL, previous_session_id = NULL
WHERE current_session IN (SELECT id FROM sessions WHERE host_id = p_user_id)
   OR previous_session_id IN (SELECT id FROM sessions WHERE host_id = p_user_id)
   OR id = p_user_id;
```

This is the version now in `supabase/migrations/20260322_delete_user_data_rpc.sql`.

---

## Final working RPC

```sql
CREATE OR REPLACE FUNCTION public.delete_user_data(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE users
  SET current_session = NULL, previous_session_id = NULL
  WHERE current_session IN (SELECT id FROM sessions WHERE host_id = p_user_id)
     OR previous_session_id IN (SELECT id FROM sessions WHERE host_id = p_user_id)
     OR id = p_user_id;

  UPDATE sessions SET current_song = NULL WHERE host_id = p_user_id;

  DELETE FROM votes WHERE user_id = p_user_id;

  DELETE FROM votes WHERE queued_song_id IN (
    SELECT id FROM queued_songs
    WHERE added_by_id = p_user_id OR session_id IN (SELECT id FROM sessions WHERE host_id = p_user_id)
  );

  DELETE FROM queued_songs
  WHERE added_by_id = p_user_id OR session_id IN (SELECT id FROM sessions WHERE host_id = p_user_id);

  DELETE FROM sessions WHERE host_id = p_user_id;

  DELETE FROM users WHERE id = p_user_id;
END;
$$;
```
