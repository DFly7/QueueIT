# Xcode Setup: Keys & Config

After implementing the `.xcconfig` + Info.plist strategy, you must complete these steps in Xcode for the app to work.

---

## 1. Assign the xcconfig Files to Build Configurations

If you skip this step, your Info.plist will literally contain the string `$(BACKEND_URL)` instead of the actual URL, causing the app to crash on launch.

1. In the **Project Navigator**, click the **blue project icon** (QueueIT).
2. Select the **Info** tab.
3. Under **Configurations**, expand **Debug** and **Release**.
4. For each configuration, click the dropdown and select the corresponding `.xcconfig` file:
   - **Debug** → `Config-Debug`
   - **Release** → `Config-Release`
5. Do this for **every target** (QueueIT, QueueITClip, and their test targets) so variables propagate correctly.

---

## 2. Add Your Production Values to Config-Release.xcconfig

Edit `Config-Release.xcconfig` and replace placeholders with your production values:

- **BACKEND_URL** – Your production backend URL (e.g. `https:/$()/api.queueit.app`)
- **SUPABASE_URL** – Your production Supabase URL
- **SUPABASE_ANON_KEY** – Your rotated Supabase anon key (rotate in Supabase dashboard first)

**Note:** Use `https:/$()/` to escape double slashes in `.xcconfig` (otherwise `//` is treated as a comment).

---

## 3. Build and Test

1. Build the **QueueIT** scheme (Cmd+B).
2. Build the **QueueITClip** scheme.
3. Run on simulator or device to confirm auth and API calls work.
