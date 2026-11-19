#!/usr/bin/env bash
# TensorBoard (노션 03 §7, 06 §3). 모든 실험(logs/rsl_rl/*)을 겹쳐 본다.
#   scripts/tensorboard.sh            http://127.0.0.1:6006 (데스크탑에서 직접 볼 때)
#   scripts/tensorboard.sh --remote   0.0.0.0 으로 열기 (노트북 브라우저에서 http://<데스크탑IP>:6006)
# 원격이면 SSH 터널도 된다: ssh -L 6006:127.0.0.1:6006 <user>@<desktop> 후 노트북에서 http://localhost:6006
source "$(dirname "$0")/env.sh"
SKIP_GPU_CHECK=1 start_isaac_lab
host=127.0.0.1; [[ "${1:-}" == "--remote" ]] && host=0.0.0.0
uv run --with tensorboard tensorboard --logdir logs/rsl_rl --host "$host" --port "${PORT:-6006}"
