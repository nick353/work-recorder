## How to use Work Recorder

[日本語](USAGE.ja.md)

Show a manual task once -> an AI agent writes it up as steps and turns it into a reusable skill.
Things that are hard to explain in words are easy to hand over as a recording.

### 1. Record
- Move the mouse to the **right edge** of the screen. A black notch slides out (when idle it is just a thin black line).
- Click **Record**. **Talk while you work** ("I pick this one because the number is high", "skip this company because..."). Your voice is transcribed, so the AI can read *why* you did each thing.
- While recording you see a red square and the elapsed time. Click again to stop and save.
- To record without voice, hold the **option** key while clicking.
- **ctrl + option + cmd + R** also starts and stops recording.

### 2. Move the notch
- **Press and hold** the notch (or press and drag) to pick it up. Move it up/down or to the opposite edge.
- When you let go it snaps to the nearest left/right edge. The position is remembered.

### 3. Recordings pile up
- When you stop, the recording is saved on this Mac only (default `~/Movies/WorkRecorder`; change `recordings_dir` in `config.json`). Nothing is uploaded.
- In the background the video is shrunk, your speech is transcribed and contact sheets of the screen are made (longer recordings take longer). A notification appears when done.
- **Pending N** on the notch is the number of recordings waiting for the AI. Click it to open the recordings folder.

### 4. Hand it to the AI
- Tell Claude Code or Codex: "**review my work recording**" (the installed `work-recorder` skill is used; "作業録画を見て" works too).
- The AI reads the recording, writes numbered steps, and proposes "this is task X of job Y, to be run at frequency Z". It asks about decisions it could not infer.
- Once you agree, the AI turns it into a skill (a written procedure it can follow next time), compares the first run with your recording, fixes the differences, and then takes over.

### Good things to record
- Tasks that involve **judgment** are worth the most (not just clicks - the "why I chose this" part).
- Examples: how you research competitors, how you pick topics, how you assemble a weekly report, how you prepare invoices or stock sheets.
- 5-15 minutes per recording is plenty.

### Troubleshooting
- Recording is not saved -> System Settings > Privacy & Security > **Screen Recording**: enable Hammerspoon, then quit and reopen Hammerspoon.
- Health check: run `./doctor.sh` in the tool's folder; it prints what to fix.
- Remove: `./uninstall.sh` (your recordings are not deleted).
