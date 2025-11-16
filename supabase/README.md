## Supabase Schema and Policies

This folder contains the Postgres schema and RLS policy scaffolding for QueueUp.

Important notes:

- The included `schema.sql` mirrors the current working model. It is provided for reference and may require reordering and constraint adjustments before execution in a fresh database.
- RLS policies in `rls_policies.sql` are scaffolds. Review and adapt to your exact requirements before enabling.

Files:

- `schema.sql`: Tables for users, sessions, queued_songs, songs, votes (as currently defined).
- `rls_policies.sql`: Suggested RLS policies to enforce access by session membership and user identity.

Recommended workflow:

1. Apply `schema.sql` (adjusting order/constraints as necessary in your environment).
2. Seed any required baseline rows (optional).
3. Enable and verify RLS policies from `rls_policies.sql`.
4. Run integration tests against the protected endpoints.
