# Work Recorder（作業録画）

[English](README.md) | 日本語

**画面の端のサイドノッチから、手作業を声つきで画面録画し、AI（Claude Code・Codex など）に渡して、繰り返せる仕事（スキル）にするための macOS の道具です。**

<!-- demo -->
<!-- docs/demo.gif を置いたら、ここに ![demo](docs/demo.gif) を足す -->

## なぜ便利か
言葉で説明すると、AI の理解はずれます。1回やって見せれば、ずれません。
画面の端のボタンを押して、声で説明しながら作業して、もう一度押すだけ。動画・話し声の文字起こし・秒数つきのコマ一覧が、この Mac の中で作られ、AI が読める形に整います。

- 画面の端に黒い切り欠き（サイドノッチ）が貼りつき、マウスを寄せると **録画** ボタンが出ます。
- 長押しでつまんで、上下や反対の端へ運べます。位置は覚えています。
- 録画も文字起こしもこの Mac の中だけ。外へは送りません。
- AI に「作業録画を見て」と言うと、手順を書き起こし、どう繰り返すか提案して、スキルにします。
- 画面の文字は Mac の言語に合わせて日本語・英語が切り替わります。

## 必要なもの
- macOS 12 以降（Apple シリコン・Intel どちらも）
- [Homebrew](https://brew.sh)（Hammerspoon と ffmpeg を入れるのに使います）
- Python 3.9 以降（macOS の開発ツールに入っています）
- 空き容量: 文字起こしに約200MB、初回に声のモデル約500MB（要らなければ `--no-transcribe`）

## 1行で入れる
```bash
git clone https://github.com/nick353/work-recorder.git ~/work-recorder && ~/work-recorder/install.sh
```
オプション: `--no-transcribe`（文字起こしなし）・`--no-skill`（AI 用スキルを入れない）・`--no-open`（設定画面を開かない）。何度流しても安全です。

AI に任せるなら、Claude Code か Codex でこのフォルダを開いて「このリポジトリをセットアップして」と頼むだけ（[AGENTS.md](AGENTS.md) の手順で進みます）。

そのあと システム設定 > プライバシーとセキュリティ で **Hammerspoon** を入にします。
1. **画面収録**（必須。入にしたら Hammerspoon を開き直す）
2. **マイク**（声つきで録るとき）
3. **アクセシビリティ**（任意。窓の名前を記録する）

点検は `./doctor.sh`。

## 使い方
[docs/USAGE.ja.md](docs/USAGE.ja.md) を見てください。短くは:
1. 画面の端にマウスを寄せる → **録画** を押す → 声で説明しながら作業 → もう一度押す（`ctrl+option+cmd+R` でも）。option を押しながらで声なし。
2. 「作業録画を保存しました」の通知を待つ。
3. AI に「**作業録画を見て**」と言う。

## 設定
`config.json`（install.sh が `config.example.json` から作ります。git には入りません）
```json
{
  "recordings_dir": "~/Movies/WorkRecorder",
  "whisper_model": "small",
  "language": "",
  "ui_language": "auto"
}
```
| 項目 | 意味 |
|---|---|
| `recordings_dir` | 録画の置き場 |
| `whisper_model` | 文字起こしのモデル（`tiny`・`base`・`small`・`medium`・`large-v3`） |
| `language` | 話す言語（`ja`・`en`）。空なら自動判定 |
| `ui_language` | `ja`・`en`・`auto`（Mac の言語に合わせる） |

書き換えたら、Hammerspoon のメニュー（Reload Config）で読み直します。

## 消し方
`./uninstall.sh`（Hammerspoon の設定の数行と入れたスキルを外します。**録画は消しません**）。Hammerspoon と ffmpeg は残ります（`brew uninstall --cask hammerspoon`・`brew uninstall ffmpeg`）。

## 仕組み
| 部品 | 役目 |
|---|---|
| `hammerspoon/recorder.lua` | 端のノッチ・つまんで運ぶ・録画の開始と停止・2秒ごとの前面のアプリ／窓／Chrome の URL の記録 |
| `scripts/rec-run.sh` | macOS 標準の `screencapture -v` を合図まで動かし続ける。声は ffmpeg で別に録る |
| `scripts/ingest.sh` | 止めたあと、動画を縮めて声と合わせ、下ごしらえを呼ぶ |
| `scripts/prep.py` | 秒数つきのコマ一覧・文字起こし・`MANIFEST.md`（AI が読む入口）を作る |
| `scripts/rec.py` | 録画の台帳（未相談・相談中・スキル化済み・見送り） |
| `skill/SKILL.md` | AI が録画を読んでスキルにするまでの手順（Claude Code・Codex に入れる） |

録画1本の中身: `recording.mp4`・`events.jsonl`・`prep/`（MANIFEST.md・sheets・frames・transcript.txt）・`meta.json`。

## プライバシー
- 画面全体を録るので、パスワードや個人情報が写ることがあります。**録画はこの Mac の中だけ**に置き、この道具は通信しません。文字起こしもこの Mac の中で動きます（初回だけ声のモデルを Hugging Face から取ってきます）。
- 録画を Claude Code・Codex などクラウドの AI に読ませると、読んだコマや文字は、その道具によってそのサービスへ送られます。録るときに気をつけてください。
- 録画中は、前面のアプリ・窓の名前・Chrome のページ URL を `events.jsonl` に記録します。

## 知っておくこと
- 外付けの画面を横に並べていると、その側の端はマウスが通り過ぎやすいです。隣の画面が無い側の端に置くと使いやすくなります。
- macOS の `screencapture -g`（音つき録画）は動画が壊れることがあるため、声は別に録って合わせています。
- `meta.json` の状態は日本語の語（`未相談`・`相談中`・`スキル化済み`・`見送り`）で保存します。`rec.py set` では英語（pending・consulting・done・skipped）も使えます。

## ライセンス
[MIT](LICENSE)
