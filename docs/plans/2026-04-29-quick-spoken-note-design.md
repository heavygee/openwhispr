# Quick Spoken Note Design

## Problem

OpenWhispr can dictate into the focused app and already has a notes system, but it lacks a zero-friction path for capturing a spoken thought directly as a note. The desired behavior is not "open notes and interact with UI"; it is "catch this thought now and let me keep working."

## Contract

When the user triggers Quick Spoken Note, OpenWhispr records using the user's existing activation behavior, transcribes the speech, formats it into a new markdown note using a configurable prompt and the existing reasoning model settings, saves it under a hardcoded `Quick Notes` folder, and confirms with a toast. If LLM formatting fails after transcription succeeds, OpenWhispr still saves the raw transcript with a timestamp fallback title.

## Requirements

### MUST

1. Provide a separate configurable Quick Spoken Note hotkey with no default value.
2. Reuse the app-wide activation mode, so tap/hold behavior stays consistent with normal dictation.
3. Reuse the currently selected transcription model for speech-to-text.
4. Reuse the existing reasoning/cleanup LLM settings for note title and markdown formatting.
5. Provide an editable Quick Note prompt in settings, with a sensible default and reset behavior.
6. Create a new note for every successful Quick Spoken Note capture.
7. Save notes under a hardcoded `Quick Notes` folder/subfolder, creating it if needed.
8. Show a non-interrupting toast after save, such as `Saved note: <title>`.
9. Never discard a successfully transcribed note solely because LLM formatting failed.

### SHOULD

1. Broadcast the existing `note-added` event so all note UI and sync paths behave normally.
2. Keep the feature independent from future routing, MCP, API, or mindmapping destinations.
3. Keep the prompt capable of adding structure, headings, tasks, tags, and inferred organization where useful.

### MAY

1. Later evolve this into a general "do this with spoken text" action pipeline.
2. Later infer destination from existing notes, folders, project context, MCP, API, or an external mindmapping system.
3. Later add custom feedback sounds, but v1 should use existing toast UX only.

## Architecture

Add a second capture destination beside normal dictation, internally something like `quickNote`. It should reuse the existing recording/transcription path and activation mode, but route the completed transcript to a note formatter and note persistence path instead of paste-at-cursor.

Settings need two new persisted fields:

- Quick Spoken Note hotkey, unset by default.
- Quick Note prompt, editable with reset-to-default.

The save path should use existing note persistence APIs where possible rather than inventing a parallel storage path.

## Data Flow

1. User triggers the Quick Spoken Note hotkey.
2. OpenWhispr records using the current activation mode.
3. Recording is transcribed using the currently selected transcription provider/model.
4. The raw transcript plus Quick Note prompt are sent through the existing reasoning/cleanup LLM configuration.
5. The formatter returns a title and markdown body.
6. OpenWhispr creates or resolves the hardcoded `Quick Notes` folder.
7. OpenWhispr saves a new note in that folder.
8. OpenWhispr broadcasts normal note update events and shows a toast.

## LLM Formatting Contract

The formatting layer should ask the model to return a parseable object with:

- `title`: short, useful note title.
- `markdownContent`: structured markdown note body.

The default prompt should allow the model to clean up dictation artifacts, add headings, extract tasks, add lightweight tags, and infer useful structure without inventing facts.

## Failure Behavior

- Transcription failure: do not create a note; use the existing recording/transcription error UX.
- LLM formatting failure: save the raw transcript as markdown with a timestamp title.
- Folder creation failure: save at root as a last resort and toast that the note was saved without the folder.
- Note save failure: show an error toast; do not pretend capture succeeded.

## UX

Add a "Quick Spoken Note" subsection in settings near the existing hotkey/transcription or notes settings. The section should include:

- Hotkey recorder.
- Prompt textarea.
- Reset prompt action.

No note editor, panel, or capture-specific UI opens during capture. The normal success feedback is a toast.

## Test Strategy

Unit tests should cover:

- Formatter response parsing.
- Formatter fallback when response is invalid or model call fails.
- Folder resolution behavior for `Quick Notes`.
- Raw transcript fallback title generation.

Integration/manual smoke should cover:

- Configure Quick Spoken Note hotkey.
- Capture one note in tap mode.
- Capture one note in hold mode.
- Confirm new notes appear under `Quick Notes`.
- Disable or break LLM configuration and confirm raw transcript fallback note is still saved.

Verification commands should include:

- `npm run quality-check`
- `npm run i18n:check`
- `npm run build:renderer`
- GitHub CI
- Windows Artifact workflow

## Out Of Scope For V1

- Automatic folder/project inference.
- Mindmapping integration.
- MCP/API routing destinations.
- Configurable destination actions.
- Custom notification sounds.
- Opening the note editor after capture.
