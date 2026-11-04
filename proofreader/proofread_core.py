"""Find-and-check proofreading: the model may only *point out* misheard words;
every suggested change is checked here before it touches the text."""
import json
import os
import re

from pypinyin import lazy_pinyin

ENGLISH_WORDS = [
    "Claude", "Claude Code", "Claude Chat", "CLAUDE.md", "Codex", "ChatGPT", "GPT", "Notion", "NotebookLM",
    "GitHub", "Obsidian", "Gemini", "Antigravity", "prompt", "workflow", "app", "App", "AI", "vibe coding",
    "feedback", "deadline", "spelling", "grammar", "Mac", "iPad", "iPhone", "Typeless", "Canva", "OwnWords",
]
SELF_CORRECTION = re.compile(r"不對|不是，|我是說|應該是|講錯")
HAN = re.compile(r"^[㐀-鿿]+$")

def load_glossary():
    """English words the model may restore: the built-in list plus every
    English replacement in the person's word list."""
    words = set(ENGLISH_WORDS)
    vocab = os.path.expanduser("~/Library/Application Support/OwnWords/我的詞庫.txt")
    if os.path.exists(vocab):
        for line in open(vocab, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            for sep in ("→", "=>", "->"):
                if sep in line:
                    right = line.split(sep, 1)[1].strip()
                    if re.search(r"[A-Za-z]", right):
                        words.add(right)
                    break
    return words


# Sounds that are easy to mix up, especially with a Taiwanese accent:
# zh/z, ch/c, sh/s, n/l, f/h at the start; ang/an, eng/en, ing/in at the end.
def _canon(syllable):
    for a, b in (("zh", "z"), ("ch", "c"), ("sh", "s")):
        if syllable.startswith(a):
            syllable = b + syllable[2:]
            break
    if syllable.startswith("n"):
        syllable = "l" + syllable[1:]
    elif syllable.startswith("f"):
        syllable = "h" + syllable[1:]
    for a, b in (("ang", "an"), ("eng", "en"), ("ing", "in")):
        if syllable.endswith(a):
            syllable = syllable[: -len(a)] + b
            break
    return syllable


def sounds_alike(a, b):
    pa, pb = lazy_pinyin(a), lazy_pinyin(b)
    return len(pa) == len(pb) and all(_canon(x) == _canon(y) for x, y in zip(pa, pb))


LATIN = re.compile(r"^[A-Za-z0-9 .\-]+$")


def _letters(s):
    return re.sub(r"[^a-z]", "", s.lower())


def _skeleton(s):
    """Rough sound of a word: consonants only, with easily confused ones merged."""
    s = _letters(s)
    for a, b in (("ph", "f"), ("ck", "k"), ("c", "k"), ("g", "k"), ("q", "k"), ("b", "p"), ("d", "t"), ("r", "l"), ("v", "f"), ("z", "s")):
        s = s.replace(a, b)
    return re.sub(r"[aeiouyw]", "", s)


def _close(a, b, limit):
    from difflib import SequenceMatcher
    return SequenceMatcher(None, a, b).ratio() >= limit


def _vocabulary_pairs():
    heard, written = set(), set()
    vocab = os.path.expanduser("~/Library/Application Support/OwnWords/我的詞庫.txt")
    if os.path.exists(vocab):
        for line in open(vocab, encoding="utf-8"):
            line = line.strip()
            for sep in ("→", "=>", "->"):
                if sep in line and not line.startswith("#"):
                    left, right = (x.strip() for x in line.split(sep, 1))
                    heard.add(left)
                    written.add(right)
                    break
    return heard, written


def check(edit, text, glossary):
    """Returns why an edit is rejected, or None if it may be applied."""
    src, dst, kind = edit.get("from", ""), edit.get("to", ""), edit.get("type", "")
    if not src or not dst or src == dst or src not in text or len(src) > 40:
        return "not in text"
    heard, written = _vocabulary_pairs()
    if dst in heard or src in written:
        return "undoes the word list"

    if kind == "同音":
        if not (HAN.match(src) and HAN.match(dst)):
            return "not chinese"
        return None if sounds_alike(src, dst) else "does not sound alike"

    if kind == "英文":
        lower = {g.lower(): g for g in glossary}
        if dst.lower() not in lower:
            return "not a known english word"
        if src.lower() in lower and src.lower() != dst.lower():
            return "swaps one known word for another"
        if src.lower() == dst.lower():
            return None  # only fixing capitals
        if dst.lower().startswith(src.lower()) or src.lower() in dst.lower():
            # "notebook" → "NotebookLM" is fine; "Chat" → "Claude Chat" adds a word.
            return None if len(dst) - len(src) <= 3 else "adds words"
        if LATIN.match(src):
            if len(_letters(dst)) < 0.6 * len(_letters(src)):
                return "drops words"
            # Needs some shared spelling either way, so a name like
            # "Marigold" is never turned into "Claude".
            if not _close(_letters(src), _letters(dst), 0.35):
                return "does not look alike"
            looks = _close(_letters(src), _letters(dst), 0.5)
            sounds = _close(_skeleton(src), _skeleton(dst), 0.6)
            return None if looks or sounds else "does not look or sound alike"
        if HAN.match(src) and len(src) <= 5:
            # A Chinese spelling of an English word, e.g. 麥克 → Mac.
            sound = _skeleton("".join(lazy_pinyin(src)))
            return None if _close(sound, _skeleton(dst), 0.6) else "does not sound alike"
        return "mixed text"

    if kind == "改口":
        if not SELF_CORRECTION.search(src):
            return "no correction words"
        return None if dst in src and len(dst) < len(src) else "not taken from what was said"
    return "unknown type"


def parse(output):
    match = re.search(r"\[.*\]", output, flags=re.S)
    if not match:
        return []
    try:
        edits = json.loads(match.group(0))
    except json.JSONDecodeError:
        return []
    return [e for e in edits if isinstance(e, dict)]


def apply(text, edits, glossary):
    applied, rejected = [], []
    for edit in edits:
        reason = check(edit, text, glossary)
        if reason:
            rejected.append((edit, reason))
            continue
        text = text.replace(edit["from"], edit["to"], 1)
        applied.append(edit)
    return text, applied, rejected


def build_messages(system, glossary, text):
    system = system + "\n\n可以改成的英文：" + "、".join(sorted(glossary, key=str.lower))
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": "才聊已經標在展示牌上，接著把NoterbookLM的範例資料放到藍色盒子。"},
        {"role": "assistant", "content": '[{"from": "才聊", "to": "材料", "type": "同音"}, {"from": "NoterbookLM", "to": "NotebookLM", "type": "英文"}]'},
        {"role": "user", "content": "就是我覺得那個藍色先排，然後然後再看要不要加上標籤。"},
        {"role": "assistant", "content": "[]"},
        {"role": "user", "content": "色票分三格，不對，四格，每格都放藍色。"},
        {"role": "assistant", "content": '[{"from": "三格，不對，四格", "to": "四格", "type": "改口"}]'},
        {"role": "user", "content": text},
    ]


TIDY_MIN_LENGTH = 30
TIDY_MIN_KEPT = 0.8
TIDY_MAX_CUT = 40
_PUNCTUATION = set(" \n\t，。！？、,.!?：:；;「」⋯…（）()")
TIDY_EXAMPLE = (
    "這個色票。其實我。其實我覺得它排得太密。然後然後你看那個藍色的。就是。它跟綠色放在一起就。分不出來嗎。"
    "下午我再去買展示架，那個架子那個架子要大一點。",
    "這個色票，其實我覺得它排得太密，然後你看那個藍色的，就是它跟綠色放在一起，分不出來嗎？\n\n"
    "下午我再去買展示架，那個架子要大一點。",
)


def tidy_messages(system, text):
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": TIDY_EXAMPLE[0]},
        {"role": "assistant", "content": TIDY_EXAMPLE[1]},
        {"role": "user", "content": text},
    ]


def check_tidy(source, output):
    """The tidied text may only remove words and change punctuation: every
    remaining character must appear in the source, in the same order, so it
    can never contain anything the speaker did not say."""
    original = [c for c in source if c not in _PUNCTUATION]
    kept = [c for c in output if c not in _PUNCTUATION]
    if not kept:
        return "empty"
    position = 0
    longest_cut = 0
    for character in kept:
        found = position
        while found < len(original) and original[found] != character:
            found += 1
        if found == len(original):
            return "added words"
        longest_cut = max(longest_cut, found - position)
        position = found + 1
    longest_cut = max(longest_cut, len(original) - position)
    if len(kept) / len(original) < TIDY_MIN_KEPT:
        return "removed too much"
    return "cut too long" if longest_cut > TIDY_MAX_CUT else None


class Proofreader:
    """Keeps the model loaded and remembers each step's fixed instructions, so
    a sentence only costs the time to read that sentence and answer."""

    def __init__(self, model_name, system, tidy_system=None):
        from mlx_lm import load
        from mlx_lm.sample_utils import make_sampler

        self.model, self.tokenizer = load(model_name)
        self.sampler = make_sampler(temp=0.0)
        self.system = system
        self.tidy_system = tidy_system
        self.prepared = {}

    def _tokens(self, messages):
        return self.tokenizer.apply_chat_template(messages, add_generation_prompt=True, tokenize=True)

    def _generate(self, step, version, build, text, max_tokens):
        from mlx_lm import generate
        from mlx_lm.models.cache import make_prompt_cache, trim_prompt_cache

        state = self.prepared.get(step)
        if state is None or state["version"] != version:
            # The fixed part is whatever two different requests have in common.
            first = self._tokens(build("甲"))
            second = self._tokens(build("乙乙"))
            size = 0
            while size < min(len(first), len(second)) and first[size] == second[size]:
                size += 1
            cache = make_prompt_cache(self.model)
            generate(self.model, self.tokenizer, prompt=first[:size], max_tokens=1,
                     sampler=self.sampler, prompt_cache=cache)
            trim_prompt_cache(cache, cache[0].offset - size)
            state = {"version": version, "cache": cache, "prefix": first[:size]}
            self.prepared[step] = state

        full = self._tokens(build(text))
        size = len(state["prefix"])
        if full[:size] != state["prefix"]:  # did not split cleanly; do it the slow way
            return generate(self.model, self.tokenizer, prompt=full, max_tokens=max_tokens, sampler=self.sampler)
        output = generate(self.model, self.tokenizer, prompt=full[size:], max_tokens=max_tokens,
                          sampler=self.sampler, prompt_cache=state["cache"])
        trim_prompt_cache(state["cache"], state["cache"][0].offset - size)
        return output

    def run(self, text):
        glossary = load_glossary()
        output = self._generate(
            "words", tuple(sorted(glossary)),
            lambda t: build_messages(self.system, glossary, t), text, 200,
        )
        fixed, applied, rejected = apply(text, parse(output), glossary)

        tidied = False
        tidy_rejected = None
        if self.tidy_system and len(fixed) >= TIDY_MIN_LENGTH:
            candidate = self._generate(
                "tidy", self.tidy_system,
                lambda t: tidy_messages(self.tidy_system, t), fixed, int(len(fixed) * 1.5) + 40,
            ).strip()
            # The model tends to keep long stutters like 他他他他.
            candidate = re.sub(r"([他她它我你])\1{2,}", r"\1", candidate)
            tidy_rejected = check_tidy(fixed, candidate)
            if tidy_rejected is None:
                fixed = candidate
                tidied = True
        return fixed, applied, rejected, tidied, tidy_rejected
