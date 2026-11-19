"""각 학습 run 의 TensorBoard 로그에서 마지막 지표를 뽑아 Markdown 표로 출력한다.

    uv run python summarize_runs.py logs/rsl_rl            # 모든 실험
    uv run python summarize_runs.py logs/rsl_rl/reach_so101
"""

from __future__ import annotations

import sys
from pathlib import Path

from tensorboard.backend.event_processing.event_accumulator import EventAccumulator

# 앞쪽에 있을수록 먼저 보여 준다. 없는 태그는 건너뛴다.
KEY_TAGS = [
    "Metrics/ee_pose/position_error",
    "Metrics/success_rate",
    "Train/mean_reward",
    "Train/mean_episode_length",
    "Loss/value_function",
    "Loss/surrogate",
    "Perf/total_fps",
]


def summarize(run_dir: Path) -> dict[str, str]:
    acc = EventAccumulator(str(run_dir), size_guidance={"scalars": 0})
    acc.Reload()
    tags = acc.Tags().get("scalars", [])
    row = {"run": f"{run_dir.parent.name}/{run_dir.name}"}
    steps = 0
    for tag in KEY_TAGS:
        if tag in tags:
            events = acc.Scalars(tag)
            row[tag] = f"{events[-1].value:.4g}"
            steps = max(steps, events[-1].step)
    row["iterations"] = str(steps)
    row["checkpoints"] = str(len(list(run_dir.glob("model_*.pt"))))
    return row


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "logs/rsl_rl")
    runs = sorted({p.parent for p in root.rglob("events.out.tfevents.*")})
    if not runs:
        print(f"TensorBoard 로그가 있는 run 이 없습니다: {root}")
        return
    rows = [summarize(r) for r in runs]
    cols = ["run", "iterations", "checkpoints"] + [t for t in KEY_TAGS if any(t in r for r in rows)]
    print("# SO-101 Reach 학습 결과\n")
    print("| " + " | ".join(cols) + " |")
    print("|" + "---|" * len(cols))
    for r in rows:
        print("| " + " | ".join(r.get(c, "-") for c in cols) + " |")
    print("\n`Metrics/ee_pose/position_error`: 목표와 그리퍼 사이 거리(m). 03 기본 학습(512 envs x 200)은 약 0.01, 이어 학습하면 약 0.005.")
    print("보상을 바꾼 실험(06 §5-1)끼리는 Train/mean_reward 를 비교하지 않는다. position_error 로만 비교한다.")


if __name__ == "__main__":
    main()
