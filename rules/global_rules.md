# Global Rules – SanityApp (AI Agent Guardrails)

These rules define **hard constraints** for any AI agent operating in this repository.
They apply to **all files, all tools, and all actions** unless explicitly overridden by the user in writing.

If there is any conflict between these rules and another instruction, **these rules take precedence**.

---

## 1. Source Control & Safety

### 1.1 Never Commit Without Explicit Instruction
- **Do NOT run**:
  - `git commit`
  - `git push`
  - create or merge pull requests
- **Never commit changes automatically**
- Only commit when the user explicitly says:
  - “commit this”
  - “you may commit”
  - or equivalent wording

You may:
- modify files locally
- show diffs
- suggest commit messages

But **no commits or pushes without permission**.

---

### 1.2 No Implicit Account or Remote Changes
Do **not** create, modify, or delete:
- Apple Developer resources
- App Store Connect entries
- Certificates or provisioning profiles
- Bundle identifiers
- iCloud containers or entitlements

You may **explain steps**, but never assume access or permission.

---

### 1.3 No Destructive Actions Without Confirmation
Do not execute or suggest destructive commands by default, including:
- `rm -rf`
- mass file deletions
- git history rewrites
- deleting certificates or keychain items

If relevant, you may **suggest** such actions clearly labeled as *optional*, but never perform them automatically.

---

## 2. Make Every Step Testable (Mandatory)

### 2.1 Work in Small, Verifiable Steps
- Changes must be incremental and testable in isolation
- Avoid large or opaque refactors

Every step must include:
1. **What changed**
2. **Why it changed**
3. **How to test it**
4. **Expected result**
5. **What could fail + how to debug**

---

### 2.2 Always Tell the User What to Test
For every change, explicitly describe:
- which screen to open
- which simulator or device to use
- which user actions to perform
- which edge cases to try
- what confirms success

Never assume the user knows how to test your changes.

---

### 2.3 No Big-Bang Changes
- Do not introduce large refactors in a single step
- Split complex changes into multiple testable steps
- The project must **compile and run** after every step

---

## 3. Product Scope Guardrails

### 3.1 No Feature Creep
Do **not** implement anything unless it is:
- explicitly defined in `prd.md`, or
- explicitly requested by the user

In particular, do NOT add:
- analytics, tracking, telemetry
- streaks, scores, gamification
- statistics or charts beyond the calendar view
- social features or sharing
- accounts, login, sync
- additional questions or prompts
- AI summaries, insights, or recommendations

If something seems useful:
- suggest it
- wait for explicit approval

---

### 3.2 Follow Time & Logic Rules Exactly
All time-based logic must follow the PRD exactly:
- Daily answer window: **6:00 PM – 11:59 PM (device timezone)**
- Before 6 PM: answering disabled + informational message
- After 11:59 PM: standard answering locked
- Missed-day grace period: **48 hours**, then gray and locked

Do not reinterpret or “improve” these rules.

---

### 3.3 Mood Entries Are Immutable
- Once a mood is saved, it cannot be edited
- Optional notes are part of the same immutable entry
- Do not add edit flows unless explicitly asked

---

## 4. Engineering & Workflow Rules

### 4.1 Prefer Simple, Native Implementations
- Use standard Apple frameworks (SwiftUI, Foundation, UserNotifications)
- Avoid third-party dependencies unless explicitly approved

---

### 4.2 Keep the Project Forkable
- Years, mood labels, colors, and time windows may be configurable via constants
- Do not hardcode personal identifiers or environment-specific values

---

### 4.3 Document Assumptions
- If an assumption is required:
  - state it explicitly before implementing
  - ask for confirmation if it affects behavior

---

## 5. Communication Rules (Mandatory)

### 5.1 Plan Before Acting
Before making changes, always:
- explain the proposed approach
- list files likely to be touched
- describe how the result will be tested

Only proceed after this explanation.

---

### 5.2 Ask Before Irreversible or Structural Changes
Always ask for confirmation before:
- renaming the app
- changing bundle identifiers or display names
- modifying signing or team settings
- restructuring folders or architecture
- changing app icon assets

---

## 6. Additional Guardrails (Active)

The following rules are **mandatory**:

1. **No new dependencies without approval**
2. **No changes to signing or team settings unless asked**
3. **Always include a rollback plan**
4. **No background tasks or daemons unless required by the PRD**
5. **Code must compile at every step**
6. **Use feature flags for risky changes (off by default)**

---

## 7. Default Behavior if Unsure

If there is **any uncertainty** about:
- scope
- intent
- impact
- permissions

Then:
- stop
- explain the uncertainty
- ask the user before proceeding

Silence or ambiguity is **not consent**.

---
