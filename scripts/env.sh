# 모든 스크립트가 source 하는 공통 설정. 직접 실행하지 않는다.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="https://github.com/art-e-fact/isaaclab-so101.git"
UPSTREAM_COMMIT="0284f4a2c31fd86282c58914a524595e6b71e3e7"   # 실습생마다 같은 결과가 나오도록 고정
UPSTREAM_DIR="${REPO_ROOT}/third_party/isaaclab-so101"
EXAMPLE_DIR="${UPSTREAM_DIR}/examples/isaaclab"
RESULTS_DIR="${REPO_ROOT}/results"
TASK="SO101-Reach"

export PATH="${HOME}/.local/bin:${PATH}"

# conda 환경이 켜져 있으면 uv 환경과 섞인다.
if [[ -n "${CONDA_PREFIX:-}" ]]; then
  echo "[경고] conda 환경(${CONDA_DEFAULT_ENV:-?})이 켜져 있습니다. 'conda deactivate' 후 다시 실행하세요." >&2
  exit 1
fi

load_env() {
  if [[ ! -f "${UPSTREAM_DIR}/.env" ]]; then
    echo "[오류] ${UPSTREAM_DIR}/.env 가 없습니다. 먼저 scripts/01_setup.sh 를 실행하세요." >&2
    exit 1
  fi
  set -a; source "${UPSTREAM_DIR}/.env"; set +a
}

log() { echo -e "\n=== $* ==="; }
