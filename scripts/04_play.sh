#!/usr/bin/env bash
# 학습된 정책 재생.
#   scripts/04_play.sh               # 가장 최근 run 을 12초 영상으로 헤드리스 기록
#   scripts/04_play.sh <run 폴더명>   # 특정 run (예: 2026-11-20_10-00-00_s3_512envs_1600it)
#   scripts/04_play.sh --viz [run]   # Isaac Sim 창으로 보기 (모니터 필요)
source "$(dirname "$0")/env.sh"
load_env
cd "${EXAMPLE_DIR}"

viz=0
if [[ "${1:-}" == "--viz" ]]; then viz=1; shift; fi

log_root="${EXAMPLE_DIR}/logs/rsl_rl/reach_so101"
run="${1:-$(ls -1t "${log_root}" 2>/dev/null | head -1)}"
[[ -n "${run}" && -d "${log_root}/${run}" ]] || { echo "[오류] run 을 찾을 수 없습니다: ${log_root}/${run}" >&2; exit 1; }
log "재생: ${run}"

if (( viz )); then
  uv run isaaclab play --task "${TASK}" --checkpoint "${log_root}/${run}" --viz kit
else
  uv run isaaclab play --task "${TASK}" --checkpoint "${log_root}/${run}" --video --video_length 360
  echo "[완료] 영상은 ${log_root}/${run}/videos/ 아래에 저장됩니다."
fi
