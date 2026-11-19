"""내보낸 Reach 정책(policy.onnx)을 Isaac 없이 확인한다.

    python check_onnx.py --onnx policy.onnx
    python check_onnx.py --onnx policy.onnx --jit policy.pt   # TorchScript 파일과 출력 비교
"""

import argparse
import time

import numpy as np
import onnxruntime as ort

OBS_DIM = 24  # 관절 위치 6 + 관절 속도 6 + 목표 7 + 직전 행동 5
ACT_DIM = 5  # 팔 관절 5개

parser = argparse.ArgumentParser()
parser.add_argument("--onnx", required=True)
parser.add_argument("--jit", help="같은 체크포인트의 policy.pt (선택)")
args = parser.parse_args()

sess = ort.InferenceSession(args.onnx, providers=["CPUExecutionProvider"])
inp, out = sess.get_inputs()[0], sess.get_outputs()[0]
print(f"입력: {inp.name} {inp.shape}")
print(f"출력: {out.name} {out.shape}")
assert inp.shape[-1] == OBS_DIM, f"관측 크기가 {OBS_DIM}이 아니다: {inp.shape}"
assert out.shape[-1] == ACT_DIM, f"행동 크기가 {ACT_DIM}가 아니다: {out.shape}"

# home 자세에서 가만히 있고, 목표가 작업 범위 한가운데일 때의 관측
obs = np.zeros((1, OBS_DIM), dtype=np.float32)
obs[0, 12:19] = [0.0, -0.22, 0.20, 0.0, 0.0, 0.0, 1.0]  # 목표 위치 xyz + 방향(x, y, z, w)
action = sess.run([out.name], {inp.name: obs})[0]
print("home 자세, 목표 (0, -0.22, 0.20)일 때 행동:", np.round(action[0], 3))
assert np.isfinite(action).all(), "행동에 NaN/inf가 있다"

start = time.perf_counter()
for _ in range(1000):
    sess.run([out.name], {inp.name: obs})
ms = (time.perf_counter() - start) * 1000 / 1000  # 총 시간(ms) ÷ 1000회
print(f"추론 1회 평균 {ms:.3f} ms (30Hz 제어의 한 주기는 33 ms)")

if args.jit:
    import torch

    jit = torch.jit.load(args.jit, map_location="cpu")
    rng = np.random.default_rng(0)
    worst = 0.0
    for _ in range(100):
        x = rng.uniform(-1, 1, size=(1, OBS_DIM)).astype(np.float32)
        a_onnx = sess.run([out.name], {inp.name: x})[0]
        a_jit = jit(torch.from_numpy(x)).detach().numpy()
        worst = max(worst, float(np.abs(a_onnx - a_jit).max()))
    print(f"ONNX와 TorchScript 출력의 최대 차이: {worst:.2e}")
    assert worst < 1e-4, "두 파일의 출력이 다르다. 같은 체크포인트에서 내보낸 파일인지 확인한다"

print("OK")
