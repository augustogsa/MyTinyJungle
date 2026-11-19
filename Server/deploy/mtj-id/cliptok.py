"""CLIP byte-level BPE tokenizer (OpenAI CLIP, MIT), so mtj-id runs without torch/open_clip. Same ids as open_clip."""
import gzip, html, os
from functools import lru_cache
import ftfy, numpy as np, regex as re


@lru_cache()
def bytes_to_unicode():
    bs = list(range(ord("!"), ord("~") + 1)) + list(range(ord("¡"), ord("¬") + 1)) + list(range(ord("®"), ord("ÿ") + 1))
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b); cs.append(256 + n); n += 1
    return dict(zip(bs, map(chr, cs)))


def get_pairs(word):
    return {(word[i], word[i + 1]) for i in range(len(word) - 1)}


def clean(text):
    text = ftfy.fix_text(text)
    text = html.unescape(html.unescape(text))
    return re.sub(r"\s+", " ", text).strip().lower()


class Tokenizer:
    def __init__(self, path=os.path.join(os.path.dirname(os.path.abspath(__file__)), "bpe_simple_vocab_16e6.txt.gz")):
        self.byte_encoder = bytes_to_unicode()
        merges = gzip.open(path).read().decode("utf-8").split("\n")[1:49152 - 256 - 2 + 1]
        merges = [tuple(m.split()) for m in merges]
        vocab = list(bytes_to_unicode().values())
        vocab = vocab + [v + "</w>" for v in vocab] + ["".join(m) for m in merges] + ["<start_of_text>", "<end_of_text>"]
        self.encoder = dict(zip(vocab, range(len(vocab))))
        self.bpe_ranks = dict(zip(merges, range(len(merges))))
        self.cache = {"<start_of_text>": "<start_of_text>", "<end_of_text>": "<end_of_text>"}
        self.pat = re.compile(r"""<start_of_text>|<end_of_text>|'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+""", re.IGNORECASE)
        self.sot, self.eot = self.encoder["<start_of_text>"], self.encoder["<end_of_text>"]

    def bpe(self, token):
        if token in self.cache:
            return self.cache[token]
        word = tuple(token[:-1]) + (token[-1] + "</w>",)
        pairs = get_pairs(word)
        if not pairs:
            return token + "</w>"
        while True:
            bigram = min(pairs, key=lambda p: self.bpe_ranks.get(p, float("inf")))
            if bigram not in self.bpe_ranks:
                break
            first, second = bigram
            new, i = [], 0
            while i < len(word):
                try:
                    j = word.index(first, i)
                    new.extend(word[i:j]); i = j
                except ValueError:
                    new.extend(word[i:]); break
                if word[i] == first and i < len(word) - 1 and word[i + 1] == second:
                    new.append(first + second); i += 2
                else:
                    new.append(word[i]); i += 1
            word = tuple(new)
            if len(word) == 1:
                break
            pairs = get_pairs(word)
        word = " ".join(word)
        self.cache[token] = word
        return word

    def encode(self, text):
        out = []
        for tok in re.findall(self.pat, clean(text)):
            tok = "".join(self.byte_encoder[b] for b in tok.encode("utf-8"))
            out.extend(self.encoder[t] for t in self.bpe(tok).split(" "))
        return out

    def __call__(self, texts, ctx=77):
        r = np.zeros((len(texts), ctx), dtype=np.int64)
        for i, t in enumerate(texts):
            ids = [self.sot] + self.encode(t)[: ctx - 2] + [self.eot]
            r[i, : len(ids)] = ids
        return r
