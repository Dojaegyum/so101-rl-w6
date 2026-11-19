# W6·W7 실습 과제. scripts/apply_tasks.sh 가 원본 so101_reach.py 끝에 이 파일을 덧붙인다.
# 06 부분은 노션 W6 문서의 cat >> 블록을 순서대로 그대로 옮겼다. 07 부분만 새로 작성했다.

# ===== 06: 목표 범위를 내가 정한 과제 =====
import os

@configclass
class SO101ReachWideEnvCfg(SO101ReachEnvCfg):
    def __post_init__(self) -> None:
        super().__post_init__()  # 기본 과제 설정을 그대로 가져온다
        ranges = self.commands.ee_pose.ranges
        ranges.pos_x = (-0.20, 0.20)   # 좌우 ±20cm (기본 ±10cm)
        ranges.pos_y = (-0.30, -0.10)  # 앞 10~30cm (기본 15~30cm)
        ranges.pos_z = (0.05, 0.30)    # 높이 5~30cm (기본 10~30cm)

@configclass
class SO101ReachGoalPlayEnvCfg(SO101ReachWideEnvCfg):
    """재생용: GOAL="x y z" 환경 변수의 한 점으로 목표를 고정한다."""

    def __post_init__(self) -> None:
        super().__post_init__()
        x, y, z = (float(v) for v in os.environ.get("GOAL", "0 -0.22 0.20").split())
        ranges = self.commands.ee_pose.ranges
        ranges.pos_x, ranges.pos_y, ranges.pos_z = (x, x), (y, y), (z, z)

@configclass
class SO101ReachWidePPORunnerCfg(SO101ReachPPORunnerCfg):
    experiment_name = "reach_so101_wide"  # 로그를 logs/rsl_rl/reach_so101_wide/ 에 따로 저장
    max_iterations = 600                  # 범위가 넓어진 만큼 더 오래 배운다

gym.register(
    id="SO101-Reach-Wide",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    disable_env_checker=True,
    kwargs={
        "env_cfg_entry_point": f"{__name__}:SO101ReachWideEnvCfg",
        "rsl_rl_cfg_entry_point": f"{__name__}:SO101ReachWidePPORunnerCfg",
        "default_agent": "rsl_rl",
    },
)
gym.register(
    id="SO101-Reach-Goal-Play",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    disable_env_checker=True,
    kwargs={
        "env_cfg_entry_point": f"{__name__}:SO101ReachGoalPlayEnvCfg",
        "rsl_rl_cfg_entry_point": f"{__name__}:SO101ReachWidePPORunnerCfg",
        "default_agent": "rsl_rl",
    },
)


# ===== 06-5: 구 안에서 목표를 뽑는 과제 =====
import torch

class SphereGoalCommand(mdp.UniformPoseCommand):
    CENTER = (0.0, -0.20, 0.18)  # 구의 중심 (베이스 기준 m)
    RADIUS = 0.15                # 반지름 (m)
    MIN_Z = 0.05                 # 테이블에 너무 가까운 점은 이 높이로 올린다

    def _resample_command(self, env_ids):
        super()._resample_command(env_ids)  # 방향 부분은 원래대로 만든다
        n = self.pose_command_b[env_ids].shape[0]
        d = torch.randn(n, 3, device=self.device)
        d = d / d.norm(dim=1, keepdim=True)                                  # 무작위 방향
        r = self.RADIUS * torch.rand(n, 1, device=self.device) ** (1 / 3)   # 구 안에 고르게
        p = torch.tensor(self.CENTER, device=self.device) + d * r
        p[:, 2] = p[:, 2].clamp(min=self.MIN_Z)
        self.pose_command_b[env_ids, :3] = p

@configclass
class SO101ReachSphereEnvCfg(SO101ReachEnvCfg):
    def __post_init__(self) -> None:
        super().__post_init__()
        self.commands.ee_pose.class_type = SphereGoalCommand  # 목표 생성기를 바꿔 끼운다

@configclass
class SO101ReachSpherePPORunnerCfg(SO101ReachPPORunnerCfg):
    experiment_name = "reach_so101_sphere"
    max_iterations = 600

gym.register(
    id="SO101-Reach-Sphere",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    disable_env_checker=True,
    kwargs={
        "env_cfg_entry_point": f"{__name__}:SO101ReachSphereEnvCfg",
        "rsl_rl_cfg_entry_point": f"{__name__}:SO101ReachSpherePPORunnerCfg",
        "default_agent": "rsl_rl",
    },
)


# ===== 06-5 선택: 위로 높이 뻗기 =====
class HighSphereGoalCommand(SphereGoalCommand):  # 5번의 목표 생성기를 물려받는다
    CENTER = (0.0, -0.18, 0.24)  # 5번 구(0, -0.20, 0.18)보다 2cm 뒤, 6cm 위
    RADIUS = 0.15                # 높이 0.09~0.39를 덮는다

@configclass
class SO101ReachHighEnvCfg(SO101ReachEnvCfg):
    def __post_init__(self) -> None:
        super().__post_init__()
        self.commands.ee_pose.class_type = HighSphereGoalCommand

@configclass
class SO101ReachHighPPORunnerCfg(SO101ReachSpherePPORunnerCfg):
    experiment_name = "reach_so101_high"  # 로그를 따로 모은다

gym.register(
    id="SO101-Reach-High",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    disable_env_checker=True,
    kwargs={
        "env_cfg_entry_point": f"{__name__}:SO101ReachHighEnvCfg",
        "rsl_rl_cfg_entry_point": f"{__name__}:SO101ReachHighPPORunnerCfg",
        "default_agent": "rsl_rl",
    },
)


# ===== 06-5-1: 보상 바꿔 보기 (구 과제 + 보상 가중치) =====
# 실험할 때는 이 숫자만 바꾼다. 괄호 안이 원래 값이다.
REWARD = {
    "track_weight": -0.2,         # 거리 벌점 (원래 -0.2)
    "fine_weight": 0.1,           # 정밀 보너스 (원래 0.1)
    "fine_std": 0.05,             # 정밀 보너스가 커지기 시작하는 거리 m (원래 0.05)
    "action_rate_final": -0.005,  # 커리큘럼 뒤 급한 동작 벌점 (원래 -0.005)
    "joint_vel_final": -0.001,    # 커리큘럼 뒤 관절 속도 벌점 (원래 -0.001)
}

@configclass
class SO101ReachSphereRewardEnvCfg(SO101ReachSphereEnvCfg):  # 5번의 구 과제를 물려받는다
    def __post_init__(self) -> None:
        super().__post_init__()
        rewards = self.rewards
        rewards.end_effector_position_tracking.weight = REWARD["track_weight"]
        rewards.end_effector_position_tracking_fine_grained.weight = REWARD["fine_weight"]
        rewards.end_effector_position_tracking_fine_grained.params["std"] = REWARD["fine_std"]
        self.curriculum.action_rate.params["weight"] = REWARD["action_rate_final"]
        self.curriculum.joint_vel.params["weight"] = REWARD["joint_vel_final"]

@configclass
class SO101ReachSphereRewardPPORunnerCfg(SO101ReachSpherePPORunnerCfg):
    experiment_name = "reach_so101_sphere_reward"  # 로그를 따로 모은다

gym.register(
    id="SO101-Reach-Sphere-Reward",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    disable_env_checker=True,
    kwargs={
        "env_cfg_entry_point": f"{__name__}:SO101ReachSphereRewardEnvCfg",
        "rsl_rl_cfg_entry_point": f"{__name__}:SO101ReachSphereRewardPPORunnerCfg",
        "default_agent": "rsl_rl",
    },
)

# ===== 07: 도메인 랜덤화 (구 과제 + DR) =====
# 노션 07 §3의 코드는 내보내기에 빠져 있어 07 §1 표의 값으로 다시 작성했다 (Isaac Lab 3.0.0 API).
# 실험할 때는 이 숫자만 바꾼다. 괄호 안이 07 §1의 기본값이다. "끄기"는 (1.0, 1.0) 또는 0.
DR = {
    "joint_pos_bias": 0.03,        # 에피소드마다 고정되는 관절 각도 오차 ±rad (0.03 ≈ ±1.7°)
    "joint_pos_noise": 0.01,       # 매 step 관절 각도 잡음 ±rad (원래 값과 같음)
    "joint_vel_noise": 0.1,        # 관절 속도 잡음 ±rad/s (원래 ±0.01)
    "obs_delay_max": 1,            # 관절 관측 지연 0~N step (1 step = 33 ms)
    "mass_scale": (0.8, 1.2),      # 링크 질량 배율
    "gain_scale": (0.7, 1.3),      # 모터 강성·감쇠(PD 게인) 배율
    "joint_friction": (0.0, 0.0),  # 관절 마찰 (꺼짐. 8번에서 (0.0, 0.05)로 켠다)
}

from isaaclab.managers import EventTermCfg as EventTerm
from isaaclab.utils.noise import NoiseModelWithAdditiveBiasCfg, UniformNoiseCfg


@configclass
class SO101ReachSphereDREnvCfg(SO101ReachSphereEnvCfg):  # 06 §5의 구 과제를 물려받는다
    def __post_init__(self) -> None:
        super().__post_init__()
        policy = self.observations.policy

        # 관측 쪽: 캘리브레이션 오차(bias) + 센서 잡음, 속도 잡음, 통신 지연
        bias, noise = DR["joint_pos_bias"], DR["joint_pos_noise"]
        if bias > 0:
            policy.joint_pos.noise = NoiseModelWithAdditiveBiasCfg(
                noise_cfg=UniformNoiseCfg(n_min=-noise, n_max=noise),
                bias_noise_cfg=UniformNoiseCfg(n_min=-bias, n_max=bias),  # reset 때 관절마다 새로 뽑는다
            )
        else:
            policy.joint_pos.noise = UniformNoiseCfg(n_min=-noise, n_max=noise)
        policy.joint_vel.noise = UniformNoiseCfg(n_min=-DR["joint_vel_noise"], n_max=DR["joint_vel_noise"])
        for term in (policy.joint_pos, policy.joint_vel):
            term.delay_min_lag = 0
            term.delay_max_lag = int(DR["obs_delay_max"])  # 에피소드마다 0~N step 중 하나를 뽑아 유지한다

        # 물리 쪽: 시작할 때 로봇마다 한 번 뽑아 학습 내내 유지한다
        robot_bodies = SceneEntityCfg("robot", body_names=".*")
        robot_joints = SceneEntityCfg("robot", joint_names=".*")
        if tuple(DR["mass_scale"]) != (1.0, 1.0):
            self.events.dr_mass = EventTerm(
                func=mdp.randomize_rigid_body_mass,
                mode="startup",
                params={"asset_cfg": robot_bodies, "mass_distribution_params": DR["mass_scale"], "operation": "scale"},
            )
        if tuple(DR["gain_scale"]) != (1.0, 1.0):
            self.events.dr_gains = EventTerm(
                func=mdp.randomize_actuator_gains,
                mode="startup",
                params={
                    "asset_cfg": robot_joints,
                    "stiffness_distribution_params": DR["gain_scale"],
                    "damping_distribution_params": DR["gain_scale"],
                    "operation": "scale",
                },
            )
        if tuple(DR["joint_friction"]) != (0.0, 0.0):
            self.events.dr_friction = EventTerm(
                func=mdp.randomize_joint_parameters,
                mode="startup",
                params={"asset_cfg": robot_joints, "friction_distribution_params": DR["joint_friction"], "operation": "abs"},
            )


@configclass
class SO101ReachSphereDRPPORunnerCfg(SO101ReachSpherePPORunnerCfg):
    experiment_name = "reach_so101_sphere_dr"  # 로그를 logs/rsl_rl/reach_so101_sphere_dr/ 에 따로 모은다


gym.register(
    id="SO101-Reach-Sphere-DR",
    entry_point="isaaclab.envs:ManagerBasedRLEnv",
    disable_env_checker=True,
    kwargs={
        "env_cfg_entry_point": f"{__name__}:SO101ReachSphereDREnvCfg",
        "rsl_rl_cfg_entry_point": f"{__name__}:SO101ReachSphereDRPPORunnerCfg",
        "default_agent": "rsl_rl",
    },
)
