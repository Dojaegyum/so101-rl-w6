# SO-101 강화학습 실습 (W6) — GPU 데스크탑 실행용

SO-101 팔이 그리퍼를 무작위 목표점에 갖다 대도록 Isaac Lab의 `SO101-Reach` 과제를 PPO(rsl_rl)로 학습한다.
예제 코드는 [art-e-fact/isaaclab-so101](https://github.com/art-e-fact/isaaclab-so101) 커밋 `0284f4a`로 고정해 `third_party/`에 받는다.
이 레포에는 설치·학습·결과 수집 스크립트만 있다.

## 필요 사양

| 항목 | 조건 |
|---|---|
| OS | Linux x86_64 (Ubuntu 22.04/24.04 권장) |
| GPU | RT 코어가 있는 NVIDIA RTX 계열 (RTX 30/40/50, L4, L40S). A100/H100은 렌더링 불가 |
| 드라이버 | 580 이상 (torch 2.11, CUDA 13.0) |
| 디스크 | 30GB 이상, 50GB 권장 |
| RAM | 학습 약 4GB + env당 0.2MB, `--viz` 사용 시 약 6GB 추가 |
| 기타 | `git`, `git-lfs`, `curl` |

## 실행 순서

```bash
git clone <이 레포 URL> so101-rl-w6 && cd so101-rl-w6
conda deactivate 2>/dev/null || true    # conda 환경이 켜져 있으면 끈다

scripts/00_check_pc.sh       # 1. PC 확인
scripts/01_setup.sh          # 2~6. uv 설치, 예제 clone, EULA 동의, uv sync(약 10GB), GPU 확인
scripts/02_sweep.sh          # 7. 헤드리스 관절 검사 → results/sweep/
scripts/02_sweep.sh --viz    #    (선택) Isaac Sim 창으로 확인. 첫 실행은 셰이더 컴파일로 수 분간 무출력

scripts/03_train.sh s1       # 64 envs  x 200 iter   동작 확인
scripts/03_train.sh s2       # 512 envs x 200 iter
scripts/03_train.sh s3       # 512 envs x 1600 iter  본 학습
scripts/04_play.sh           # 가장 최근 run을 12초 영상으로 기록
scripts/05_collect.sh        # 지표 요약(results/summary.md) + 로그·영상 tar.gz
```

- 각 단계는 다시 실행해도 안전하다. 이미 받은 것은 건너뛴다.
- 패키지 기본값(4096 envs x 200 iter, RTX 5070 Ti 약 2분)은 `scripts/03_train.sh default`로 실행한다.
- 원하는 값으로 실행: `NUM_ENVS=1024 MAX_ITER=400 scripts/03_train.sh custom`
- 추가 인자는 `isaaclab train`에 그대로 넘어간다. 예: `scripts/03_train.sh s1 --seed 1`
- 특정 run 재생: `scripts/04_play.sh <run 폴더명>`, 창으로 보기: `scripts/04_play.sh --viz`

## 결과 확인

- 로그·체크포인트: `third_party/isaaclab-so101/examples/isaaclab/logs/rsl_rl/reach_so101/<날짜>_<단계>/`
- TensorBoard:
  ```bash
  cd third_party/isaaclab-so101/examples/isaaclab
  uv run tensorboard --logdir logs/rsl_rl/reach_so101 --bind_all   # 노트북 브라우저에서 http://<데스크탑IP>:6006
  ```
- 핵심 지표 `Metrics/ee_pose/position_error`: 목표와 그리퍼 사이 거리(m). 기본 설정에서 약 0.004(4 mm)까지 내려가면 정상이다.
- 결과를 노트북으로 옮기기: `scp <user>@<desktop>:<경로>/results/so101_reach_*.tar.gz .`
- `results/summary.md`는 커밋해서 run별 비교 기록으로 남길 수 있다.

## 원격(SSH) 데스크탑에서 실행할 때

학습은 화면 없이 돌기 때문에 SSH로 충분하다. 연결이 끊겨도 학습이 계속되도록 `tmux`를 쓴다.

```bash
tmux new -s rl
scripts/03_train.sh s3
# Ctrl+b d 로 빠져나오고, 나중에 tmux attach -t rl
```

`--viz` 옵션은 데스크탑에 모니터가 연결돼 있어야 한다.

## 파일 구성

| 파일 | 역할 |
|---|---|
| `scripts/env.sh` | 공통 설정: 고정 커밋, 경로, conda 확인, `.env` 로드 |
| `scripts/00_check_pc.sh` | OS·GPU·드라이버·디스크·git-lfs 확인 |
| `scripts/01_setup.sh` | uv 설치, 예제 clone, EULA, `uv sync`, CUDA 확인 |
| `scripts/02_sweep.sh` | 관절 sweep 검사 |
| `scripts/03_train.sh` | 단계별 PPO 학습 |
| `scripts/04_play.sh` | 정책 재생·영상 기록 |
| `scripts/05_collect.sh` | 결과 요약과 압축 |
| `scripts/summarize_runs.py` | TensorBoard 로그에서 마지막 지표를 표로 출력 |
