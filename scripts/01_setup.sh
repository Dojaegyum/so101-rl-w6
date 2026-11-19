#!/usr/bin/env bash
# 2~6. uv 설치, 예제 clone(커밋 고정), EULA 동의, uv sync, GPU 확인
source "$(dirname "$0")/env.sh"

log "2. uv 설치"
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh -o /tmp/install-uv.sh
  sh /tmp/install-uv.sh
fi
uv --version

log "3. 예제 다운로드 (커밋 ${UPSTREAM_COMMIT:0:7} 고정)"
mkdir -p "${REPO_ROOT}/third_party"
if [[ ! -d "${UPSTREAM_DIR}/.git" ]]; then
  git clone "${UPSTREAM_URL}" "${UPSTREAM_DIR}"
fi
git -C "${UPSTREAM_DIR}" fetch --quiet origin
git -C "${UPSTREAM_DIR}" checkout --quiet "${UPSTREAM_COMMIT}"
git -C "${UPSTREAM_DIR}" lfs pull
git -C "${UPSTREAM_DIR}" rev-parse HEAD > "${UPSTREAM_DIR}/setup-commit.txt"
echo "HEAD: $(cat "${UPSTREAM_DIR}/setup-commit.txt")"

log "4. EULA 자동 동의"
if [[ ! -f "${UPSTREAM_DIR}/.env" ]]; then
  cp "${UPSTREAM_DIR}/.env.example" "${UPSTREAM_DIR}/.env"
fi
sed -i 's/^OMNI_KIT_ACCEPT_EULA=.*/OMNI_KIT_ACCEPT_EULA=YES/' "${UPSTREAM_DIR}/.env"
load_env

log "5. 설치 (첫 실행은 Isaac Sim 약 10GB 다운로드)"
cd "${EXAMPLE_DIR}"
uv sync

log "6. GPU 확인"
uv run python -c "import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available(), torch.cuda.get_device_name(0)); x=torch.ones(4,device='cuda'); print(x+x)"

echo -e "\n[완료] 다음: scripts/02_sweep.sh"
