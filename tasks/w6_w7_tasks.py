# W6·W7 실습 과제. scripts/apply_tasks.sh 가 원본 so101_reach.py 끝에 이 파일을 덧붙인다.
# 06·07 모두 노션 문서의 cat >> 블록을 순서대로 그대로 옮겼다.

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

# ===== 07: 06의 구 과제 + 도메인 랜덤화 =====
from isaaclab.managers import EventTermCfg as EventTerm
from isaaclab.utils.noise import NoiseModelWithAdditiveBiasCfg
from isaaclab.utils.noise import UniformNoiseCfg as Unoise
from isaaclab_tasks.core.reach.reach_env_cfg import EventCfg

# 실험할 때 바꿀 값은 여기에 모아 둔다. (0.0, 0.0)이나 (1.0, 1.0), 0은 "끄기"다.
DR = {
    "joint_pos_bias": 0.03,  # [rad] 에피소드마다 관절별로 고정된 각도 오차 ±0.03 rad (약 ±1.7°). 캘리브레이션 오차 흉내
    "joint_pos_noise": 0.01,  # [rad] 매 step 바뀌는 각도 잡음. 원래 값과 같다
    "joint_vel_noise": 0.10,  # [rad/s] 속도 잡음. 원래 0.01. 실기는 속도를 차분으로 계산해 잡음이 크다
    "obs_delay_max": 1,  # [step] 관측 지연 0~1 step (0~33 ms). USB 통신 지연 흉내
    "mass_scale": (0.8, 1.2),  # 링크 질량 ×0.8~1.2
    "gain_scale": (0.7, 1.3),  # 모터 강성·감쇠 ×0.7~1.3. 모터 힘·반응 속도 차이 흉내
    "joint_friction": (0.0, 0.0),  # 관절 마찰 계수에 더할 값. 8번에서 켠다 (예: (0.0, 0.05))
}


@configclass
class SO101ReachDREventCfg(EventCfg):
    """원래 이벤트(reset_robot_joints)에 물리 값 랜덤화를 더한다. startup: 시작할 때 로봇마다 한 번 뽑는다."""

    robot_mass = EventTerm(
        func=mdp.randomize_rigid_body_mass,
        mode="startup",
        params={
            "asset_cfg": SceneEntityCfg("robot", body_names=".*"),
            "mass_distribution_params": DR["mass_scale"],
            "operation": "scale",
        },
    )
    actuator_gains = EventTerm(
        func=mdp.randomize_actuator_gains,
        mode="startup",
        params={
            "asset_cfg": SceneEntityCfg("robot", joint_names=".*"),
            "stiffness_distribution_params": DR["gain_scale"],
            "damping_distribution_params": DR["gain_scale"],
            "operation": "scale",
        },
    )
    joint_friction = EventTerm(
        func=mdp.randomize_joint_parameters,
        mode="startup",
        params={
            "asset_cfg": SceneEntityCfg("robot", joint_names=".*"),
            "friction_distribution_params": DR["joint_friction"],
            "operation": "add",
        },
    )


@configclass
class SO101ReachSphereDREnvCfg(SO101ReachSphereEnvCfg):  # 06의 구 과제를 물려받는다
    def __post_init__(self) -> None:
        super().__post_init__()
        self.events = SO101ReachDREventCfg()

        obs = self.observations.policy
        # 관절 위치: 매 step 잡음 + 에피소드마다 고정된 오차(bias)
        obs.joint_pos.noise = NoiseModelWithAdditiveBiasCfg(
            noise_cfg=Unoise(n_min=-DR["joint_pos_noise"], n_max=DR["joint_pos_noise"]),
            bias_noise_cfg=Unoise(n_min=-DR["joint_pos_bias"], n_max=DR["joint_pos_bias"]),
        )
        obs.joint_vel.noise = Unoise(n_min=-DR["joint_vel_noise"], n_max=DR["joint_vel_noise"])
        # 관측 지연: 로봇마다 0~obs_delay_max step 늦은 값을 보여 준다
        obs.joint_pos.delay_max_lag = DR["obs_delay_max"]
        obs.joint_vel.delay_max_lag = DR["obs_delay_max"]


@configclass
class SO101ReachSphereDRPPORunnerCfg(SO101ReachSpherePPORunnerCfg):
    experiment_name = "reach_so101_sphere_dr"  # 로그를 logs/rsl_rl/reach_so101_sphere_dr/ 에 따로 저장
    max_iterations = 600  # 06의 구 학습과 같게 둬서 공정하게 비교한다


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
