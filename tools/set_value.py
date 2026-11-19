"""so101_reach.py 의 REWARD / DR dict 에서 한 줄의 값만 바꾼다. 줄 끝 주석은 그대로 둔다.

    python set_value.py so101_reach.py fine_weight 0.3
    python set_value.py so101_reach.py gain_scale "(0.85, 1.15)"
"""

import re
import sys
from pathlib import Path

path, key, value = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
pattern = re.compile(rf'^(    "{re.escape(key)}":\s*)(\([^)]*\)|[^,#\n]+)(,.*)$', re.MULTILINE)
text = path.read_text(encoding="utf-8")
new, n = pattern.subn(lambda m: f"{m.group(1)}{value}{m.group(3)}", text)
if n != 1:
    sys.exit(f'"{key}" 줄을 {n}개 찾았습니다 (1개여야 함): {path}')
path.write_text(new, encoding="utf-8")
print(f"{key} = {value}")
