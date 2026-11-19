#!/usr/bin/env bash
# 시뮬레이션 실습(03·04·06·07)을 처음부터 끝까지 순서대로 돌린다. 05 실기와 06 §7·07 §7 실기 비교는 제외.
# 오래 걸리므로 tmux 안에서 실행한다: tmux new -s rl  →  scripts/run_all.sh  →  Ctrl+b d
#   scripts/run_all.sh                  필수 단계만
#   scripts/run_all.sh --all            선택 단계까지 (03 이어 학습·실습 A~E, 06 높이 뻗기·보상 R1~R4)
#   scripts/run_all.sh --from w6        특정 단계부터 (w3, w4, w6, w7)
# 각 단계는 소규모 시험(64 envs x 10)을 먼저 돌려 설정 오류를 일찍 잡는다.
source "$(dirname "$0")/env.sh"
S="$(dirname "$0")"
ALL=0; FROM=w3
while (( $# )); do
  case "$1" in --all) ALL=1; shift ;; --from) FROM="$2"; shift 2 ;; *) sed -n '2,8p' "$0"; exit 1 ;; esac
done
order=(w3 w4 w6 w7); started=0
step() { echo -e "\n##### $(date '+%H:%M:%S') $* #####"; "$@"; }

for stage in "${order[@]}"; do
  [[ "$stage" == "$FROM" ]] && started=1
  (( started )) || continue
  case "$stage" in
    w3)
      step "$S/w3.sh" smoke
      step "$S/w3.sh" basic
      if (( ALL )); then
        step "$S/w3.sh" resume
        for e in A B C D E; do step "$S/w3.sh" exp "$e"; done
      fi ;;
    w4)
      step "$S/w4.sh" all ;;
    w6)
      step "$S/apply_tasks.sh"
      step "$S/w6.sh" smoke
      step "$S/w6.sh" limit
      step "$S/w6.sh" box
      step "$S/w6.sh" box-video
      step "$S/w6.sh" sphere
      step "$S/w6.sh" sphere-video
      if (( ALL )); then
        step "$S/w6.sh" high
        for r in R1 R2 R3 R4; do step "$S/w6.sh" reward "$r"; done
        step "$S/w6.sh" export smooth
        step "$S/w6.sh" export high
      fi
      step "$S/w6.sh" export sphere ;;
    w7)
      step "$S/w7.sh" check
      step "$S/w7.sh" smoke
      step "$S/w7.sh" train
      step "$S/w7.sh" compare
      step "$S/w7.sh" export ;;
  esac
done
(( started )) || die "--from 은 w3, w4, w6, w7 중 하나입니다."
step "$S/collect.sh"
echo -e "\n[완료] results/summary.md 와 results/so101_results_*.tar.gz 를 확인하세요."
