"""OwnWords local proofreader.

Keeps a small language model loaded and answers one JSON line per request:
  in:  {"id": 1, "text": "..."}
  out: {"id": 1, "text": "...", "applied": [...], "rejected": [...]}
Prints {"ready": true} once the model is loaded. Everything runs on this Mac.

Two steps, both checked in proofread_core before they change anything:
1. Words: the model lists words it thinks were misheard (same sound, known
   English word, or an explicit self-correction).
2. Tidy: the model may remove stumbles, fix punctuation and add paragraph
   breaks, but may never add a word the speaker did not say.
The app then runs its own guard on top.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proofread_core as core  # noqa: E402

MODEL = os.environ.get("OWNWORDS_PROOFREAD_MODEL", "mlx-community/Qwen3-4B-Instruct-2507-4bit")
HERE = os.path.dirname(os.path.abspath(__file__))


def reply(payload):
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main():
    with open(os.path.join(HERE, "system-prompt.txt"), encoding="utf-8") as f:
        system = f.read()
    with open(os.path.join(HERE, "tidy-prompt.txt"), encoding="utf-8") as f:
        tidy_system = f.read()
    proofreader = core.Proofreader(MODEL, system, tidy_system)
    # Warm up both steps so the first real sentence is fast.
    proofreader.run("這是一段用來預熱的文字，讓第一句真正講的話也一樣快。")
    reply({"ready": True})

    for line in sys.stdin:
        request = {}
        try:
            request = json.loads(line)
            fixed, applied, rejected, tidied, tidy_rejected = proofreader.run(request["text"])
            reply({"id": request.get("id"), "text": fixed, "applied": applied, "tidied": tidied,
                   "tidy_rejected": tidy_rejected,
                   "rejected": [{"edit": e, "why": why} for e, why in rejected]})
        except Exception as error:  # keep serving; the app falls back to the original text
            reply({"id": request.get("id"), "error": str(error)})


if __name__ == "__main__":
    main()
