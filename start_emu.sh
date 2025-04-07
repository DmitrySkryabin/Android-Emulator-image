#!/bin/bash

BL='\033[0;34m'
G='\033[0;32m'
RED='\033[0;31m'
YE='\033[1;33m'
NC='\033[0m' # No Color

SKIN='864x1920'

grpc_port=${GRPC_PORT}

function wait_emulator_to_be_ready() {
  emulator_name=${EMULATOR_NAME}
  # nohup emulator -avd "${emulator_name}" -no-boot-anim -no-snapshot -gpu swiftshader_indirect -skin ${SKIN} -dpi-device 300 -grpc ${grpc_port} &
  nohup emulator -avd "${emulator_name}" -no-boot-anim -no-snapshot -gpu guest -skin ${SKIN} -dpi-device 300 -grpc ${grpc_port} &
  # nohup emulator -avd "${emulator_name}" -no-boot-anim -gpu off -grpc ${grpc_port} &
  printf "${G}==>  ${BL}Emulator has ${YE}${EMULATOR_NAME} ${BL}started in headed mode! ${G}<==${NC}""\n"
}

function check_emulator_status () {
  printf "${G}==> ${BL}Checking emulator booting up status 🧐${NC}\n"
  start_time=$(date +%s)
  spinner=( "⠹" "⠺" "⠼" "⠶" "⠦" "⠧" "⠇" "⠏" )
  i=0
  # Get the timeout value from the environment variable or use the default value of 300 seconds (5 minutes)
  timeout=${EMULATOR_TIMEOUT:-300}

  while true; do
    result=$(adb shell getprop sys.boot_completed 2>&1)

    if [ "$result" == "1" ]; then
      printf "\e[K${G}==> \u2713 Emulator is ready : '$result'           ${NC}\n"
      adb devices -l
      adb shell input keyevent 82
      break
    elif [ "$result" == "" ]; then
      printf "${YE}==> Emulator is partially Booted! 😕 ${spinner[$i]} ${NC}\r"
    else
      printf "${RED}==> $result, please wait ${spinner[$i]} ${NC}\r"
      i=$(( (i+1) % 8 ))
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -gt $timeout ]; then
      printf "${RED}==> Timeout after ${timeout} seconds elapsed 🕛.. ${NC}\n"
      break
    fi
    sleep 4
  done
};

function disable_animation() {
  adb shell "settings put global window_animation_scale 0.0"
  adb shell "settings put global transition_animation_scale 0.0"
  adb shell "settings put global animator_duration_scale 0.0"
}

DISPLAY=:1
export DISPLAY

wait_emulator_to_be_ready
sleep 1
check_emulator_status
sleep 1
disable_animation