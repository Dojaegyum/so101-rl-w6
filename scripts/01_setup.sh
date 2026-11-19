#!/usr/bin/env bash
# 노션 02 §2~6: uv 설치, 예제 clone(커밋 고정), EULA 동의, uv sync, GPU 확인
#            + 03 §5 기준선 보존(commit.txt, so101_reach.baseline.py, *-help.txt)
source "$(dirname "$0")/env.sh"
scrub_conda

log "2. uv 설치"
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh -o /tmp/install-uv.sh
  sh /tmp/install-uv.sh
fi
uv --version

log "3. 예제 다운로드 (${UPSTREAM_DIR}, 커밋 ${UPSTREAM_COMMIT:0:7} 고정)"
mkdir -p "${ROBOTICS_DIR}"
[[ -d "${UPSTREAM_DIR}/.git" ]] || git clone "${UPSTREAM_URL}" "${UPSTREAM_DIR}"
if [[ "$(git -C "${UPSTREAM_DIR}" rev-parse HEAD)" != "${UPSTREAM_COMMIT}" ]]; then
  git -C "${UPSTREAM_DIR}" fetch --quiet origin
  git -C "${UPSTREAM_DIR}" checkout --quiet "${UPSTREAM_COMMIT}"
fi
git -C "${UPSTREAM_DIR}" lfs pull
git -C "${UPSTREAM_DIR}" rev-parse HEAD > "${UPSTREAM_DIR}/setup-commit.txt"
echo "HEAD: $(cat "${UPSTREAM_DIR}/setup-commit.txt")"

log "4. EULA 자동 동의"
[[ -f "${UPSTREAM_DIR}/.env" ]] || cp "${UPSTREAM_DIR}/.env.example" "${UPSTREAM_DIR}/.env"
sed -i 's/^OMNI_KIT_ACCEPT_EULA=.*/OMNI_KIT_ACCEPT_EULA=YES/' "${UPSTREAM_DIR}/.env"

log "5. 설치 (첫 실행은 Isaac Sim 약 10GB 다운로드)"
cd "${WORK}"
uv sync

log "6. GPU 확인"
SKIP_GPU_CHECK=1 start_isaac_lab
uv run python -c "import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available(), torch.cuda.get_device_name(0)); x=torch.ones(4,device='cuda'); print(x+x)"

log "03 §5 기준선 보존"
git -C "${UPSTREAM_DIR}" rev-parse HEAD > experiments/commit.txt
uv run isaaclab train --task SO101-Reach --help > experiments/train-help.txt
uv run isaaclab play --task SO101-Reach --help > experiments/play-help.txt
ls experiments experiments/backup

echo -e "\n[완료] 다음: scripts/02_sweep.sh"
