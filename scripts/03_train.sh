#!/usr/bin/env bash
# SO101-Reach PPO 학습. 단계별로 env 수와 iteration 을 늘린다.
#
#   scripts/03_train.sh s1        # 64 envs  x 200 iter   (동작 확인)
#   scripts/03_train.sh s2        # 512 envs x 200 iter
#   scripts/03_train.sh s3        # 512 envs x 1600 iter  (본 학습)
#   scripts/03_train.sh default   # 4096 envs x 200 iter  (패키지 기본값, RTX 5070 Ti 약 2분)
#   NUM_ENVS=1024 MAX_ITER=400 scripts/03_train.sh custom
#
# 추가 인자는 그대로 isaaclab train 에 넘어간다. 예: scripts/03_train.sh s1 --seed 1
# 로그·체크포인트: third_party/isaaclab-so101/examples/isaaclab/logs/rsl_rl/reach_so101/<날짜>_<단계>/
source "$(dirname "$0")/env.sh"
stage="${1:-}"; shift || true

case "${stage}" in
  s1)      envs=64;   iters=200 ;;
  s2)      envs=512;  iters=200 ;;
  s3)      envs=512;  iters=1600 ;;
  default) envs=4096; iters=200 ;;
  custom)  envs="${NUM_ENVS:?NUM_ENVS 를 지정하세요}"; iters="${MAX_ITER:?MAX_ITER 를 지정하세요}" ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac

load_env
cd "${EXAMPLE_DIR}"
run_name="${stage}_${envs}envs_${iters}it"
log "학습: ${TASK}, ${envs} envs x ${iters} iterations (run: ${run_name})"

mkdir -p "${RESULTS_DIR}"
start=$(date +%s)
uv run isaaclab train --task "${TASK}" \
  --num_envs "${envs}" --max_iterations "${iters}" --run_name "${run_name}" "$@" \
  2>&1 | tee "${RESULTS_DIR}/train_${run_name}.log"
echo "[완료] ${run_name}: $(( $(date +%s) - start ))초. 로그: ${RESULTS_DIR}/train_${run_name}.log"
echo "다음: scripts/04_play.sh  (가장 최근 run 을 영상으로 기록)"
