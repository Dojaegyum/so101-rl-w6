#!/usr/bin/env bash
# 결과 수집: 로그·체크포인트·영상과 각 run 의 마지막 지표를 results/ 에 모으고 tar.gz 로 묶는다.
#   tar.gz 는 노트북으로 옮기기 위한 것. git 에는 results/summary.md 만 올라간다(.gitignore 참고).
source "$(dirname "$0")/env.sh"
cd "${EXAMPLE_DIR}"
log_root="logs/rsl_rl/reach_so101"
[[ -d "${log_root}" ]] || { echo "[오류] ${log_root} 가 없습니다. 먼저 학습하세요." >&2; exit 1; }

mkdir -p "${RESULTS_DIR}"
uv run python "${REPO_ROOT}/scripts/summarize_runs.py" "${log_root}" | tee "${RESULTS_DIR}/summary.md"

stamp="$(date +%Y%m%d_%H%M%S)"
archive="${RESULTS_DIR}/so101_reach_${stamp}.tar.gz"
tar -czf "${archive}" "${log_root}" -C "${RESULTS_DIR}" $(cd "${RESULTS_DIR}" && ls -1 | grep -v '\.tar\.gz$')
echo "[완료] ${archive} ($(du -h "${archive}" | cut -f1))"
echo "노트북으로 복사 예: scp <user>@<desktop>:${archive} ."
