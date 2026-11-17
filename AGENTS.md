# AI エージェント向けの手順（Claude Code・Codex など）

このリポジトリを渡されて「セットアップして」「入れて」と言われたら、下の順で**最後まで**進めてください。
最後に必ず、使い方の説明（`docs/USAGE.md`）を利用者に見せて終わります。
（English summary: run `./install.sh`, ask the user to grant Screen Recording / Microphone / Accessibility to Hammerspoon in System Settings, run `./doctor.sh` until no ✗, then show the user the contents of `docs/USAGE.md` in their language.）

## これは何か
macOS の画面の端に「作業録画」のボタン（サイドノッチ）を出す道具です。利用者が手作業を声つきで録画すると、この Mac の中に貯まり、文字起こしとコマ一覧が自動で作られます。あとで AI（スキル `work-recorder`）がそれを読んで、繰り返せる作業（スキル）にします。
部品: Hammerspoon（ボタン）・macOS 標準の screencapture（録画）・ffmpeg（声と縮め）・Python の faster-whisper（文字起こし）。

## セットアップの手順
1. **確かめる**: macOS であること。`brew` が無ければ、利用者に https://brew.sh の1行をターミナルで流してもらう（パスワードが要るので AI は流さない）。終わったら次へ。
2. **入れる**: このリポジトリのフォルダで `./install.sh` を流す（数分。文字起こしを入れたくないと言われたら `--no-transcribe`）。何度流しても安全。
   - 既にある `~/.hammerspoon/init.lua` は消さず、印（`-- >>> work-recorder >>>`）の間だけを書き足す・書き換える。
   - スキルを `~/.claude/skills/work-recorder/` と（`~/.codex` があれば）`~/.codex/skills/work-recorder/` に入れる。
3. **権限を入れてもらう**: AI はシステム設定を変えられないので、利用者に頼む。システム設定 > プライバシーとセキュリティ で「Hammerspoon」を入にする:
   - **画面収録**（必須。macOS によっては「画面とシステムオーディオの録音」）。入にしたら Hammerspoon を一度終了して開き直す。
   - **マイク**（声つきで録るなら。初めて声ありで録ると聞かれる）
   - **アクセシビリティ**（任意。窓の名前を記録する）
   利用者が「入れた」と言うまで待つ。
4. **点検する**: `./doctor.sh` を流す。× があれば、出てきた直し方に沿って直し（利用者の操作が要るものは頼む）、× が無くなるまで繰り返す。Hammerspoon に問い合わせできないときは、Hammerspoon を終了して開き直してもらう。
5. **試す（任意だが勧める）**: 利用者に、画面の右端にマウスを寄せて切り欠きが出るか、● 録画 → 数秒 → もう一度押す、を試してもらう。`python3 scripts/rec.py list` に1本出て、1〜2分で `prep/MANIFEST.md` ができれば成功。
6. **使い方を見せて終わる**: `docs/USAGE.md` の中身を、利用者の言葉（日本語なら日本語）でそのまま見せる。要約で短くしすぎない。最後に「録画を撮ったら『作業録画を見て』と言ってください」と一言添える。

## 守ること
- システム設定・セキュリティの設定は利用者が変える（AI は設定画面を開くところまで）。
- 録画ファイルを外のサービスへ送らない。消さない。
- 失敗したら、隠さずに出力のどこで止まったかを伝え、`./doctor.sh` で直す所を出す。

## 録画が撮られたあと
スキル `work-recorder`（`skill/SKILL.md`）の手順で、録画を読み、手順を書き起こし、どの作業にするかを提案して、スキルにします。
