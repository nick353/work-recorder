# Instructions for AI agents (Claude Code, Codex, ...)

If you are asked to "set up", "install" or "set up this repository", follow the steps below **to the end**.
Always finish by showing the user the usage guide (`docs/USAGE.md`, or `docs/USAGE.ja.md` for Japanese speakers).
Talk to the user in their language.

## What this is
A macOS tool that puts a "Record" button (a side notch) on the edge of the screen. The user records a manual task with their voice; the recording stays on the Mac and a transcript and timestamped contact sheets are prepared automatically. Later an AI (the `work-recorder` skill) reads it and turns it into a repeatable task (a skill).
Parts: Hammerspoon (the button), macOS `screencapture` (recording), ffmpeg (voice + shrinking), Python faster-whisper (transcription).

## Setup steps
1. **Check**: it must be macOS. If `brew` is missing, ask the user to run the one-liner from https://brew.sh in Terminal (it needs their password, so do not run it yourself). Continue once done.
2. **Install**: run `./install.sh` in this folder (takes a few minutes; add `--no-transcribe` if the user does not want speech-to-text). It is safe to re-run.
   - It never deletes an existing `~/.hammerspoon/init.lua`; it only adds/replaces the block between `-- >>> work-recorder >>>` and `-- <<< work-recorder <<<`.
   - It installs the skill to `~/.claude/skills/work-recorder/` and (if `~/.codex` exists) `~/.codex/skills/work-recorder/`.
3. **Permissions (the user does this)**: you cannot change System Settings. In System Settings > Privacy & Security, ask the user to turn ON "Hammerspoon" for:
   - **Screen Recording** (required; on some macOS versions called "Screen & System Audio Recording"). Afterwards quit and reopen Hammerspoon.
   - **Microphone** (for recording with voice; macOS asks the first time)
   - **Accessibility** (optional; logs window titles)
   Wait until the user says it is done.
4. **Check**: run `./doctor.sh`. Fix each NG line using the hint it prints (ask the user when it needs their action). Repeat until there are no NG lines. If Hammerspoon cannot be queried, ask the user to quit and reopen it.
5. **Try it (recommended)**: ask the user to move the mouse to the screen edge, confirm the notch appears, click Record, wait a few seconds, click again. `python3 scripts/rec.py list` should show one recording, and `prep/MANIFEST.md` should appear within 1-2 minutes.
6. **Finish by showing the usage guide**: show the contents of `docs/USAGE.md` (or `docs/USAGE.ja.md`) in the user's language. Do not over-summarize. End with: "After you record something, say 'review my work recording'."

## Rules
- The user changes System Settings / security settings; you only open the settings pane.
- Never upload recordings to any outside service. Never delete them.
- If something fails, say exactly where it stopped and run `./doctor.sh` to find what to fix.
- Do not run `hs.reload()` or restart Hammerspoon without telling the user (it interrupts a recording in progress).

## After a recording exists
Follow the `work-recorder` skill (`skill/SKILL.md`): read the recording, write the steps, propose what task it is, and turn it into a skill.
