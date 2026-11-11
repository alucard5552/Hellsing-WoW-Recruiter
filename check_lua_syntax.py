import re
import sys

def check_file(filepath):
    print(f"=== Checking {filepath} ===")
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()

    # remove comments: --[=[ ... ]=] and --[[ ... ]]
    text = re.sub(r'--\[(=*)\[.*?\]\1\]', '', text, flags=re.DOTALL)
    lines = [re.sub(r'--.*$', '', l) for l in text.splitlines()]

    stack = []
    for line_idx, line in enumerate(lines):
        clean = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        clean = re.sub(r"'(?:[^'\\]|\\.)*'", "''", clean)
        
        words = re.findall(r'\b[a-zA-Z_]\w*\b', clean)
        for i, w in enumerate(words):
            if w in ('function', 'if', 'repeat'):
                stack.append((w, line_idx + 1))
            elif w in ('for', 'while'):
                stack.append((w, line_idx + 1))
            elif w == 'do':
                prev_loop = any(words[j] in ('for', 'while') for j in range(i))
                if not prev_loop:
                    stack.append(('do', line_idx + 1))
            elif w == 'end':
                if stack and stack[-1][0] in ('function', 'if', 'for', 'while', 'do'):
                    stack.pop()
                else:
                    print(f"ERROR: Extra 'end' at line {line_idx + 1}")
            elif w == 'until':
                if stack and stack[-1][0] == 'repeat':
                    stack.pop()
                else:
                    print(f"ERROR: Extra 'until' at line {line_idx + 1}")

    if not stack:
        print("PERFECT: 0 unclosed blocks! All blocks matched cleanly.")
    else:
        print(f"WARNING: {len(stack)} unclosed blocks:")
        for item in stack:
            print(f"  Line {item[1]}: {item[0]}")

if __name__ == '__main__':
    for p in sys.argv[1:]:
        check_file(p)
