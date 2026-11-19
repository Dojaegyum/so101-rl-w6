#!/usr/bin/env bash
# 노션 03 Reach 학습 (PPO)
#   scripts/w3.sh smoke        §3 소규모 시험: 64 envs x 10 iterations
#   scripts/w3.sh basic        §4 본 학습: 512 envs x 200 iterations → experiments/basic-checkpoint.txt
#   scripts/w3.sh resume       §6 기본 체크포인트에서 200 iterations 이어 학습 (선택)
#   scripts/w3.sh exp A|B|C|D|E  §9 실습 (선택, 각 400 iterations)
#       A: envs 512 vs 2048   B: seed 1,2,3   C: fine_grained weight 0.2 (Hydra)
#       D: action scale 0.25 (파일 수정 후 되돌림)   E: pos_z (0.05, 0.35) (파일 수정 후 되돌림)
source "$(dirname "$0")/env.sh"
start_isaac_lab

restore_reach() {  # D·E 뒤 되돌리기. W6·W7 과제가 적용돼 있었으면 그 상태로 되돌린다
  if [[ -f experiments/backup/so101_reach.with-w6-w7.py ]] && cmp -s experiments/before-exp.py experiments/backup/so101_reach.with-w6-w7.py; then
    cp experiments/backup/so101_reach.with-w6-w7.py so101_reach.py
  else
    cp experiments/before-exp.py so101_reach.py
  fi
  rm -f experiments/before-exp.py
}

case "${1:-}" in
  smoke)
    train w3-smoke --task SO101-Reach --num_envs 64 --max_iterations 10 ;;
  basic)
    train baseline-512-200 --task SO101-Reach --num_envs 512 --max_iterations 200
    record_checkpoint reach_so101 basic-checkpoint.txt ;;
  resume)
    CKPT="$(read_checkpoint basic-checkpoint.txt)"
    train resume-512-200 --task SO101-Reach --num_envs 512 --max_iterations 200 --checkpoint "$CKPT" --run_name resume ;;
  exp)
    case "${2:-}" in
      A) for n in 512 2048; do train "envs$n-400" --task SO101-Reach --num_envs "$n" --max_iterations 400 --run_name "envs$n"; done ;;
      B) for s in 1 2 3; do train "envs512-seed$s" --task SO101-Reach --num_envs 512 --max_iterations 400 --seed "$s" --run_name "envs512_seed$s"; done ;;
      C) train fine_w0.2 --task SO101-Reach --num_envs 512 --max_iterations 400 --run_name fine_w0.2 \
           env.rewards.end_effector_position_tracking_fine_grained.weight=0.2 ;;
      D|E)
        cp so101_reach.py experiments/before-exp.py
        trap restore_reach EXIT
        if [[ "$2" == D ]]; then
          grep -q 'scale=0.5, use_default_offset=True' so101_reach.py || die "scale=0.5 줄을 찾지 못했습니다."
          sed -i 's/scale=0.5, use_default_offset=True/scale=0.25, use_default_offset=True/' so101_reach.py; name=scale0.25
        else
          grep -q 'pos_z = (0.10, 0.30)\|pos_z=(0.10, 0.30)\|pos_z = (0.1, 0.3)' so101_reach.py || { grep -n pos_z so101_reach.py; die "pos_z 기본값 줄을 찾지 못했습니다."; }
          sed -i -E '0,/pos_z ?= ?\(0\.10?, 0\.30?\)/s//pos_z = (0.05, 0.35)/' so101_reach.py; name=posz_wide
        fi
        diff experiments/backup/so101_reach.baseline.py so101_reach.py | head -20 || true
        train "$name" --task SO101-Reach --num_envs 512 --max_iterations 400 --run_name "$name" ;;
      *) die "실습 이름은 A, B, C, D, E 중 하나입니다." ;;
    esac ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac
