#!/usr/bin/env python3
import argparse
import json
import sys


def strip_comments(text: str) -> str:
    out = []
    i = 0
    in_str = False
    escape = False
    while i < len(text):
        ch = text[i]
        if in_str:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
            i += 1
            continue

        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue

        if ch == "/" and i + 1 < len(text):
            nxt = text[i + 1]
            if nxt == "/":
                i += 2
                while i < len(text) and text[i] not in "\n\r":
                    i += 1
                continue
            if nxt == "*":
                i += 2
                while i + 1 < len(text) and not (text[i] == "*" and text[i + 1] == "/"):
                    i += 1
                i += 2
                continue

        out.append(ch)
        i += 1
    return "".join(out)


def strip_trailing_commas(text: str) -> str:
    out = []
    i = 0
    in_str = False
    escape = False
    while i < len(text):
        ch = text[i]
        if in_str:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
            i += 1
            continue

        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue

        if ch == ",":
            j = i + 1
            while j < len(text) and text[j] in " \t\r\n":
                j += 1
            if j < len(text) and text[j] in "]}":
                i += 1
                continue

        out.append(ch)
        i += 1
    return "".join(out)


def parse_hujson(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()
    cleaned = strip_trailing_commas(strip_comments(raw))
    return json.loads(cleaned)


def collect_refs(obj, tags, groups):
    if isinstance(obj, dict):
        for v in obj.values():
            collect_refs(v, tags, groups)
    elif isinstance(obj, list):
        for v in obj:
            collect_refs(v, tags, groups)
    elif isinstance(obj, str):
        if obj.startswith("tag:"):
            tags.add(obj)
        elif obj.startswith("group:"):
            groups.add(obj)


def main() -> int:
    parser = argparse.ArgumentParser(description="Lightweight HuJSON ACL validator.")
    parser.add_argument("file", help="Path to acl.hujson")
    args = parser.parse_args()

    try:
        data = parse_hujson(args.file)
    except Exception as exc:
        print(f"ERROR: Failed to parse HuJSON: {exc}", file=sys.stderr)
        return 1

    defined_tags = set((data.get("tagOwners") or {}).keys())
    defined_groups = set((data.get("groups") or {}).keys())

    ref_tags = set()
    ref_groups = set()
    collect_refs(data, ref_tags, ref_groups)

    missing_tags = sorted(t for t in ref_tags if t not in defined_tags)
    missing_groups = sorted(g for g in ref_groups if g not in defined_groups)

    if missing_tags:
        print("ERROR: Tags referenced but not defined in tagOwners:", file=sys.stderr)
        for tag in missing_tags:
            print(f"  - {tag}", file=sys.stderr)

    if missing_groups:
        print("ERROR: Groups referenced but not defined in groups:", file=sys.stderr)
        for group in missing_groups:
            print(f"  - {group}", file=sys.stderr)

    if missing_tags or missing_groups:
        return 1

    print("OK: HuJSON parsed and tag/group references are defined.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
