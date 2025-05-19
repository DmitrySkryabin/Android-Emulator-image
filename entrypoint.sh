#!/bin/bash

BL='\033[0;34m'
G='\033[0;32m'
RED='\033[0;31m'
YE='\033[1;33m'
NC='\033[0m' # No Color


function check_current_focus() {
  printf "${BL}==> Checking emulator running activity ${NC}\n"
  target="com.google.android.apps.nexuslauncher.NexusLauncherActivity"
  error_target="Application Not Responding: com.android.systemui}"

  while true; do
    result=$(adb shell dumpsys window 2>/dev/null | grep -i mCurrentFocus)

    if [[ $result == *"$error_target"* ]]; then
      printf "${RED}==>  Activity is NOT OKEY: ${NC}\n"
      printf "${RED}Current activity: $result ${NC}\n"
      adb shell input keyevent KEYCODE_HOME
      printf "${YE}==> Menu button is pressed ${NC}\n"

    else
      printf "${G}==> Activity is OKEY: ${NC}\n"
      printf "Current activity: $result\n"
    fi
    sleep 10
  done
}

function check_emulator_status () {
  printf "${BL}==> ${BL}Checking emulator status: ${NC}\n" # Выводим начальное сообщение один раз
  start_time=$(date +%s)
  spinner=( "." ".." "..." )
  i=0
  timeout=${EMULATOR_TIMEOUT:-300}

  while true; do
    result=$(adb shell getprop sys.boot_completed 2>&1)

    if [ "$result" == "1" ]; then
      printf "\r\e[K${G}==> !Emulator is ready ${NC}\n" # Очищаем строку и выводим сообщение с новой строкой
      adb devices -l
      adb shell input keyevent 82
      break
    else
      printf "\r\e[K${YE}==> please wait ${spinner[$i]} ${NC}" # Очищаем и выводим индикатор
      i=$(( (i+1) % 3 ))
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -gt $timeout ]; then
      printf "\r\e[K${RED}==> Timeout after ${timeout} seconds elapsed ${NC}\n" # Очищаем и выводим таймаут с новой строкой
      break
    fi
    sleep 4
  done
};

function disable_animation() {
  adb shell settings put global development_settings_enabled 1
  adb shell settings put global window_animation_scale 0.0
  adb shell settings put global transition_animation_scale 0.0
  adb shell settings put global animation_duration_scale 0.0
  adb shell settings put global network_recommendations_enabled 0
  adb shell settings put secure autofill_service null
  adb shell settings put secure spell_checker_enabled 0
  adb shell settings put secure show_ime_with_hard_keyboard 0
  adb shell settings put system pointer_location 1

  # Убираем приколы с клавиатурой
  adb shell pm disable-user com.google.android.inputmethod.latin || echo "WARN: Failed to disable inputmethod.latin"
  adb shell pm disable-user com.google.android.tts || echo "WARN: Failed to disable tts"
  adb shell pm disable-user com.google.android.googlequicksearchbox || echo "WARN: Failed to disable googlequicksearchbox"
};


./start_vnc.sh &
VNC_PID=$!
./start_emu.sh &
EMULATOR_PID=$!
sleep 5
check_emulator_status
sleep 5
disable_animation
check_current_focus &
CHECK_CURRENT_FOCUS_PID=$!
./start_appium.sh &
APPIUM_PID=$!


clean() {
  STOP="yes"
  if [ -n "$VNC_PID" ]; then
    kill -TERM "$VNC_PID"
  fi
  if [ -n "$EMULATOR_PID" ]; then
    kill -TERM "$EMULATOR_PID"
  fi
  if [ -n "$CHECK_CURRENT_FOCUS_PID" ]; then
    kill -TERM "$CHECK_CURRENT_FOCUS_PID"
  fi
  if [ -n "$APPIUM_PID" ]; then
    kill -TERM "$APPIUM_PID"
  fi
}

trap clean SIGINT SIGTERM

wait