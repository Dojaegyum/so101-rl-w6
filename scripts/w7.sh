#!/usr/bin/env bash
# 노션 07 도메인 랜덤화 (Sim-to-Real 개선). 06 §5 구 정책(experiments/sphere-checkpoint.txt)이 기준 A 다.
#   scripts/w7.sh check      §2 Isaac Lab 에 관측 지연·bias 잡음 기능이 있는지, 과제가 등록됐는지
#   scripts/w7.sh smoke      §3 소규모 시험: SO101-Reach-Sphere-DR 64 envs x 10
#   scripts/w7.sh train      §4 DR 정책 B 학습: 2048 envs x 600 → experiments/sphere-dr-checkpoint.txt
#   scripts/w7.sh compare    §5 DR 환경에서 A·B 를 각각 16 envs 로 재생해 영상 두 개
#   scripts/w7.sh export     §6 B 를 구 점으로 재생 → ~/robotics/so101-deploy/07/
#   scripts/w7.sh tune KEY=VALUE [...] [--run_name 이름]   §8 DR 값 바꿔 B 다시 학습 (끝나면 원래 값으로)
#       예: scripts/w7.sh tune 'gain_scale=(0.85, 1.15)' joint_pos_bias=0.015 --run_name dr_weak
# 환경 변수: NUM_ENVS (기본 2048), MAX_ITER (기본 600)
source "$(dirname "$0")/env.sh"
start_isaac_lab
ENVS="${NUM_ENVS:-2048}"
ITER_ARGS=(); [[ -n "${MAX_ITER:-}" ]] && ITER_ARGS=(--max_iterations "$MAX_ITER")
require_tasks() { grep -q '"SO101-Reach-Sphere-DR"' so101_reach.py || die "DR 과제가 없습니다. scripts/apply_tasks.sh 를 먼저 실행하세요."; }

case "${1:-}" in
  check)
    echo "delay_max_lag: $(grep -c delay_max_lag .venv/lib/python3.12/site-packages/isaaclab/managers/manager_term_cfg.py)"
    echo "NoiseModelWithAdditiveBiasCfg: $(grep -c NoiseModelWithAdditiveBiasCfg .venv/lib/python3.12/site-packages/isaaclab/utils/noise/noise_cfg.py)"
    echo "SO101-Reach-Sphere: $(grep -c '"SO101-Reach-Sphere"' so101_reach.py), SO101-Reach-Sphere-DR: $(grep -c '"SO101-Reach-Sphere-DR"' so101_reach.py)"
    grep -n "^DR = {" -A8 so101_reach.py || true ;;
  smoke)
    require_tasks; train w7-smoke --task SO101-Reach-Sphere-DR --num_envs 64 --max_iterations 10 ;;
  train)
    require_tasks
    train sphere-dr-train --task SO101-Reach-Sphere-DR --num_envs "$ENVS" --run_name sphere_dr "${ITER_ARGS[@]}"
    record_checkpoint reach_so101_sphere_dr sphere-dr-checkpoint.txt ;;
  compare)
    CKPT_A="$(read_checkpoint sphere-checkpoint.txt)"; CKPT_B="$(read_checkpoint sphere-dr-checkpoint.txt)"
    play_video "$CKPT_A" --task SO101-Reach-Sphere-DR --num_envs 16 --video --video_length 360
    play_video "$CKPT_B" --task SO101-Reach-Sphere-DR --num_envs 16 --video --video_length 360 ;;
  export)
    CKPT_B="$(read_checkpoint sphere-dr-checkpoint.txt)"
    GOAL="0 -0.32 0.18" play_video "$CKPT_B" --task SO101-Reach-Goal-Play --num_envs 4 --video --video_length 120
    export_policy "$CKPT_B" 07 '{"shape": "sphere", "center": [0.0, -0.20, 0.18], "radius": 0.15, "min_z": 0.05}' ;;
  tune)
    require_tasks; shift
    base=experiments/backup/so101_reach.with-w6-w7.py; [[ -f "$base" ]] || die "$base 가 없습니다."
    run=dr_tuned; sets=()
    while (( $# )); do
      if [[ "$1" == --run_name ]]; then run="$2"; shift 2; else sets+=("$1"); shift; fi
    done
    (( ${#sets[@]} )) || die "바꿀 값을 KEY=VALUE 로 주세요."
    cp "$base" so101_reach.py
    trap 'cp "$base" so101_reach.py; echo "so101_reach.py 의 DR 값을 원래대로 되돌렸습니다."' EXIT
    for kv in "${sets[@]}"; do set_value so101_reach.py "${kv%%=*}" "${kv#*=}"; done
    diff "$base" so101_reach.py || true
    train "sphere-dr-$run" --task SO101-Reach-Sphere-DR --num_envs "$ENVS" --run_name "$run" "${ITER_ARGS[@]}"
    record_checkpoint reach_so101_sphere_dr "sphere-dr-$run-checkpoint.txt" ;;
  *) sed -n '2,11p' "$0"; exit 1 ;;
esac
