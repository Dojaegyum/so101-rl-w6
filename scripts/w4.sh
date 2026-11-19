#!/usr/bin/env bash
# 노션 04 정책 재생·내보내기 (ONNX). 기본 체크포인트(experiments/basic-checkpoint.txt)를 쓴다.
#   scripts/w4.sh viz      §2 창 띄워 재생 (모니터 필요, 16 envs)
#   scripts/w4.sh video    §3 영상 녹화 (창 없이, 360 step = 12초). 재생하면 exported/ 에 ONNX 가 생긴다
#   scripts/w4.sh export   §4 exported/ 의 policy.onnx* · policy.pt 를 ~/robotics/so101-deploy/ 로 복사
#   scripts/w4.sh check    §6 Isaac 없이 ONNX 확인 (check_onnx.py, onnxruntime 은 임시로 붙여 실행)
#   scripts/w4.sh all      video → export → check
source "$(dirname "$0")/env.sh"
start_isaac_lab
CKPT="$(read_checkpoint basic-checkpoint.txt)"
echo "기본 체크포인트: $CKPT"

check_onnx() {  # check_onnx <배포 폴더>
  cp "${REPO_ROOT}/tools/check_onnx.py" "$1/"
  # 노션은 conda env lerobot 에서 실행한다. 데스크탑에는 lerobot 이 없을 수 있어 Isaac 환경에 onnx 도구를 임시로 붙인다.
  (cd "$1" && uv run --project "${WORK}" --no-sync --with onnxruntime python check_onnx.py --onnx policy.onnx --jit policy.pt)
}

case "${1:-}" in
  viz)    uv run isaaclab play --task SO101-Reach --num_envs 16 --checkpoint "$CKPT" --viz kit ;;
  video)  play_video "$CKPT" --task SO101-Reach --num_envs 16 --video --video_length 360 ;;
  export) export_policy "$CKPT" "" '{"shape": "box", "x": [-0.10, 0.10], "y": [-0.30, -0.15], "z": [0.10, 0.30]}' ;;
  check)  check_onnx "${DEPLOY_DIR}" ;;
  all)    "$0" video; "$0" export; "$0" check ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
