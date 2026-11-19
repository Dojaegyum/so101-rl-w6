#!/usr/bin/env bash
# 결과 수집: run 별 마지막 지표 표(results/summary.md) + 노트북으로 옮길 tar.gz
#   tar.gz 에 들어가는 것: logs/rsl_rl (체크포인트·TensorBoard·영상), experiments/ (기록·로그), ~/robotics/so101-deploy (ONNX)
#   05 실기 배포는 팔이 연결된 노트북에서 한다. tar 를 풀어 so101-deploy 폴더를 ~/robotics/ 아래에 두면 된다.
source "$(dirname "$0")/env.sh"
SKIP_GPU_CHECK=1 start_isaac_lab
[[ -d logs/rsl_rl ]] || die "logs/rsl_rl 이 없습니다. 먼저 학습하세요."
mkdir -p "${RESULTS_DIR}"
uv run --no-sync python "${REPO_ROOT}/tools/summarize_runs.py" logs/rsl_rl | tee "${RESULTS_DIR}/summary.md"

stamp="$(date +%Y%m%d_%H%M%S)"
archive="${RESULTS_DIR}/so101_results_${stamp}.tar.gz"
items=("isaaclab-so101/examples/isaaclab/logs/rsl_rl" "isaaclab-so101/examples/isaaclab/experiments")
[[ -d "${DEPLOY_DIR}" ]] && items+=("so101-deploy")
tar -czf "${archive}" -C "${ROBOTICS_DIR}" "${items[@]}"
echo "[완료] ${archive} ($(du -h "${archive}" | cut -f1))"
echo "노트북으로 복사: scp <user>@<desktop>:${archive} ."
echo "노트북에서 풀기: mkdir -p ~/robotics && tar -xzf $(basename "${archive}") -C ~/robotics so101-deploy"
