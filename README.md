# SO-101 강화학습 실습 W3~W7 — GPU 데스크탑 실행용

노션 실습 문서(W0~W7)의 **시뮬레이션 부분**을 스크립트로 옮긴 레포다. GPU 데스크탑에서 clone해 실행한다.

| 노션 | 내용 | 이 레포 |
|---|---|---|
| 02 | Isaac Lab 설치 | `scripts/00_check_pc.sh`, `01_setup.sh`, `02_sweep.sh` |
| 03 (W3) | Reach PPO 학습 | `scripts/w3.sh` |
| 04 (W4) | 재생·ONNX 내보내기 | `scripts/w4.sh` |
| 05 (W5) | 실기 배포 | **제외**. 팔과 실기 도구 ZIP이 필요하다. 노트북에서 한다 |
| 06 (W6) | 목표 범위 설계 (상자·구·높이·보상) | `tasks/w6_w7_tasks.py`, `scripts/w6.sh` |
| 07 (W7) | 도메인 랜덤화 | `tasks/w6_w7_tasks.py`, `scripts/w7.sh` |

경로는 노션과 같다. 예제는 `~/robotics/isaaclab-so101`(커밋 `0284f4a` 고정)에 받고, ONNX는 `~/robotics/so101-deploy/`에 모은다.
`ROBOTICS_DIR=/다른/경로`로 바꿀 수 있다.

## 필요 사양

| 항목 | 조건 |
|---|---|
| OS | Ubuntu 22.04/24.04 x86_64 |
| GPU | NVIDIA RTX (노션 기준 RTX 5080 16GB, 4070 Ti 12GB도 가능). A100/H100은 렌더링 불가 |
| 드라이버 | 580 이상 |
| 디스크 | 30GB 이상, 50GB 권장 |
| 기타 | `git`, `git-lfs`, `curl`, `tmux`(권장) |

## 빠른 시작

```bash
git clone https://github.com/Dojaegyum/so101-rl-w6.git && cd so101-rl-w6
scripts/00_check_pc.sh      # GPU·드라이버·디스크 확인
scripts/01_setup.sh         # uv, 예제 clone, EULA, uv sync(약 10GB), GPU 확인, 기준선 보존
scripts/02_sweep.sh         # 관절 검사 (헤드리스, results/sweep/)

tmux new -s rl
scripts/run_all.sh          # 03 → 04 → 06 → 07 필수 단계를 순서대로. Ctrl+b d 로 빠져나온다
```

- `scripts/run_all.sh --all`: 선택 단계까지 돌린다. 03 이어 학습·실습 A~E, 06 높이 뻗기·보상 R1~R4가 들어간다.
- `scripts/run_all.sh --from w6`: 중간 단계부터 다시 시작한다.
- 각 장은 소규모 시험(64 envs × 10)을 먼저 돌려 설정 오류를 일찍 잡는다.
- 끝나면 `results/summary.md`(run별 마지막 지표)와 `results/so101_results_*.tar.gz`가 생긴다.

conda 환경이 켜져 있어도 된다. 스크립트가 안에서 conda 변수를 지우고 실행한다.

## 장별로 하나씩 실행

```bash
# 03 Reach 학습
scripts/w3.sh smoke          # §3 64 envs × 10
scripts/w3.sh basic          # §4 512 envs × 200 → experiments/basic-checkpoint.txt (5080 약 1.4분)
scripts/w3.sh resume         # §6 (선택) 200 iterations 이어 학습
scripts/w3.sh exp A          # §9 (선택) A: envs 512/2048  B: seed 1~3  C: fine 0.2  D: scale 0.25  E: pos_z 넓히기

# 04 재생·ONNX
scripts/w4.sh video          # §3 12초 영상 (창 없이)
scripts/w4.sh export         # §4 ~/robotics/so101-deploy/ 로 복사
scripts/w4.sh check          # §6 check_onnx.py (입력 24, 출력 5, ONNX = TorchScript)
scripts/w4.sh viz            # §2 창으로 보기 (모니터 필요)

# 06 목표 범위 설계
scripts/apply_tasks.sh       # §2·§5·§5-1 + 07 과제를 so101_reach.py 에 등록 (몇 번 실행해도 안전)
scripts/w6.sh smoke          # §3 64 envs × 10
scripts/w6.sh limit          # §0 기본 정책으로 상자 점·구 점 영상
scripts/w6.sh box            # §3 상자 2048 envs × 600 (5080 10~15분 추정)
scripts/w6.sh box-video      # §4 상자 점 (0.17, -0.15, 0.12). GOAL="x y z" 로 다른 점
scripts/w6.sh sphere         # §5 구 학습
scripts/w6.sh sphere-video   # §5 구 점 (0, -0.32, 0.18)
scripts/w6.sh high           # §5 (선택) 위로 높이 뻗기 + 높은 점 두 개 영상
scripts/w6.sh reward R1      # §5-1 R1 fine 0.3 / R2 track -0.5 / R3 smooth -0.02 / R4 벌점 끄기(sim 전용)
scripts/w6.sh export sphere  # §6 → ~/robotics/so101-deploy/06/ (box, high, smooth 도 가능)

# 07 도메인 랜덤화
scripts/w7.sh check          # §2 Isaac Lab 기능·과제 등록 확인, DR 값 출력
scripts/w7.sh smoke          # §3 64 envs × 10
scripts/w7.sh train          # §4 DR 정책 B 2048 envs × 600
scripts/w7.sh compare        # §5 DR 환경에서 A(06 구)·B(07 DR) 영상
scripts/w7.sh export         # §6 → ~/robotics/so101-deploy/07/
scripts/w7.sh tune 'gain_scale=(0.85, 1.15)' --run_name dr_weak   # §8 값 바꿔 다시 학습
```

- GPU 메모리가 부족하면 `NUM_ENVS=1024 scripts/w6.sh sphere`처럼 줄인다(부록 A).
- 반복 횟수는 `MAX_ITER=400`으로 바꾼다.
- 학습 로그는 작업 폴더의 `experiments/*.log`에 남는다. 체크포인트 경로는 `experiments/*-checkpoint.txt`에 적힌다(노션과 같은 이름).
- 영상은 녹화가 끝나면 자동으로 종료한다. 노션처럼 Ctrl+C를 누르지 않아도 된다. 영상 경로는 `experiments/videos.txt`에 쌓인다.

## 결과 보기

```bash
scripts/tensorboard.sh            # 데스크탑에서 http://127.0.0.1:6006
scripts/tensorboard.sh --remote   # 노트북 브라우저에서 http://<데스크탑IP>:6006
scripts/collect.sh                # results/summary.md + tar.gz
```

비교는 `Metrics/ee_pose/position_error`로 한다. 보상을 바꾼 실험끼리는 `Train/mean_reward`를 비교하지 않는다(06 §5-1).

## 실기(05, 06 §7, 07 §7)는 노트북에서

`scripts/collect.sh`가 만든 tar.gz를 팔이 연결된 노트북으로 옮겨 `so101-deploy`만 푼다.

```bash
scp <user>@<desktop>:~/so101-rl-w6/results/so101_results_*.tar.gz .
mkdir -p ~/robotics && tar -xzf so101_results_*.tar.gz -C ~/robotics so101-deploy
```

이후 노션 05의 실기 도구 ZIP으로 `mock` → `check` → `live` 순서로 진행한다. 이때 정책 파일은 아래에 있다.

| 폴더 | 정책 |
|---|---|
| `so101-deploy/` | 04 기본 정책 |
| `so101-deploy/06/` | 06 구(또는 상자) 정책 |
| `so101-deploy/07/` | 07 DR 정책 |

## 노션과 다른 점

| 항목 | 노션 | 이 레포 | 이유 |
|---|---|---|---|
| 07 §3 DR 코드 | 토글 안 코드 | **새로 작성** (`tasks/w6_w7_tasks.py` 끝) | 노션 내보내기에 토글 내용이 빠져 있었다. 07 §1 표의 값과 Isaac Lab 3.0.0 API로 다시 썼다 |
| 06 코드 덧붙이기 | `cat >>` 블록 4개 | `apply_tasks.sh`가 원본에서 다시 만든다 | 두 번 붙여 넣어 생기는 `Cannot re-register id` 오류가 나지 않는다 |
| 보상·DR 값 바꾸기 | `sed` 또는 VS Code | `tools/set_value.py` (튜플 값도 처리) | 실험이 끝나면 자동으로 원래 값으로 되돌린다 |
| 04 §6 check_onnx | conda env `lerobot` | Isaac 환경 + 임시 onnxruntime | 데스크탑에는 lerobot이 없을 수 있다 |
| "학습 환경 켜기" 블록 | `while conda deactivate` 반복 | conda 변수를 직접 지운다 | conda init이 안 된 셸에서는 노션의 반복문이 끝나지 않는다 |
| 학습 실패 판단 | 눈으로 확인 | 종료 코드 + 로그의 `Traceback` | `isaaclab train`은 Python 오류로 죽어도 종료 코드 0을 낼 때가 있다 |

### 07 DR 구현 (검증 필요)

| 노션 07 §1 설정 | 구현 |
|---|---|
| `joint_pos_bias` ±0.03, `joint_pos_noise` ±0.01 | `NoiseModelWithAdditiveBiasCfg`. bias는 reset 때 관절마다 새로 뽑는다 |
| `joint_vel_noise` ±0.1 | 관절 속도 관측의 `UniformNoiseCfg` |
| `obs_delay_max` 1 | 관절 위치·속도 관측의 `delay_max_lag`. 목표와 직전 행동은 지연하지 않는다 |
| `mass_scale` ×0.8~1.2 | `randomize_rigid_body_mass` (startup, scale) |
| `gain_scale` ×0.7~1.3 | `randomize_actuator_gains` 강성·감쇠 (startup, scale) |
| `joint_friction` 꺼짐 | `randomize_joint_parameters` (startup, abs). `(0.0, 0.0)`이면 등록하지 않는다 |

로컬(GPU 없음)에서 확인한 것은 여기까지다.
- 과제 7개가 모두 등록된다.
- 설정 객체가 만들어지고 값이 의도대로 들어간다.
- 스크립트 흐름(체크포인트 기록, 영상 대기, ONNX 복사, 원래 값 복원)은 가짜 학습 명령으로 시험했다.

실제 학습은 GPU가 있어야 해서 돌려 보지 못했다. 데스크탑에서 `scripts/w7.sh smoke`가 처음 실제로 확인하는 단계다.

## 파일 구성

| 파일 | 역할 |
|---|---|
| `tasks/w6_w7_tasks.py` | 06(상자·재생·구·높이·보상) 노션 원문 + 07 DR 과제 |
| `scripts/env.sh` | 공통: 경로, conda 정리, 학습·재생·내보내기 함수 |
| `scripts/apply_tasks.sh` | 원본 `so101_reach.py`에 과제 덧붙이기 / `--reset`으로 원본 복원 |
| `scripts/w3.sh` `w4.sh` `w6.sh` `w7.sh` | 장별 실행 |
| `scripts/run_all.sh` | 전체 순서 실행 |
| `scripts/tensorboard.sh` `collect.sh` | 결과 보기·수집 |
| `tools/check_onnx.py` | 노션 04 §6 원문 |
| `tools/set_value.py` | REWARD·DR dict 값 바꾸기 |
| `tools/summarize_runs.py` | TensorBoard 로그 → Markdown 표 |
