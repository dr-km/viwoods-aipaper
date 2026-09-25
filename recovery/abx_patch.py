#!/usr/bin/env python3
"""Remove attributes from one <pkg name="..."> in an Android Binary XML (ABX) file.

Used to clear a package's disabled state (`enabled`, `enabledCaller`) in
/data/system/users/0/package-restrictions.xml. Text round-trips (abx2xml -> xml2abx)
are lossy: they flatten typed/interned attributes into plain strings. This tool parses
the token stream, drops the named attributes, and re-emits it with a rebuilt
interned-string table.

Safety:
  * before patching, re-emitting the UNMODIFIED file must reproduce it byte-for-byte
    (proves the writer handles every token in this file);
  * after patching, the result is re-parsed and must equal the original minus the
    dropped attributes.

Usage:
  abx_patch.py <in.abx> --check                                  # parse + identity test only
  abx_patch.py <in.abx> <pkg-name> <attr> [<attr> ...] --out <out.abx>

Several packages: run once per package, feeding each output to the next.
Always verify the result with the platform decoder (abx2xml) before installing.
"""
import struct
import sys

START_DOC, END_DOC, START_TAG, END_TAG = 0, 1, 2, 3
TEXT_LIKE = {4, 5, 6, 7, 8, 9, 10}
ATTRIBUTE = 15

T_NULL, T_STR, T_INT_STR, T_BHEX, T_B64 = 0x10, 0x20, 0x30, 0x40, 0x50
T_INT, T_INTHEX, T_LONG, T_LONGHEX = 0x60, 0x70, 0x80, 0x90
T_FLOAT, T_DOUBLE, T_TRUE, T_FALSE = 0xA0, 0xB0, 0xC0, 0xD0
FIXED = {T_INT: 4, T_INTHEX: 4, T_LONG: 8, T_LONGHEX: 8, T_FLOAT: 4, T_DOUBLE: 8, T_TRUE: 0, T_FALSE: 0}


class Tok:
    """name/value hold raw bytes (no decoding), so re-emission is lossless."""
    __slots__ = ("start", "end", "cmd", "typ", "name", "value")

    def __init__(self, start, end, cmd, typ, name=None, value=None):
        self.start, self.end, self.cmd, self.typ, self.name, self.value = start, end, cmd, typ, name, value

    def key(self):
        return (self.cmd, self.typ, self.name, self.value)

    def sname(self):
        return self.name.decode("utf-8", "replace") if self.name is not None else None


def parse(data):
    assert data[:4] == b"ABX\x00", "bad magic (not an ABX file)"
    pos = 4
    strings = []
    toks = []

    def u16():
        nonlocal pos
        v = struct.unpack_from(">H", data, pos)[0]
        pos += 2
        return v

    def utf():
        nonlocal pos
        n = u16()
        raw = data[pos:pos + n]
        assert len(raw) == n, "truncated string (file cut off mid-write?)"
        pos += n
        return raw

    def interned():
        idx = u16()
        if idx == 0xFFFF:
            s = utf()
            strings.append(s)
            return s
        return strings[idx]

    while pos < len(data):
        start = pos
        b = data[pos]
        pos += 1
        cmd, typ = b & 0x0F, b & 0xF0
        name = value = None
        if cmd == START_DOC:
            assert typ == T_NULL
        elif cmd == END_DOC:
            assert typ == T_NULL
            toks.append(Tok(start, pos, cmd, typ))
            break
        elif cmd in (START_TAG, END_TAG):
            assert typ == T_INT_STR, f"tag token type {typ:#x} at {start}"
            name = interned()
        elif cmd in TEXT_LIKE:
            assert typ == T_STR
            value = utf()
        elif cmd == ATTRIBUTE:
            name = interned()
            if typ == T_STR:
                value = utf()
            elif typ == T_INT_STR:
                value = interned()
            elif typ in (T_BHEX, T_B64):
                n = u16()
                value = data[pos:pos + n]
                pos += n
            elif typ in FIXED:
                n = FIXED[typ]
                value = data[pos:pos + n]
                pos += n
            else:
                raise AssertionError(f"unknown attr type {typ:#x} at {start}")
        else:
            raise AssertionError(f"unknown token {b:#x} at {start}")
        toks.append(Tok(start, pos, cmd, typ, name, value))
    assert toks and toks[-1].cmd == END_DOC, "no END_DOCUMENT (truncated file?)"
    assert pos == len(data), f"trailing bytes: parsed {pos} of {len(data)}"
    return toks


def emit(toks):
    """Serialize tokens; interned strings are (re)numbered in order of first use."""
    out = bytearray(b"ABX\x00")
    table = {}

    def w_utf(b):
        out.extend(struct.pack(">H", len(b)))
        out.extend(b)

    def w_interned(b):
        if b in table:
            out.extend(struct.pack(">H", table[b]))
        else:
            out.extend(b"\xff\xff")
            w_utf(b)
            table[b] = len(table)

    for t in toks:
        out.append(t.cmd | t.typ)
        if t.cmd in (START_DOC, END_DOC):
            continue
        if t.cmd in (START_TAG, END_TAG):
            w_interned(t.name)
        elif t.cmd in TEXT_LIKE:
            w_utf(t.value)
        elif t.cmd == ATTRIBUTE:
            w_interned(t.name)
            if t.typ == T_STR:
                w_utf(t.value)
            elif t.typ == T_INT_STR:
                w_interned(t.value)
            elif t.typ in (T_BHEX, T_B64):
                out.extend(struct.pack(">H", len(t.value)))
                out.extend(t.value)
            elif t.typ in FIXED:
                out.extend(t.value)
    return bytes(out)


def load(path):
    data = open(path, "rb").read()
    toks = parse(data)
    assert emit(toks) == data, "identity re-emit != original: writer can't reproduce this file; refusing to patch"
    return data, toks


def elements(toks):
    """Yield (start_tok_index, [attr tok indices]) for each START_TAG."""
    for i, t in enumerate(toks):
        if t.cmd == START_TAG:
            j = i + 1
            attrs = []
            while toks[j].cmd == ATTRIBUTE:
                attrs.append(j)
                j += 1
            yield i, attrs


def show(t):
    v = t.value
    if isinstance(v, bytes) and t.typ in (T_INT, T_INTHEX, T_LONG, T_LONGHEX):
        return int.from_bytes(v, "big")
    if isinstance(v, bytes) and t.typ in (T_STR, T_INT_STR):
        return v.decode("utf-8", "replace")
    return v.hex() if isinstance(v, bytes) else v


def main():
    argv = sys.argv[1:]
    if len(argv) >= 2 and argv[1] == "--check":
        data, toks = load(argv[0])
        n_tag = sum(1 for t in toks if t.cmd == START_TAG)
        print(f"OK: {len(toks)} tokens, {n_tag} elements, {len(data)} bytes fully consumed; identity re-emit byte-exact")
        return

    out_i = argv.index("--out")
    out_path = argv[out_i + 1]
    src, pkg, drop_names = argv[0], argv[1].encode(), {a.encode() for a in argv[2:out_i]}
    data, toks = load(src)

    matches = []
    for i, attrs in elements(toks):
        if toks[i].name != b"pkg":
            continue
        for a in attrs:
            if toks[a].name == b"name" and toks[a].value == pkg:
                matches.append((i, attrs))
    assert len(matches) == 1, f"expected exactly 1 <pkg name={pkg.decode()}>, found {len(matches)}"
    i, attrs = matches[0]

    print(f"element <pkg> at byte {toks[i].start}:")
    drop = []
    for a in attrs:
        t = toks[a]
        mark = "DROP" if t.name in drop_names else "keep"
        print(f"  [{mark}] bytes {t.start}-{t.end} type={t.typ:#04x} {t.sname()}={show(t)!r}")
        if t.name in drop_names:
            drop.append(t)
    missing = drop_names - {t.name for t in drop}
    for m in sorted(missing):
        print(f"  [note] attribute {m.decode()!r} not present on this package (nothing to drop)")
    assert drop, "none of the requested attributes are present — nothing to do"

    dropped = {id(t) for t in drop}
    remaining = [t for t in toks if id(t) not in dropped]
    out = emit(remaining)
    open(out_path, "wb").write(out)

    # independent check: re-parse and compare token streams (string-level, index-independent)
    got = [t.key() for t in parse(out)]
    want = [t.key() for t in remaining]
    assert got == want, "patched token stream != original minus dropped attributes"
    print(f"wrote {out_path}: {len(data)} -> {len(out)} bytes ({len(out) - len(data):+d}); token stream verified")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, struct.error, IndexError, ValueError, OSError) as e:
        sys.exit(f"error: {e}")
