# Client-Side Validation Testing Guide

This guide provides comprehensive test scenarios for the newly implemented client-side validation and error handling system.

## Overview

All validation now happens client-side before API calls, with user-friendly error messages and haptic feedback (`.rigid` impact for errors).

## Testing Checklist

### ✅ Username Validation Tests

#### ProfileSetupView (Main App)

**Location:** Post-authentication profile setup screen

1. **Empty Username**
   - [ ] Clear username field
   - [ ] Tap "Continue"
   - [ ] Expected: "Username is required" error with haptic
   
2. **Too Short (< 3 characters)**
   - [ ] Enter "ab"
   - [ ] Tap "Continue"
   - [ ] Expected: "Username must be at least 3 characters" with haptic
   
3. **Too Long (> 30 characters)**
   - [ ] Enter "abcdefghijklmnopqrstuvwxyz12345"
   - [ ] Tap "Continue"
   - [ ] Expected: "Username cannot exceed 30 characters" with haptic
   
4. **Invalid Characters - Spaces**
   - [ ] Enter "john doe"
   - [ ] Tap "Continue"
   - [ ] Expected: "Username can only contain letters, numbers, dashes, and underscores" with haptic
   
5. **Invalid Characters - Special Characters**
   - [ ] Enter "user@123"
   - [ ] Tap "Continue"
   - [ ] Expected: "Username can only contain letters, numbers, dashes, and underscores" with haptic
   
6. **Valid Username**
   - [ ] Enter "john_doe_123"
   - [ ] Tap "Continue"
   - [ ] Expected: API call proceeds, no validation error
   
7. **Edge Case - Leading/Trailing Spaces**
   - [ ] Enter "  username  "
   - [ ] Tap "Continue"
   - [ ] Expected: Should be trimmed and validated (passes if 3+ chars after trim)

8. **Visual Feedback**
   - [ ] Verify text field border turns red when validation error appears
   - [ ] Verify error message appears with icon
   - [ ] Verify error clears when user starts typing again

#### GuestNamePromptView (App Clip)

**Location:** First-time App Clip guest name prompt

1. **Empty Name**
   - [ ] Clear the name field
   - [ ] Tap "Let's Go!"
   - [ ] Expected: Button should be disabled (no API call)
   
2. **Too Short**
   - [ ] Enter "ab"
   - [ ] Tap "Let's Go!"
   - [ ] Expected: "Username must be at least 3 characters" with haptic
   
3. **Too Long**
   - [ ] Enter 31+ character name
   - [ ] Tap "Let's Go!"
   - [ ] Expected: "Username cannot exceed 30 characters" with haptic
   
4. **Invalid Characters**
   - [ ] Enter "Guest@123"
   - [ ] Tap "Let's Go!"
   - [ ] Expected: "Username can only contain letters, numbers, dashes, and underscores" with haptic
   
5. **Valid Guest Name**
   - [ ] Use default "Neon Giraffe" or similar
   - [ ] Tap "Let's Go!"
   - [ ] Expected: Name accepted, proceeds to session
   
6. **Random Name Generation**
   - [ ] Tap "Give me a random name" multiple times
   - [ ] Expected: All generated names should be valid (pass validation)

### ✅ Join Code Validation Tests

#### CreateSessionView (Session Creation)

**Location:** Create new session screen

1. **Empty Join Code**
   - [ ] Leave join code empty
   - [ ] Expected: "Create Session" button disabled
   
2. **Too Short (< 4 characters)**
   - [ ] Enter "abc"
   - [ ] Tap "Create Session"
   - [ ] Expected: "Join code must be at least 4 characters" with haptic
   
3. **Too Long (> 20 characters)**
   - [ ] Enter "abcdefghijklmnopqrstuvwxyz"
   - [ ] Tap "Create Session"
   - [ ] Expected: "Join code cannot exceed 20 characters" with haptic
   
4. **Invalid Characters - Special Characters**
   - [ ] Enter "PARTY@2024"
   - [ ] Tap "Create Session"
   - [ ] Expected: "Join code can only contain letters and numbers" with haptic
   
5. **Invalid Characters - Spaces**
   - [ ] Enter "PARTY HOME"
   - [ ] Tap "Create Session"
   - [ ] Expected: "Join code can only contain letters and numbers" with haptic
   
6. **Valid Join Code**
   - [ ] Enter "PARTY2024"
   - [ ] Tap "Create Session"
   - [ ] Expected: API call proceeds
   
7. **Duplicate Join Code (Backend Error)**
   - [ ] Create session with code "TEST123"
   - [ ] Leave session
   - [ ] Try to create another session with "TEST123"
   - [ ] Expected: "This join code is already taken. Try another!" (friendly backend error)
   
8. **Visual Feedback**
   - [ ] Verify border color changes when join code is valid
   - [ ] Verify border turns red on validation error
   - [ ] Verify error message appears inline

#### JoinSessionView (Session Joining)

**Location:** Join existing session screen

1. **Empty Join Code**
   - [ ] Leave join code empty
   - [ ] Expected: "Join Session" button disabled
   
2. **Too Short**
   - [ ] Enter "xyz"
   - [ ] Tap "Join Session"
   - [ ] Expected: "Join code must be at least 4 characters" with haptic
   
3. **Too Long**
   - [ ] Enter 21+ character code
   - [ ] Tap "Join Session"
   - [ ] Expected: "Join code cannot exceed 20 characters" with haptic
   
4. **Invalid Characters**
   - [ ] Enter "CODE-2024" (hyphen not allowed)
   - [ ] Tap "Join Session"
   - [ ] Expected: "Join code can only contain letters and numbers" with haptic
   
5. **Valid But Non-Existent Session (Backend Error)**
   - [ ] Enter "FAKE1234"
   - [ ] Tap "Join Session"
   - [ ] Expected: "Couldn't find that session. Check the code and try again." (friendly 404 error)
   
6. **Valid and Existing Session**
   - [ ] Enter actual session join code
   - [ ] Tap "Join Session"
   - [ ] Expected: Successfully joins session

#### AppClipRootView (QR Code/Deep Link)

**Location:** App Clip launched via QR code or deep link

1. **Invalid Join Code from QR**
   - [ ] Create QR code with invalid format (e.g., "A@B")
   - [ ] Scan with App Clip
   - [ ] Expected: Error message shown, does not attempt to join
   
2. **Too Short Code from Deep Link**
   - [ ] Launch with URL: `queueit://join?code=ABC`
   - [ ] Expected: Validation error shown
   
3. **Valid Code from QR**
   - [ ] Scan valid session QR code
   - [ ] Expected: Auto-joins session after name prompt
   
4. **Malformed Code (Extra Spaces)**
   - [ ] Launch with URL: `queueit://join?code=%20TEST123%20`
   - [ ] Expected: Code trimmed, validation succeeds if otherwise valid

### ✅ Backend Error Parsing Tests

These test that backend errors are displayed in a user-friendly way:

1. **Username Already Taken (409)**
   - [ ] Try to set username that already exists
   - [ ] Expected: "Username already taken" (parsed from backend)
   
2. **No Music Provider (400)**
   - [ ] Try to create session without connecting music provider
   - [ ] Expected: Alert showing music provider requirement
   
3. **Anonymous User Creating Session (403)**
   - [ ] As App Clip guest, try to create session (if possible)
   - [ ] Expected: "Guest users cannot create sessions. Install the full app to host."
   
4. **Validation Error (422)**
   - [ ] Force a Pydantic validation error
   - [ ] Expected: User-friendly message (not raw JSON)
   
5. **Session Not Found (404)**
   - [ ] Join non-existent session code
   - [ ] Expected: "Couldn't find that session. Check the code and try again."

### ✅ Haptic Feedback Tests

**All error scenarios should trigger `.rigid` haptic feedback:**

1. **Username Validation Error**
   - [ ] Trigger any username validation error
   - [ ] Expected: Feel sharp haptic feedback when error appears
   
2. **Join Code Validation Error**
   - [ ] Trigger any join code validation error
   - [ ] Expected: Feel sharp haptic feedback when error appears
   
3. **Backend Error Response**
   - [ ] Trigger a backend error (e.g., duplicate join code)
   - [ ] Expected: Feel haptic feedback when error is received
   
4. **App Clip QR Code Error**
   - [ ] Scan invalid QR code
   - [ ] Expected: Feel haptic feedback when validation fails

### ✅ User Experience Flow Tests

#### Complete Username Entry Flow

1. [ ] Start profile setup
2. [ ] Enter "a" (too short)
3. [ ] Tap Continue
4. [ ] See inline error + haptic
5. [ ] Start typing "abc" 
6. [ ] Error clears as you type
7. [ ] Type "abc_user_123"
8. [ ] Tap Continue
9. [ ] Successfully proceeds

#### Complete Session Creation Flow

1. [ ] Tap "Create Session"
2. [ ] Enter "A@B" (invalid chars)
3. [ ] Tap "Create Session"
4. [ ] See inline error + haptic
5. [ ] Edit to "PARTY"
6. [ ] See "Create Session" button still disabled (too short)
7. [ ] Edit to "PARTY2024"
8. [ ] Button becomes enabled
9. [ ] Tap "Create Session"
10. [ ] If duplicate: See friendly error message
11. [ ] If success: Session created

#### Complete Session Join Flow

1. [ ] Tap "Join Session"
2. [ ] Enter "xyz" (too short)
3. [ ] Tap "Join Session"
4. [ ] See error + haptic
5. [ ] Edit to "FAKE1234"
6. [ ] Tap "Join Session"
7. [ ] See "Couldn't find that session" error
8. [ ] Edit to valid code
9. [ ] Tap "Join Session"
10. [ ] Successfully joins

### ✅ Edge Cases

1. **Rapid Typing**
   - [ ] Type invalid username quickly
   - [ ] Validation error should clear smoothly as you edit
   
2. **Copy-Paste**
   - [ ] Copy invalid text with special characters
   - [ ] Paste into username field
   - [ ] Tap Continue
   - [ ] Expected: Validation catches it
   
3. **Offline Mode**
   - [ ] Disable network
   - [ ] Try to create session with valid code
   - [ ] Expected: Network error (not validation error)
   
4. **Session Already Joined**
   - [ ] Join a session
   - [ ] Try to join the same session again
   - [ ] Expected: Backend handles this gracefully

## Implementation Summary

### Files Created
- `QueueIT/QueueIT/Utilities/ValidationUtilities.swift` - Validation logic
- `QueueIT/QueueIT/Utilities/HapticFeedback.swift` - Haptic feedback helpers

### Files Modified
1. `QueueIT/QueueIT/Views/ProfileSetupView.swift`
2. `QueueIT/QueueITClip/GuestNamePromptView.swift`
3. `QueueIT/QueueIT/Views/CreateSessionView.swift`
4. `QueueIT/QueueIT/Views/JoinSessionView.swift`
5. `QueueIT/QueueIT/Services/QueueAPIService.swift`
6. `QueueIT/QueueIT/Services/SessionCoordinator.swift`
7. `QueueIT/QueueITClip/AppClipRootView.swift`

### Validation Rules Implemented

**Username:**
- Min: 3 characters
- Max: 30 characters
- Allowed: letters, numbers, hyphens (-), underscores (_)
- Trimmed before validation

**Join Code:**
- Min: 4 characters
- Max: 20 characters
- Allowed: letters and numbers only
- Trimmed before validation

### Error Message Mapping

| Backend Status | Raw Backend Error | User-Friendly Message |
|---------------|-------------------|----------------------|
| 400 | Various validation errors | Parsed from `detail` field or "Invalid request..." |
| 401 | Unauthorized | "Session expired. Please sign in again." |
| 403 | Forbidden | "You don't have permission to do that." |
| 404 | Not Found | "Couldn't find that session. Check the code and try again." |
| 409 | Duplicate key | "This join code is already taken. Try another!" |
| 422 | Validation Error | Parsed Pydantic errors or "Invalid input format..." |
| 500 | Internal Server Error | "Server error. Please try again later." |

## Notes for Testing

- Test on a real device for haptic feedback (simulator doesn't provide haptics)
- Test with various keyboard types (physical keyboard, software keyboard)
- Test with VoiceOver enabled for accessibility
- Test in both light and dark mode (visual error indicators)
- Test with different font sizes (accessibility)

## Success Criteria

All validation tests pass with:
- ✅ Client-side validation catches errors before API calls
- ✅ User-friendly error messages (no raw JSON/HTTP errors)
- ✅ Haptic feedback on all error scenarios
- ✅ Inline error messages with icons
- ✅ Red border on invalid fields
- ✅ Error clears when user starts editing
- ✅ Button states correctly reflect validation state
