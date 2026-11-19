#!/usr/bin/env bash
# 7. 헤드리스 관절 검사. 영상·관절 그래프·sweep.json 을 results/sweep 에 남긴다.
#   --viz : Isaac Sim 창으로 확인 (모니터 연결된 데스크탑에서만. 첫 실행은 셰이더 컴파일로 수 분간 출력 없음)
source "$(dirname "$0")/env.sh"
load_env
cd "${EXAMPLE_DIR}"

if [[ "${1:-}" == "--viz" ]]; then
  uv run python sweep.py --viz kit
else
  mkdir -p "${RESULTS_DIR}/sweep"
  uv run python sweep.py --out "${RESULTS_DIR}/sweep"
  echo "[완료] 결과: ${RESULTS_DIR}/sweep (sweep.mp4, joint_tracking.png, sweep.json)"
fi
