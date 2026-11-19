"""Tiny ja/en switch shared by the scripts. UI language = config.json "ui_language" ("ja"|"en"),
otherwise the Mac's first preferred language (Japanese -> ja, anything else -> en)."""
import json
import os
import re
import subprocess

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lang():
    try:
        with open(os.path.join(BASE, "config.json"), encoding="utf-8") as f:
            v = json.load(f).get("ui_language")
            if v in ("ja", "en"):
                return v
    except Exception:
        pass
    try:
        out = subprocess.run(["defaults", "read", "-g", "AppleLanguages"], capture_output=True, text=True, timeout=5).stdout
        m = re.search(r'"?([A-Za-z]{2,3})(?:[-_][A-Za-z0-9]+)*"?', out.replace("(", "").replace(")", ""))
        if m:
            return "ja" if m.group(1).lower() == "ja" else "en"
    except Exception:
        pass
    return "ja" if os.environ.get("LANG", "").lower().startswith("ja") else "en"


LANG = lang()


def t(ja, en):
    return ja if LANG == "ja" else en
