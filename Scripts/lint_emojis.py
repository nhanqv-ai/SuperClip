#!/usr/bin/env python3
import sys
import os
import unicodedata

def is_emoji_char(char):
    code = ord(char)
    # Unicode emoji ranges:
    # 0x1F300-0x1F5FF: Misc Symbols and Pictographs
    # 0x1F600-0x1F64F: Emoticons
    # 0x1F680-0x1F6FF: Transport and Map
    # 0x1F700-0x1F77F: Alchemical
    # 0x1F780-0x1F7FF: Geometric Shapes Extended
    # 0x1F800-0x1F8FF: Supplemental Arrows-C
    # 0x1F900-0x1F9FF: Supplemental Symbols and Pictographs
    # 0x1FA00-0x1FA6F: Chess Symbols
    # 0x1FA70-0x1FAFF: Symbols and Pictographs Extended-A
    # 0x2600-0x26FF:   Misc Symbols
    # 0x2700-0x27BF:   Dingbats
    if 0x1F300 <= code <= 0x1FAFF:
        return True
    if 0x2600 <= code <= 0x27BF:
        return True
    if code in (0xFE0E, 0xFE0F): # variation selectors
        return True
    # Emoticons / Pictographs outside standard block
    if 0x1F1E6 <= code <= 0x1F1FF: # Regional indicator flags
        return True
    cat = unicodedata.category(char)
    # Check other symbols but exclude Box Drawing (0x2500-0x257F), Block Elements (0x2580-0x259F),
    # and Control/Technical symbols (0x2300-0x23FF like Cmd/Option keys)
    if cat in ('So', 'Sk') and code > 0x27BF:
        return True
    return False

def scan_file(filepath):
    violations = []
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line_no, line in enumerate(f, start=1):
                for col_no, ch in enumerate(line, start=1):
                    if is_emoji_char(ch):
                        violations.append((line_no, col_no, ch, hex(ord(ch))))
    except Exception as e:
        pass
    return violations

def main():
    targets = sys.argv[1:]
    if not targets:
        targets = ["Sources", "Tests", "Scripts", "Makefile", "Package.swift", "PROJECT.md", "TEST_INFRA.md"]

    total_violations = 0
    scanned_files = 0

    for root_target in targets:
        if not os.path.exists(root_target):
            continue
        if os.path.isfile(root_target):
            paths = [root_target]
        else:
            paths = []
            for root, _, files in os.walk(root_target):
                # Skip .git directory
                if "/.git" in root or root.endswith("/.git"):
                    continue
                # Skip .agents directory to avoid scanning other agents work-in-progress notes
                if "/.agents" in root or root.endswith("/.agents"):
                    continue
                for f in files:
                    if f.endswith(('.swift', '.plist', '.py', '.sh', '.json', '.md', 'Makefile', 'Package.swift')):
                        paths.append(os.path.join(root, f))

        for path in paths:
            scanned_files += 1
            violations = scan_file(path)
            if violations:
                total_violations += len(violations)
                for line_no, col_no, ch, code in violations:
                    print(f"ERROR: Emoji violation in {path}:{line_no}:{col_no} -> character '{ch}' ({code})")

    if total_violations > 0:
        print(f"\nFAILED: Found {total_violations} emoji violations across {scanned_files} files.")
        print("SuperClip strictly requires flat vector design and SF Symbols. No emojis permitted.")
        sys.exit(1)
    else:
        print(f"PASSED: Scanned {scanned_files} files. 0 emojis found.")
        sys.exit(0)

if __name__ == '__main__':
    main()
