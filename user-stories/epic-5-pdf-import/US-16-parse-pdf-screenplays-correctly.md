# US-16 — Parse PDF screenplays correctly

**Epic:** PDF Import

## User Story
As an actor, I want to import a PDF screenplay and have the app correctly identify characters and dialogue, so that I can practice from industry-standard shooting scripts without manually reformatting them.

## Background / Root Cause Analysis

The current PDF path calls `PDFDocument.string`, which extracts text in **PDF content-stream order** — not visual/spatial order. For screenplay PDFs this causes three compounding failures:

1. **Scrambled reading order** — dialogue text extracts *before* the character name that owns it, because centered character headings and left-indented dialogue are in separate positioned text blocks in the PDF. The parser then cannot associate lines with speakers.

2. **Lost indentation** — `PDFDocument.string` strips leading spaces, so the column position that distinguishes character name (center) from dialogue (left-center) from action (left) is gone entirely.

3. **Noise lines** — page headers (`Salmon Rev. (06/19/2020)  5.`), revision marks (`*`), and scene numbers (`2A`, `2C`) are injected inline with content and trip the ALL-CAPS character-name detector.

Tested against: *Dune* Final Shooting Draft (06/19/2020).

---

## Acceptance Criteria

- Characters and their dialogue lines are correctly extracted from a standard US-format PDF screenplay
- Character names do **not** include `(CONT'D)`, `(O.S.)`, `(V.O.)` suffixes — these are stripped and the base name is used
- Page headers, revision asterisks, and scene numbers are silently removed and do not appear as character names or dialogue
- Action / stage-direction lines are captured with `cueType = .direction` and do not generate false character detections
- All-caps words within action lines (e.g. `FADE IN:`, `HARVESTER`, `SPICE`) do not create phantom characters
- Scenes are split on `INT.` / `EXT.` / `INT/EXT` / `I/E` scene headings (ignoring leading scene numbers)
- Falls back gracefully to the existing FountainParser heuristic if the PDF does not appear to be a formatted screenplay

---

## Technical Approach

### Replace `PDFDocument.string` with position-aware extraction

Use `PDFPage.characterBounds(at:)` (available in iOS PDFKit since iOS 11) to read the **x/y coordinate** of each character on each page. This mirrors what `pdftotext -layout` does internally.

**Algorithm:**

```
for each page:
  1. Read page.string → get characters
  2. Read characterBounds(at: i) for each character → get (x, y)
  3. Group characters into lines by y-coordinate (within ±3pt tolerance)
  4. Sort lines top-to-bottom; within each line sort characters left-to-right
  5. For each line, record lineX = minimum x of any character on that line
  6. Strip the line if it matches a page-header pattern
  7. Strip trailing `*` revision marks
  8. Classify line by lineX using detected column thresholds (see below)
```

**Column threshold detection (dynamic, per document):**

Rather than hardcoding pixel values, scan the first 10 pages:
- Collect lineX of every ALL-CAPS line
- The modal / median lineX → `charNameX` (character name column)
- `dialogueX` ≈ `charNameX * 0.6`
- Lines with lineX < `dialogueX * 0.6` → action / scene heading

**Line classification:**

| lineX relative to thresholds | Content | CueType |
|---|---|---|
| ≥ charNameX − 10pt | ALL CAPS, not a page header | character name |
| ≥ charNameX − 10pt | starts with `(` | parenthetical (skip) |
| dialogueX … charNameX | any text | dialogue → `.spoken` |
| < dialogueX | starts with INT./EXT. | scene heading |
| < dialogueX | other text | action → `.direction` |

**Character name normalisation:**

Strip suffixes before recording the speaker:
- `(CONT'D)`, `(CONT'D.)`
- `(O.S.)`, `(V.O.)`, `(O.C.)`, `(V.O./O.S.)`

**Page header detection:**

Skip lines matching: `/ Rev\. \(\d{2}\/\d{2}\/\d{4}\)/` or bare page numbers (`/^\d+\.$/`).

---

## Files to Create / Modify

| File | Change |
|---|---|
| `ActorsCue/Parsing/PDFScreenplayParser.swift` | New — position-aware parser |
| `ActorsCue/Views/Import/ImportView.swift` | Route PDF to `PDFScreenplayParser` instead of text-extraction + `FountainParser` |

## Out of Scope

- Scanned / image-based PDFs (no text layer) — surface a clear error message
- Non-US screenplay formats (BBC format, etc.)
- Multi-column call sheets or production reports
