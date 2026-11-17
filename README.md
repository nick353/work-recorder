# Work Recorder（作業録画）

手作業を**声つきで画面録画**して、AI（Claude Code・Codex など）に渡し、毎日の仕事（スキル）にするための macOS の道具です。
言葉で説明すると AI の理解がずれやすい作業を、録画でそのまま渡せます。

- 画面の端に黒い切り欠き（サイドノッチ）が貼りつき、マウスを寄せると「● 録画」が出てきます。
- 長押しでつまんで上下・左右に運べ、離すと近い方の端へ吸い寄せられます。
- 録画はこの Mac の中だけに貯まり、話し声の文字起こしと画面のコマ一覧が自動で作られます。
- AI に「作業録画を見て」と言うと、手順を書き起こして、どの作業にするか提案し、スキルにします。

## いちばん簡単な入れ方（AI に任せる）
このリポジトリを手元に置き、Claude Code か Codex をこのフォルダで開いて、こう頼むだけです。

> このリポジトリをセットアップして

AI が `AGENTS.md` の手順で、入れる → 権限のお願い → 点検 → 使い方の説明、まで進めます。
（システム設定の権限のスイッチだけは、本人が入れます）

## 手で入れる
```bash
git clone <このリポジトリ> ~/work-recorder
cd ~/work-recorder
./install.sh          # 文字起こしが要らなければ --no-transcribe
```
そのあと、システム設定 > プライバシーとセキュリティ で **Hammerspoon** を入にします。
1. **画面収録**（必須。入にしたら Hammerspoon を開き直す）
2. **マイク**（声つきで録るとき）
3. **アクセシビリティ**（任意。窓の名前を記録する）

点検は `./doctor.sh`、外すのは `./uninstall.sh`（録画は消しません）。

## 使い方
[docs/USAGE.md](docs/USAGE.md) を見てください（入れ終わると install.sh も表示します）。

## 必要なもの
- macOS（Apple シリコン・Intel どちらも）
- [Homebrew](https://brew.sh)（Hammerspoon と ffmpeg を入れるのに使います）
- python3（macOS の開発ツールに入っています）

## 仕組み
| 部品 | 役目 |
|---|---|
| `hammerspoon/recorder.lua` | 端のボタン（サイドノッチ）・つまんで運ぶ・録画の開始と停止・使ったアプリとページの記録 |
| `scripts/rec-run.sh` | macOS 標準の `screencapture -v` を動かし続け、合図で止める。声は ffmpeg で別に録る |
| `scripts/ingest.sh` | 止めたあと、動画を縮めて声と合わせ、下ごしらえを呼ぶ |
| `scripts/prep.py` | コマ一覧（秒数つき）・文字起こし・`MANIFEST.md`（AI が読む入口）を作る |
| `scripts/rec.py` | 録画の台帳（未相談・相談中・スキル化済み・見送り） |
| `skill/SKILL.md` | AI が録画を読んで、スキルにするまでの手順（install.sh が Claude Code・Codex に入れる） |

録画1本の中身: `recording.mp4`・`events.jsonl`（アプリ・窓・URL の流れ）・`prep/`（MANIFEST.md・sheets・frames・transcript.txt）・`meta.json`。

## 設定（任意）
`config.json`（install.sh が `config.example.json` から作る）
```json
{ "recordings_dir": "~/Movies/作業録画", "whisper_model": "small", "language": "ja" }
```

## 知っておくこと
- 画面全体を録るので、パスワードや個人情報が写ることがあります。録画は外へ送りませんが、録るときは気をつけてください。
- 外付けの画面を横に並べていると、その側の端はマウスが通り過ぎやすいです。外付けの画面が無い側の端に置くと使いやすくなります。
- macOS の `screencapture -g`（声つき録画）は動画が壊れることがあるため、声は別に録って合わせています。

---

## English quickstart
A macOS side-notch button to screen-record your manual work with narration, so an AI agent (Claude Code, Codex) can turn it into a reusable skill.
Open this folder in Claude Code or Codex and say **"set up this repository"** — the agent follows `AGENTS.md`. Or run `./install.sh`, grant Hammerspoon *Screen Recording* (and *Microphone*, optionally *Accessibility*) in System Settings, then `./doctor.sh`. The UI text is Japanese.
