# SanityApp – UI-First Development Plan
 
 ## 0. Guardrails (from PRD)
- **Platform**: iOS (iPhone only), iOS 16+, supports rotation
- **User model**: single-user, no login
- **Data**: local-only, offline-first, no external APIs, no cloud sync
- **Scope**: mood logging (1/day) + optional note, calendar visualization; no extras unless requested
- **Years**: starts 2026, auto-roll, supported until 2030; year range configurable in code
- **Status**: Complete
 
---
 
## 1. UI Foundations (build the look & navigation first)
- **Status**: Complete
### 1.1 App shell & navigation
- **Define app navigation structure**
  - Decide primary root: single “Year Overview” as home
  - Define how day detail is presented (push / sheet)
- **Global styling**
  - Typography scale and spacing system
  - Light visual language (calm, structured, easy to scan)
  - CHANGED: Pastel background with gentle color flow (slightly stronger)
  - CHANGED: App title header shows the new icon next to "SanityApp" (slightly larger) | Complete
  - CHANGED: App icon updated to the provided icon | Complete
  - Reusable components for cards, headers, separators
 
### 1.2 Mood design system (UI-first, logic later)
- **Mood options UI**
  - 5 discrete options: Very bad, Bad, Okay, Good, Very good
  - Option presentation: color + label
- **Selection feedback**
  - Selected option stays fully opaque/saturated
  - Non-selected options fade (reduced alpha/saturation)
- **Color palette**
  - Define calm gradient from negative → neutral → positive
  - Ensure color-blind friendliness for answer options
 
### 1.3 “Daily Question” component
- Render fixed text: “How has your day been? Log your daily mood”
- Ensure it is developer-editable (config/code), not user-editable
 
---
 
## 2. Core Screens (UI complete before wiring real persistence)
### 2.1 Year Overview (12-month calendar)
- **Layout**
  - 12 months shown on one screen
  - Each month as compact grid
  - Ensure day number always visible in each cell
  - CHANGED: Show December 2025 preview when current date is in 2025 (before 2026) | Complete
  - CHANGED: Show weekday headers above each month grid (Mo, Tue, Wed, Thu, Fri, Sat, Sun) | Complete
  - CHANGED: Month day grids are left-aligned within each month panel | Complete
- **Day cell visual states (UI placeholders first)**
  - Answered: mood color fill | Complete
  - Missed & locked: gray
  - Future day: neutral/white
- **Interaction**
  - Tapping a day opens Day Detail
  - Ensure scrolling/performance feel good (optimize later if needed)
 
### 2.2 Day Detail (read-only display + entry surface)
- **Detail copy + layout**
  - Title text: “On that day, your mood was …”
  - Show mood label
  - Show timestamp (date + time)
  - Show optional note if present
- **Entry surface (UI behavior first)**
  - Mood selector component
  - Optional note input
  - CHANGED: Keyboard can be dismissed via Done button and tapping outside the text field
  - Save action + disabled states (wire logic later)
 
### 2.3 Pre-window informational pop-up (UI)
- Implement small informational pop-up UI:
  - “There is still some time until you can answer 😉”
- Decide presentation (toast/snackbar/alert-like)
 
---
 
## 3. Data Model & Persistence (after UI scaffolding)
### 3.1 Data model (conceptual → implementation)
- **Entry fields**
  - Day identifier (date in device timezone)
  - Mood (1–5)
  - Created timestamp (date + time)
  - Optional note (plain text, max 500 words)
- **Constraints**
  - Exactly one mood selected
  - Once saved, mood cannot be changed | Complete
  - CHANGED: Provide an explicit in-notice "here" affordance that reverts (deletes) today’s saved answer if it was a mistake | Complete
 
### 3.2 Local storage
- Choose persistence mechanism (e.g., Core Data / file / SQLite)
- Implement CRUD primitives needed by UI:
  - Fetch year entries (bulk)
  - Fetch single day entry
  - Create entry for day
  - Enforce immutability after save
 
### 3.3 UI wiring
- Replace UI placeholder states with real derived state from persisted entries
- Ensure calendar updates immediately after save
 
---
 
## 4. Time & Availability Logic (wire rules into the UI)
### 4.1 Answer window
- Allow answering only between 18:00 and 23:59 (device timezone)
- Ensure behavior adapts when timezone changes (travel)
 
### 4.2 Behavior before 18:00
- Disable mood options
- Show informational pop-up when user attempts interaction
 
### 4.3 Behavior after 23:59
- Lock standard answering
- If unanswered, mark as “missed” state
 
### 4.4 Missed-day grace period
- Allow filling missed days up to 48 hours after window end
- After grace period:
  - Permanently locked
  - Display gray in calendar
  - Disallow mood/note
 
---
 
## 5. Year Range Support
- Implement year range configuration in code
- Default supported range:
  - Start: 2026
  - End: 2030
- Ensure Year Overview can switch/scroll across supported years
 
---
 
## 6. Notifications (local reminders)
### 6.1 Permission & settings
- Add reminders setting: on/off only
- Request notification permission at appropriate moment
 
### 6.2 Scheduling
- Schedule two local notifications per day:
  - 18:00
  - 23:30
- Ensure schedules adapt to timezone changes
- Ensure toggling reminders on/off updates scheduled notifications
 
---
 
## 7. Data Export
- Export includes:
  - Date
  - Mood label/value
  - Timestamp
  - Optional note
- Ensure export works offline and does not require external APIs

CHANGED: Provide export actions for CSV and JSON from the Calendar screen. | Complete

CHANGED: Export uses the system file exporter to save/share files reliably. | Complete

- **Status**: In Progress
 
---
 
## 8. QA & Polish Checklist (UI quality priority)
### 8.1 UX/UI polish
- Verify calm palette and legibility
- Verify selection feedback clarity (fade others)
- Verify day numbers always readable in all cell states
- Verify spacing/alignment across months for easy scanning
- CHANGED: Verify CSV/JSON export actions create shareable files and contain expected rows
 
### 8.2 Rule correctness
- Test edge times:
  - 17:59 → locked + pop-up
  - 18:00 → enabled
  - 23:59 → still enabled
  - 00:00 → locked/missed behavior
- Test 48-hour grace boundary
- Test timezone travel scenario (simulate timezone change)
 
### 8.3 Data integrity
- Ensure one entry per day
- Ensure saved mood is immutable
- Ensure note word limit enforced
 
### 8.4 Device coverage
- Verify iOS 16 compatibility | CHANGED: minimum iOS version bumped to 16
- Verify common iPhone screen sizes
- Verify portrait + landscape rotation behavior | CHANGED: supports rotation
