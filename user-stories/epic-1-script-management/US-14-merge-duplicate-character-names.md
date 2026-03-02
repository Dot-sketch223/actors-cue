# US-14 — Merge duplicate character names

**Epic:** Script Management

## User Story
As an actor, I want to merge two detected character names into one so that OCR variants and abbreviations (e.g. "HAMLET" and "HAMLET O.S.") are treated as a single character during practice.

## Acceptance Criteria
- In CharacterReviewView, a "Merge" action is available when two or more characters exist
- User selects exactly two character names to merge
- User chooses (or types) the canonical name to keep
- All lines attributed to either source name are reassigned to the canonical name
- The merged-away name is removed from the character list
- Merge is reflected immediately in the preview and in the saved script
