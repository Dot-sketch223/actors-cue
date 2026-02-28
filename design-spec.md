# Actor's Cue — iPhone App Design Spec

## Overview

**Purpose:** Help actors memorize lines by playing through a script, speaking other characters' lines aloud (or displaying them), and cueing the user to deliver their own lines at the right moment.

---

## Core Concepts

- **Script** — An imported play or scene, broken into lines attributed to characters
- **Role** — The character(s) the user is learning
- **Run** — A single playthrough session of a script or scene
- **Cue** — The moment the app stops and waits for the user to speak their line

---

## Data Model

```
Script
  ├── title: String
  ├── scenes: [Scene]
  └── characters: [String]

Scene
  ├── title: String
  └── lines: [Line]

Line
  ├── character: String
  ├── text: String
  ├── stage_directions: String?   // italicized, non-spoken
  └── cue_type: spoken | direction | song

UserRole
  ├── script_id: UUID
  └── characters: [String]       // user can play multiple parts
```

---

## Script Import

**Supported formats (in priority order):**
1. Plain text (`.txt`) — parsed by `CHARACTER NAME: Line text` or `CHARACTER NAME\nLine text` conventions
2. Final Draft (`.fdx`) — XML-based industry standard
3. PDF — OCR + heuristic parsing, with manual correction UI
4. Fountain (`.fountain`) — open screenwriting format
5. Manual entry — type lines directly in-app

**Import flow:**
1. Pick file from Files app / share sheet
2. App parses and displays detected characters
3. User confirms or corrects character names (merge duplicates, fix OCR errors)
4. User selects which character(s) they are playing
5. Script saved locally; optionally synced via iCloud

---

## Practice Modes

### 1. Full Run
- App displays/speaks all other characters' lines in sequence
- When the user's line is next, a **cue card** slides up showing:
  - The preceding line (context)
  - A `[ Speak your line ]` prompt
- User speaks — app listens via microphone and auto-advances when speech is detected
- Optional: show the user's line text (for early learning) or hide it (for testing)

### 2. Scene Select
- Practice a single scene or act rather than the full script

### 3. Line Drill
- Flashcard-style — shows the cue line, user speaks/recites their response
- App optionally reads the correct line aloud after the attempt (for self-check)

### 4. Stumble Mode
- Full run, but user can tap a **"Forgot it"** button
- App reveals the line, marks it as a weak point, and adds it to a drill queue

---

## Cue Delivery (Other Characters' Lines)

Two sub-modes:

| Mode | Behavior |
|---|---|
| **Read aloud** | App uses text-to-speech (configurable voice/speed per character) |
| **Display only** | Lines shown on screen; user taps to advance |
| **Hybrid** | TTS for other characters, silent cue card for user's lines |

- Each character can be assigned a distinct TTS voice
- Speed control: 0.5× to 2× playback
- Tap to pause/resume at any point

---

## Listening & Auto-Advance

- Uses on-device speech recognition (Apple's `SFSpeechRecognizer`)
- Three sensitivity settings:
  - **Any speech detected** — advances immediately when mic picks up voice
  - **Phrase match** — loosely compares spoken words to expected line (fuzzy match)
  - **Manual tap** — user taps to advance after speaking (no mic required)
- Visual indicator shows mic is active
- Timeout: if no speech after N seconds, app can auto-advance or wait (user preference)

---

## Progress & Analytics

Per script, track:
- Lines attempted vs. lines known (based on stumble/phrase-match data)
- Heatmap of which lines are consistently missed
- Run history with timestamps
- "Confidence score" per line (rolling average of match quality)

---

## UI Structure

```
Tab Bar
├── Scripts         — library of imported scripts
├── Practice        — start/resume a run (context-aware to last script)
├── Drill           — flashcard queue of weak lines
└── Progress        — stats and run history
```

**Key Screens:**

- **Script Library** — cards with title, character playing, last practiced date
- **Script Setup** — scene/character/mode selector before a run
- **Run Screen** — full-screen, minimal UI; line display, mic indicator, pause button
- **Cue Card** — modal overlay with preceding line + user's prompt
- **Post-Run Summary** — lines stumbled, time elapsed, confidence delta

---

## Settings

- Default practice mode
- TTS voice and speed (global + per-character override)
- Mic sensitivity
- Show/hide user's line during Full Run (toggle: "training wheels")
- Auto-advance timeout (3s / 5s / 10s / never)
- iCloud sync on/off
- Font size for line display

---

## Technical Stack (Recommended)

| Concern | Technology |
|---|---|
| UI | SwiftUI |
| State management | `@Observable` + SwiftData |
| Text-to-speech | `AVSpeechSynthesizer` |
| Speech recognition | `SFSpeechRecognizer` (on-device) |
| PDF parsing | `PDFKit` + Vision OCR |
| File import | `UIDocumentPickerViewController` |
| Sync | CloudKit / iCloud Documents |
| Audio session | `AVAudioSession` |

All processing on-device — no server required.

---

## MVP Scope (v1.0)

For a first release, prioritize:

1. Plain text + Fountain import
2. Character assignment
3. Full Run mode (display-only cue delivery + any-speech auto-advance)
4. Show/hide user line toggle
5. Basic stumble tracking
6. iCloud sync

Defer to v1.x: phrase matching, per-character TTS voices, PDF OCR, Line Drill mode, analytics heatmap.

---

## Open Questions to Resolve Before Implementation

1. Should the app support **songs/musical numbers** (lyrics + timing)?
2. Multi-user — should a single device support multiple actor profiles?
3. Should scripts be shareable between users (e.g., a director distributes a script to the cast)?
4. Is offline-first a hard requirement, or is a cloud backend acceptable?
5. Monetization model — one-time purchase, subscription, or free with IAP for features?
