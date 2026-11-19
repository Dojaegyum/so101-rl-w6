#!/usr/bin/env bash
# 노션 02 §7 / 03 §2: 관절 sweep 검사
#   scripts/02_sweep.sh        헤드리스. 영상·관절 그래프·sweep.json 을 results/sweep 에 남긴다
#   scripts/02_sweep.sh --viz  Isaac Sim 창 (모니터 필요. 첫 실행은 셰이더 컴파일로 몇 분간 출력 없음)
source "$(dirname "$0")/env.sh"
start_isaac_lab
if [[ "${1:-}" == "--viz" ]]; then
  uv run python sweep.py --viz kit
else
  mkdir -p "${RESULTS_DIR}/sweep"
  uv run python sweep.py --out "${RESULTS_DIR}/sweep"
  echo "[완료] ${RESULTS_DIR}/sweep (sweep.mp4, joint_tracking.png, sweep.json)"
fi
