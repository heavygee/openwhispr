## Quick Spoken Note Implementation Plan

- Add persisted settings for `quickNoteKey` and `quickNotePrompt`, with no default shortcut and a default prompt for JSON title/content output.
- Register a `quick-note` hotkey slot in the main process, expose it through preload, and emit separate quick-note recording events.
- Preserve the existing activation mode semantics: tap toggles quick-note recording, push starts on key down and stops on key up where native key listeners provide release events.
- Reuse the existing audio recording/transcription path, but route quick-note completions to note creation instead of paste/clipboard.
- Format note title/content with the existing reasoning model and fall back to raw transcript plus timestamp title on any LLM or parse failure.
- Save every capture as a new personal note in a hardcoded `Quick Notes` folder, creating the folder when missing.
- Show toast feedback after save or failure.
- Add focused unit tests for quick-note formatting/fallback behavior and run the existing quality/build gates.
