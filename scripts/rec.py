#!/usr/bin/env python3
"""作業録画の台帳（各録画フォルダの meta.json）を読む・書く。

  rec.py list [--all]                 未相談の録画（--all で全部）
  rec.py show <id>                    1本の中身（長さ・声・使ったアプリとページ・下ごしらえの置き場）
  rec.py set <id> <状態> [--note 文] [--task 番号] [--business 事業]
                                      状態: 未相談 / 相談中 / スキル化済み / 見送り
  rec.py finish <dir> --duration 秒   下ごしらえの終わり（ingest.sh が呼ぶ）
  rec.py pending-line                 今の状態に載せる1行（未相談が無ければ何も出さない）
"""
import argparse
import json
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from i18n import t  # noqa: E402

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _root():
    try:
        with open(os.path.join(BASE, "config.json"), encoding="utf-8") as f:
            d = json.load(f).get("recordings_dir")
            if d:
                return os.path.expanduser(d)
    except Exception:
        pass
    return os.path.expanduser("~/Movies/WorkRecorder")


ROOT = _root()
# The stored values are Japanese (they are written into each meta.json and read by recorder.lua).
# English aliases are accepted on the command line.
STATES = {"未相談", "相談中", "スキル化済み", "見送り", "録画中", "下ごしらえ中"}
ALIASES = {"pending": "未相談", "consulting": "相談中", "done": "スキル化済み", "skipped": "見送り",
           "recording": "録画中", "preparing": "下ごしらえ中"}
SHOWN = {v: k for k, v in ALIASES.items()}


def state_label(st):
    return st if t(True, False) else SHOWN.get(st, st)


def load(d):
    try:
        with open(os.path.join(d, "meta.json"), encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def save(d, meta):
    p = os.path.join(d, "meta.json")
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    os.replace(tmp, p)


def all_recs():
    if not os.path.isdir(ROOT):
        return []
    out = []
    for name in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, name)
        m = load(d) if os.path.isdir(d) else None
        if m:
            out.append((d, m))
    return out


def find(rid):
    for d, m in all_recs():
        if m.get("id") == rid or os.path.basename(d) == rid:
            return d, m
    sys.exit(t(f"録画 {rid} が見つからない（{ROOT}）", f"Recording {rid} not found ({ROOT})"))


def events(d):
    p = os.path.join(d, "events.jsonl")
    if not os.path.exists(p):
        return []
    out = []
    for line in open(p, encoding="utf-8"):
        try:
            out.append(json.loads(line))
        except Exception:
            pass
    return out


def mmss(s):
    s = int(s or 0)
    return f"{s // 60}:{s % 60:02d}"


def apps_summary(ev, n=6):
    seen = []
    for e in ev:
        a = e.get("app")
        if a and a not in seen:
            seen.append(a)
    return t("・", ", ").join(seen[:n]) + (t(f" ほか{len(seen) - n}", f" +{len(seen) - n} more") if len(seen) > n else "")


def cmd_list(a):
    rows = [(d, m) for d, m in all_recs() if a.all or m.get("status") == "未相談"]
    if not rows:
        print(t("未相談の録画はありません" if not a.all else "録画はありません", "No pending recordings" if not a.all else "No recordings"))
        return
    for d, m in rows:
        ev = events(d)
        print(f"- {m.get('id')}｜{state_label(m.get('status'))}｜{mmss(m.get('duration'))}｜{t('声あり', 'voice') if m.get('voice') else t('声なし', 'no voice')}｜{apps_summary(ev)}"
              + (f"｜{m.get('business')}" if m.get("business") else "")
              + (f"｜{t('タスク', 'task ')}{m.get('task')}" if m.get("task") else ""))


def cmd_show(a):
    d, m = find(a.id)
    ev = events(d)
    print(t(f"# 録画 {m.get('id')}（{m.get('status')}）", f"# Recording {m.get('id')} ({state_label(m.get('status'))})"))
    print(t(f"- 置き場: {d}", f"- Folder: {d}"))
    print(t("- 長さ: ", "- Length: ") + f"{mmss(m.get('duration'))} - " + (t("声あり（話した説明が文字起こしにある）", "with voice (what was said is in the transcript)") if m.get("voice") else t("声なし", "no voice")))
    for f in ("recording.mp4", "raw.mov"):
        if os.path.exists(os.path.join(d, f)):
            print(t("- 動画: ", "- Video: ") + os.path.join(d, f))
    man = os.path.join(d, "prep", "MANIFEST.md")
    print(t("- 下ごしらえ: ", "- Prepared: ") + (man if os.path.exists(man) else t("まだ（ingest.log を見る）", "not yet (see ingest.log)")))
    if m.get("note"):
        print(t("- メモ: ", "- Note: ") + str(m["note"]))
    print(t(f"\n## 使ったアプリ・窓・ページ（秒は録画の頭から。{len(ev)}件）", f"\n## Apps, windows and pages used (seconds from the start; {len(ev)} entries)"))
    for e in ev:
        line = f"- {mmss(e.get('t'))} {e.get('app')}｜{(e.get('title') or '')[:80]}"
        if e.get("url"):
            line += f"｜{e['url'][:120]}"
        print(line)


def cmd_set(a):
    a.state = ALIASES.get(a.state, a.state)
    if a.state not in STATES:
        sys.exit(t(f"状態は {sorted(STATES)} のどれか", f"state must be one of {sorted(ALIASES)} (or the Japanese values {sorted(STATES)})"))
    d, m = find(a.id)
    m["status"] = a.state
    m["updated"] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    if a.note:
        m["note"] = a.note
    if a.task:
        m["task"] = a.task
    if a.business:
        m["business"] = a.business
    save(d, m)
    print(t(f"{m['id']} を「{a.state}」にした", f"{m['id']} -> {state_label(a.state)}"))


def cmd_finish(a):
    d = a.dir
    m = load(d) or {"id": os.path.basename(d)}
    m["duration"] = a.duration
    m["status"] = "未相談"
    m["ingested"] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    save(d, m)


def cmd_pending(a):
    rows = [m for _, m in all_recs() if m.get("status") == "未相談"]
    if rows:
        print(t(f"- 未相談の作業録画 {len(rows)}本（新しい: {rows[-1].get('id')}）。会話の最初か依頼の区切りで、自分から「録画が{len(rows)}本あります。どの作業にするか相談しますか？」と出す。相談は work-recorder スキル",
                f"- {len(rows)} work recording(s) pending (newest: {rows[-1].get('id')}). At the start of a conversation or between requests, offer: \"You have {len(rows)} recording(s). Want to turn one into a skill?\" Use the work-recorder skill."))


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="cmd", required=True)
    x = s.add_parser("list"); x.add_argument("--all", action="store_true"); x.set_defaults(f=cmd_list)
    x = s.add_parser("show"); x.add_argument("id"); x.set_defaults(f=cmd_show)
    x = s.add_parser("set"); x.add_argument("id"); x.add_argument("state")
    x.add_argument("--note"); x.add_argument("--task"); x.add_argument("--business"); x.set_defaults(f=cmd_set)
    x = s.add_parser("finish"); x.add_argument("dir"); x.add_argument("--duration", type=int, default=0); x.set_defaults(f=cmd_finish)
    x = s.add_parser("pending-line"); x.set_defaults(f=cmd_pending)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
