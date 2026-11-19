# 모든 스크립트가 source 하는 공통 설정. 직접 실행하지 않는다.
# 경로는 노션 문서와 같다: ~/robotics/isaaclab-so101/examples/isaaclab (작업 폴더), ~/robotics/so101-deploy
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROBOTICS_DIR="${ROBOTICS_DIR:-$HOME/robotics}"
UPSTREAM_URL="https://github.com/art-e-fact/isaaclab-so101.git"
UPSTREAM_COMMIT="0284f4a2c31fd86282c58914a524595e6b71e3e7"   # 노션 00 §3 버전 고정
UPSTREAM_DIR="${ROBOTICS_DIR}/isaaclab-so101"
WORK="${UPSTREAM_DIR}/examples/isaaclab"                      # 노션의 "작업 폴더"
DEPLOY_DIR="${ROBOTICS_DIR}/so101-deploy"
RESULTS_DIR="${REPO_ROOT}/results"

command -v uv >/dev/null || export PATH="${HOME}/.local/bin:${PATH}"

# conda 환경이 섞이지 않게 한다. 노션의 `while conda deactivate` 반복문은 conda init 이 안 된
# 셸에서 끝나지 않으므로, 스크립트 안에서는 conda 변수와 PATH 항목을 직접 지운다.
scrub_conda() {
  if [[ -n "${CONDA_PREFIX:-}" ]]; then
    local clean="" p
    IFS=: read -ra parts <<< "${PATH}"
    for p in "${parts[@]}"; do [[ "$p" == *conda* || "$p" == *miniforge* || "$p" == *mamba* ]] || clean+="${clean:+:}$p"; done
    export PATH="$clean"
  fi
  unset CONDA_PREFIX CONDA_DEFAULT_ENV CONDA_SHLVL CONDA_PYTHON_EXE CONDA_EXE VIRTUAL_ENV PYTHONPATH || true
}

log() { echo -e "\n=== $* ==="; }
die() { echo "[오류] $*" >&2; exit 1; }

# 노션 03의 "학습 환경 켜기"와 같다: conda 끄기 → 작업 폴더 → .env → GPU 확인
start_isaac_lab() {
  scrub_conda
  command -v uv >/dev/null || die "uv가 없습니다. scripts/01_setup.sh 를 먼저 실행하세요."
  cd "${WORK}" 2>/dev/null || die "작업 폴더가 없습니다: ${WORK}. scripts/01_setup.sh 를 먼저 실행하세요."
  [[ -x .venv/bin/python && -f ../../.env ]] || die "uv sync 와 .env 설정을 확인하세요 (scripts/01_setup.sh)."
  set -a; source ../../.env; set +a
  if [[ "${SKIP_GPU_CHECK:-0}" != "1" ]]; then
    uv run --no-sync python -c 'import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)' \
      || die "CUDA를 쓸 수 없습니다. nvidia-smi 와 드라이버(580 이상)를 확인하세요."
  fi
  mkdir -p experiments/backup
  # 03 §5: 수정 전 원본 보관 (고정 커밋의 원본을 그대로 꺼낸다)
  [[ -f experiments/backup/so101_reach.baseline.py ]] \
    || git -C "${UPSTREAM_DIR}" show HEAD:examples/isaaclab/so101_reach.py > experiments/backup/so101_reach.baseline.py
}

# 학습 한 번 = logs/rsl_rl/<실험>/<날짜_시각>[_run_name]/ 폴더 하나
latest_run_dir() { ls -td "logs/rsl_rl/$1"/*/ 2>/dev/null | head -n 1; }

# 가장 최근 run 의 마지막 체크포인트 전체 경로를 experiments/<파일> 에 적는다 (노션 03 §4 방식)
record_checkpoint() {
  local exp="$1" out="$2" run ckpt
  run="$(latest_run_dir "$exp")"; [[ -n "$run" ]] || die "logs/rsl_rl/$exp 에 학습 결과가 없습니다."
  ckpt="$(ls -v "${run}"model_*.pt 2>/dev/null | tail -n 1)"; [[ -n "$ckpt" ]] || die "${run} 에 model_*.pt 가 없습니다."
  realpath "$ckpt" | tee "experiments/$out"
}

read_checkpoint() {
  local f="experiments/$1"
  [[ -s "$f" ]] || die "$f 가 없습니다. 해당 학습 단계를 먼저 실행하세요."
  local ckpt; ckpt="$(cat "$f")"; [[ -f "$ckpt" ]] || die "$f 에 적힌 체크포인트가 없습니다: $ckpt"
  echo "$ckpt"
}

train() {  # train <로그파일 이름> <isaaclab train 인자...>
  local logname="$1"; shift
  log "isaaclab train $*"
  local rc
  set +e; uv run isaaclab train "$@" 2>&1 | tee "experiments/${logname}.log"; rc="${PIPESTATUS[0]}"; set -e
  # isaaclab train 은 Python 오류로 죽어도 종료 코드 0 을 돌려줄 때가 있어 로그도 확인한다
  if [[ "$rc" != 0 ]] || grep -q '^Traceback (most recent call last)' "experiments/${logname}.log"; then
    tail -n 25 "experiments/${logname}.log" >&2
    die "학습이 실패했습니다 (위 마지막 25줄). 전체: ${WORK}/experiments/${logname}.log"
  fi
}

# 영상 재생: isaaclab play --video 는 녹화 후에도 스스로 끝나지 않을 수 있다(노션 04 §3).
# 새 mp4 가 생기고 크기가 멈추면 프로세스를 끝낸다. 재생할 때 exported/ 의 ONNX 도 다시 만들어진다.
play_video() {  # play_video <체크포인트> <isaaclab play 인자...>
  local ckpt="$1"; shift
  local vdir; vdir="$(dirname "$ckpt")/videos/play"
  local marker; marker="$(mktemp)"
  log "isaaclab play --checkpoint $ckpt $* (GOAL=${GOAL:-없음})"
  setsid uv run isaaclab play --checkpoint "$ckpt" "$@" > "experiments/play-last.log" 2>&1 &
  local pid=$! waited=0 video="" last=-1 size stable=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 5; waited=$((waited + 5))
    video="$(find "$vdir" -name '*.mp4' -newer "$marker" 2>/dev/null | head -n 1 || true)"
    if [[ -n "$video" ]]; then
      size="$(stat -c %s "$video")"
      if [[ "$size" == "$last" && "$size" -gt 0 ]]; then stable=$((stable + 1)); else stable=0; fi
      last="$size"
      (( stable >= 2 )) && break
    fi
    (( waited < ${PLAY_TIMEOUT:-1200} )) || { echo "[경고] ${waited}초 동안 영상이 완성되지 않았습니다." >&2; break; }
  done
  kill -INT -- "-$pid" 2>/dev/null || true; sleep 3; kill -KILL -- "-$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$marker"
  [[ -n "$video" ]] || die "영상이 만들어지지 않았습니다. experiments/play-last.log 를 보세요."
  echo "영상: $video"
  echo "$video" >> experiments/videos.txt
}

# exported/ 의 ONNX 를 배포 폴더로 복사한다 (노션 04 §4, 06 §6)
export_policy() {  # export_policy <체크포인트> <배포 하위 폴더('' 이면 so101-deploy 바로 아래)> [goal_range json]
  local ckpt="$1" sub="$2" range="${3:-}" dst="${DEPLOY_DIR}${2:+/$2}"
  local exp; exp="$(dirname "$ckpt")/exported"
  [[ -f "$exp/policy.onnx" ]] || die "$exp/policy.onnx 가 없습니다. 먼저 이 체크포인트로 재생하세요."
  mkdir -p "$dst"
  cp "$exp"/policy.onnx* "$exp"/policy.pt "$dst"/
  echo "$ckpt" > "$dst/policy_source.txt"
  [[ -n "$range" ]] && echo "$range" > "$dst/goal_range.json"
  ls -la "$dst"
}

# 파이썬 dict 의 한 줄 값을 바꾼다: set_value <파일> <키> <값>  (REWARD, DR 실험용)
set_value() { uv run --no-sync python "${REPO_ROOT}/tools/set_value.py" "$@"; }
