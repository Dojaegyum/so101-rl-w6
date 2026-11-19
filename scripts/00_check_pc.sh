#!/usr/bin/env bash
# 1. PC 확인: x86_64, RTX GPU, 드라이버 580 이상, 디스크 30GB 이상
set -uo pipefail
fail=0

echo "--- OS ---"; grep -E '^(NAME|VERSION)=' /etc/os-release
arch="$(uname -m)"; echo "arch: ${arch}"
[[ "${arch}" == "x86_64" ]] || { echo "[실패] x86_64 가 아닙니다."; fail=1; }

echo "--- GPU ---"
if ! command -v nvidia-smi >/dev/null; then
  echo "[실패] nvidia-smi 가 없습니다. NVIDIA 드라이버를 설치하세요."; fail=1
else
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
  drv="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)"
  major="${drv%%.*}"
  if (( major < 580 )); then
    echo "[실패] 드라이버 ${drv} < 580. torch 2.11(CUDA 13.0)이 동작하지 않습니다."; fail=1
  fi
  name="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
  if [[ "${name}" =~ (A100|H100|H200|V100) ]]; then
    echo "[경고] ${name} 는 RT 코어가 없어 Isaac Sim 렌더링(--viz kit, --video)이 안 될 수 있습니다."
  fi
fi

echo "--- 디스크 (${HOME}) ---"; df -h "${HOME}"
avail_gb="$(df -BG --output=avail "${HOME}" | tail -1 | tr -dc '0-9')"
if (( avail_gb < 30 )); then echo "[실패] 여유 공간 ${avail_gb}GB < 30GB"; fail=1
elif (( avail_gb < 50 )); then echo "[경고] 여유 공간 ${avail_gb}GB. 로그·체크포인트까지 고려하면 50GB 권장"; fi

echo "--- RAM ---"; free -h | head -2

echo "--- git-lfs ---"
git lfs version >/dev/null 2>&1 || { echo "[실패] git-lfs 가 없습니다: sudo apt install git-lfs"; fail=1; }

(( fail == 0 )) && echo -e "\n[통과] 다음: scripts/01_setup.sh" || { echo -e "\n[중단] 위 실패 항목을 해결하세요."; exit 1; }
