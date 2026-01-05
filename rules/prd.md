# Product Requirements Document (PRD)
## SanityApp – Day Mood Log

---

## 1. Overview

### 1.1 Product Name
**SanityApp – Day Mood Log**

### 1.2 Purpose
SanityApp is a minimalist iOS app for **personal daily mood tracking**, with a strong emphasis on **clean UI, calm visual language, and long-term overview**.

Once per day, within a defined evening time window, the user logs their mood and (optionally) a short note. Each entry is visualized as a color-coded day inside a **year-based calendar overview**, allowing reflection over months and years.

The app is intentionally limited in scope. No additional functionality is to be implemented unless explicitly requested.

---

## 2. Scope & Guiding Principles

### 2.1 Scope
- Single-user
- Local-only data storage
- Offline-first
- Mood logging + optional note
- Calendar-based visualization
- UI quality has higher priority than feature breadth

### 2.2 Supported Years
- Starts with **2026**
- Automatically rolls into subsequent years
- Supported until **2030**
- Year range must be **configurable in code** for future extension

CHANGED: In December (device timezone), the Calendar also shows the next year as a preview.

---

## 3. Platform & Technical Constraints

| Item | Requirement |
|----|----|
| Platform | iOS |
| Minimum iOS Version | iOS 16 | CHANGED: bumped minimum iOS version
| Devices | iPhone only |
| Orientation | Supports rotation | CHANGED: no longer portrait-locked
| Network | Works offline and online |
| Login | None |

---

## 4. Daily Question

### 4.1 Question Text
**“How has your day been? Log your daily mood”**

- Text is fixed in the UI
- Must be editable from the developer side (config/code)
- Not editable by the user
- English only

CHANGED: The daily entry UI uses a calm pastel background with gentle color flow (slightly stronger saturation).

CHANGED: The app title header supports an icon option that combines an academic symbol with a mood symbol (slightly larger in-app title icon).

CHANGED: The provided app icon is used as the iOS app icon and as the in-app title icon.

CHANGED: When the app is used in late 2025, the Calendar shows a December 2025 preview before the supported years start.

CHANGED: The note keyboard can be dismissed via a Done button and by tapping outside the text field.

---

## 5. Mood Answer Model

### 5.1 Mood Scale
Five discrete mood options, shown as **color + label**:

| Index | Label |
|----|----|
| 1 | Very bad |
| 2 | Bad |
| 3 | Okay |
| 4 | Good |
| 5 | Very good |

### 5.2 Color System
- Gradient-based scale (negative → neutral → positive)
- Final colors are **not taken from the mockups**
- Palette must be:
  - Calm
  - Visually pleasing
  - Color-blind–friendly (for answer options)

### 5.3 Selection Rules
- Exactly one mood must be selected
- Single-select only
- Once saved, the mood **cannot be changed**

CHANGED: The Daily Entry screen includes an additional question: “How stressed did you feel today? (0–10)” (0 = Not at all stressed, 10 = Extremely stressed). The stress value is selected via a left-to-right slider.

CHANGED: Exactly one stress value (0–10) must be selected and, once saved, it cannot be changed.

CHANGED: If the user attempts to change a saved answer for today, the UI shows a dismissible gray notice with a clickable "here" link that explicitly reverts (deletes) today’s saved answer so the user can answer again.

### 5.4 Selection Feedback (UI Requirement)
- When one mood is selected:
  - Selected option remains fully opaque/saturated
  - All other options fade (reduced alpha or saturation)
- Visual clarity of the chosen option is essential

---

## 6. Optional Daily Note

- After selecting a mood, the user may add a **short optional note**
- Maximum length: **500 words**
- Notes are stored as plain text
- Notes are included in all exports

---

## 7. Time & Availability Logic

### 7.1 Daily Answer Window
- Answering allowed from **6:00 PM to 11:59 PM**
- Timezone: **device’s current timezone**
- Automatically adapts when the user travels

### 7.2 Behavior Outside the Window

#### Before 6:00 PM
- Mood options disabled
- Show a small informational pop-up:
  > “There is still some time until you can answer 😉”

CHANGED: Answering attempts before 6:00 PM are blocked in the UI (mood selection and save), and the informational pop-up is shown when the user tries to interact.

#### After 11:59 PM
- Day is locked for standard answering
- If unanswered, it enters “missed” state

CHANGED: Answering attempts after 11:59 PM are blocked in the UI (mood selection and save), and the user sees an “Answering is closed for today.” notice.

CHANGED: A debug-only Settings screen can override the effective timezone for testing (off by default). The product rule remains device timezone.

---

## 8. Missed Day Logic

- Missed days can be filled **up to 48 hours** after the answering window ends
- After the 48-hour grace period:
  - Day becomes permanently locked
  - Day is displayed in **gray**
  - No mood or note can be added

---

## 9. Calendar & Results Overview (UI-Oriented)

### 9.1 Calendar Layout
- Year overview, 12 months per year
- Each month shown as a compact grid
- Day number always visible in every cell

CHANGED: Each month grid includes weekday headers (Mo, Tue, Wed, Thu, Fri, Sat, Sun).

CHANGED: Month day grids are left-aligned within their respective month panels.

- Layout must feel:
  - Light
  - Structured
  - Easy to scan

### 9.2 Day Cells
- Each cell represents one calendar day
- Day number must always be visible
- Visual states:
  - Mood color → answered
  - Gray → missed & locked
  - Neutral/white → future day

### 9.3 Interaction
- The app opens on a **Daily Entry** screen (question + mood options + optional note). | CHANGED: new primary home screen
- After saving, the user navigates to the **Calendar overview** (and can also open it via a calendar button). | CHANGED: new navigation flow
- Calendar day cells for answered days are highlighted with the respective mood color. | CHANGED: explicit highlight behavior

---

## 10. Notifications

### 10.1 Notification Policy
- Notifications are required for reminders
- Reminders are **on/off only**

CHANGED: Reminders can be enabled/disabled from a Settings screen, which requests permission when enabling.

### 10.2 Schedule
- Two local notifications per day:
  - **6:00 PM**
  - **11:30 PM**
- Notifications adapt automatically to current timezone

CHANGED: Turning reminders on schedules the two daily notifications; turning reminders off cancels them.

---

## 11. Data Storage & Export

### 11.1 Storage
- Local-only storage
- No cloud sync
- No external APIs

CHANGED: The Calendar screen includes export actions to share/download the saved mood data.

CHANGED: Supported export formats include CSV and JSON.

CHANGED: Export includes an additional stress value field/column (`stress_value`, 0–10).

CHANGED: Export uses the system file exporter so files can be saved/shared reliably from the simulator/device.

### 11.2 Data Model (Conceptual)

