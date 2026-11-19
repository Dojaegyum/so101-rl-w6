#!/usr/bin/env bash
# 노션 06 임의의 점 추종 (목표 범위 설계). 먼저 scripts/apply_tasks.sh 로 과제를 등록한다.
#   scripts/w6.sh limit            §0 기본 정책에 상자 점·구 점을 줘 한계 보기 (영상)
#   scripts/w6.sh smoke            §3 소규모 시험: SO101-Reach-Wide 64 envs x 10
#   scripts/w6.sh box              §3 상자 학습: 2048 envs x 600 → experiments/box-checkpoint.txt
#   scripts/w6.sh box-video        §4 상자 정책으로 상자 점 영상. GOAL="x y z" 로 다른 점 가능
#   scripts/w6.sh sphere           §5 구 학습 → experiments/sphere-checkpoint.txt
#   scripts/w6.sh sphere-video     §5 구 정책으로 구 점 영상
#   scripts/w6.sh high             §5 (선택) 위로 높이 뻗기 학습 + 높은 점 두 개 영상
#   scripts/w6.sh reward R1|R2|R3|R4   §5-1 보상 실험: 값 바꿈 → 학습 → 구 점 영상 → 원래 값으로
#   scripts/w6.sh export [sphere|box|high|smooth]   §6 ONNX 를 ~/robotics/so101-deploy/06*/ 로 (기본 sphere)
# 환경 변수: NUM_ENVS (기본 2048, GPU 메모리 부족하면 1024), MAX_ITER (기본: 과제 설정의 600)
source "$(dirname "$0")/env.sh"
start_isaac_lab
grep -q '"SO101-Reach-Sphere-DR"' so101_reach.py || die "W6·W7 과제가 없습니다. scripts/apply_tasks.sh 를 먼저 실행하세요."

ENVS="${NUM_ENVS:-2048}"
ITER_ARGS=(); [[ -n "${MAX_ITER:-}" ]] && ITER_ARGS=(--max_iterations "$MAX_ITER")
BOX_POINT="0.17 -0.15 0.12"     # §0 상자 점
SPHERE_POINT="0 -0.32 0.18"     # §0 구 점
SPHERE_RANGE='{"shape": "sphere", "center": [0.0, -0.20, 0.18], "radius": 0.15, "min_z": 0.05}'
BOX_RANGE='{"shape": "box", "x": [-0.20, 0.20], "y": [-0.30, -0.10], "z": [0.05, 0.30]}'
HIGH_RANGE='{"shape": "sphere", "center": [0.0, -0.18, 0.24], "radius": 0.15, "min_z": 0.05}'

goal_video() {  # goal_video <체크포인트> <점> [video_length]
  GOAL="$2" play_video "$1" --task SO101-Reach-Goal-Play --num_envs 4 --video --video_length "${3:-120}"
}

case "${1:-}" in
  limit)
    CKPT="$(read_checkpoint basic-checkpoint.txt)"
    goal_video "$CKPT" "$BOX_POINT"; goal_video "$CKPT" "$SPHERE_POINT" ;;
  smoke)
    train w6-smoke --task SO101-Reach-Wide --num_envs 64 --max_iterations 10 ;;
  box)
    train box_wide --task SO101-Reach-Wide --num_envs "$ENVS" --run_name box_wide "${ITER_ARGS[@]}"
    record_checkpoint reach_so101_wide box-checkpoint.txt ;;
  box-video)
    goal_video "$(read_checkpoint box-checkpoint.txt)" "${GOAL:-$BOX_POINT}" ;;
  sphere)
    train sphere_r15 --task SO101-Reach-Sphere --num_envs "$ENVS" --run_name sphere_r15 "${ITER_ARGS[@]}"
    record_checkpoint reach_so101_sphere sphere-checkpoint.txt ;;
  sphere-video)
    goal_video "$(read_checkpoint sphere-checkpoint.txt)" "${GOAL:-$SPHERE_POINT}" ;;
  high)
    train high_r15 --task SO101-Reach-High --num_envs "$ENVS" --run_name high_r15 "${ITER_ARGS[@]}"
    CKPT="$(record_checkpoint reach_so101_high high-checkpoint.txt)"
    goal_video "$CKPT" "0 -0.18 0.35"; goal_video "$CKPT" "0 -0.15 0.38" ;;
  reward)
    case "${2:-}" in
      R1) NAME=fine0.3;    SET=("fine_weight=0.3") ;;
      R2) NAME=track0.5;   SET=("track_weight=-0.5") ;;
      R3) NAME=smooth0.02; SET=("action_rate_final=-0.02") ;;
      R4) NAME=nopenalty;  SET=("action_rate_final=-0.0001" "joint_vel_final=-0.0001") ;;  # sim 에서만 본다. 실기 금지
      *) die "보상 실험은 R1, R2, R3, R4 중 하나입니다." ;;
    esac
    base=experiments/backup/so101_reach.with-w6-w7.py
    [[ -f "$base" ]] || die "$base 가 없습니다. scripts/apply_tasks.sh 를 먼저 실행하세요."
    cp "$base" so101_reach.py
    trap 'cp "$base" so101_reach.py; echo "so101_reach.py 를 원래 값으로 되돌렸습니다."' EXIT
    for kv in "${SET[@]}"; do set_value so101_reach.py "${kv%%=*}" "${kv#*=}"; done
    diff "$base" so101_reach.py || true
    train "reward-$NAME" --task SO101-Reach-Sphere-Reward --num_envs "$ENVS" --run_name "$NAME" "${ITER_ARGS[@]}"
    CKPT="$(record_checkpoint reach_so101_sphere_reward "reward-$NAME-checkpoint.txt")"
    goal_video "$CKPT" "$SPHERE_POINT" ;;
  export)
    # exported/ 는 마지막으로 재생한 체크포인트로 덮어써지므로, 고른 체크포인트로 짧게 한 번 재생한 뒤 복사한다
    case "${2:-sphere}" in
      sphere) CKPT="$(read_checkpoint sphere-checkpoint.txt)"; DST=06; RANGE="$SPHERE_RANGE"; P="$SPHERE_POINT" ;;
      box)    CKPT="$(read_checkpoint box-checkpoint.txt)";    DST=06; RANGE="$BOX_RANGE";    P="$BOX_POINT" ;;
      high)   CKPT="$(read_checkpoint high-checkpoint.txt)";   DST=06-high; RANGE="$HIGH_RANGE"; P="0 -0.18 0.35" ;;
      smooth) CKPT="$(read_checkpoint reward-smooth0.02-checkpoint.txt)"; DST=06-smooth; RANGE="$SPHERE_RANGE"; P="$SPHERE_POINT" ;;
      *) die "export 대상은 sphere, box, high, smooth 중 하나입니다." ;;
    esac
    GOAL="$P" play_video "$CKPT" --task SO101-Reach-Goal-Play --num_envs 1 --video --video_length 30
    export_policy "$CKPT" "$DST" "$RANGE"
    cat "${DEPLOY_DIR}/$DST/goal_range.json" ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
