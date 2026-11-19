#!/usr/bin/env bash
# W6·W7 과제(tasks/w6_w7_tasks.py)를 so101_reach.py 끝에 덧붙인다.
# 노션은 cat >> 블록을 여러 번 붙여 넣지만, 여기서는 항상 원본(고정 커밋)에서 다시 시작하므로
# 여러 번 실행해도 "Cannot re-register id" 오류가 나지 않는다.
#   scripts/apply_tasks.sh           원본 + W6·W7 과제
#   scripts/apply_tasks.sh --reset   원본으로만 되돌린다
source "$(dirname "$0")/env.sh"
SKIP_GPU_CHECK=1 start_isaac_lab

# 직접 고친 내용이 있으면 덮어쓰기 전에 남겨 둔다
if ! git -C "${UPSTREAM_DIR}" diff --quiet -- examples/isaaclab/so101_reach.py \
   && ! cmp -s so101_reach.py "${REPO_ROOT}/.applied_marker" 2>/dev/null; then
  keep="experiments/backup/so101_reach.local-$(date +%Y%m%d_%H%M%S).py"
  cp so101_reach.py "$keep"; echo "기존 수정본 보관: $keep"
fi

git -C "${UPSTREAM_DIR}" show HEAD:examples/isaaclab/so101_reach.py > so101_reach.py
if [[ "${1:-}" != "--reset" ]]; then
  cat "${REPO_ROOT}/tasks/w6_w7_tasks.py" >> so101_reach.py
  cp so101_reach.py experiments/backup/so101_reach.with-w6-w7.py
fi
cp so101_reach.py "${REPO_ROOT}/.applied_marker"

uv run --no-sync python -c 'import so101_reach, gymnasium as gym; print([t for t in gym.registry if t.startswith("SO101")])'
