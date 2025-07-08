#!/bin/bash

BL='\033[0;34m'
G='\033[0;32m'
RED='\033[0;31m'
YE='\033[1;33m'
NC='\033[0m' # No Color


draw_framed_message() {
    local color="$1"
    local content="$2"

    # Разбиваем текст по строкам
    mapfile -t lines < <(printf "%b" "$content")

    local max_len=0
    local clean_line

    for line in "${lines[@]}"; do
        # Удаляем ANSI коды для подсчета визуальной длины
        clean_line=$(echo -e "$line" | sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g')
        local current_len=${#clean_line}
        if (( current_len > max_len )); then
            max_len=$current_len
        fi
    done

    local frame_line=""
    for (( i=0; i<max_len+4; i++ )); do
        frame_line+="═"
    done

    printf "${color}╔%s╗${NC}\n" "$frame_line"
    for line in "${lines[@]}"; do
        clean_line=$(echo -e "$line" | sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g')
        local padding=$((max_len - ${#clean_line}))
        local spaces=$(printf '%*s' "$padding")
        printf "${color}║ ${line}${spaces} ║${NC}\n"
    done
    printf "${color}╚%s╝${NC}\n" "$frame_line"
}

function check_current_focus() {
  printf "${BL}==> Checking emulator running activity ${NC}\n"
  target="com.google.android.apps.nexuslauncher.NexusLauncherActivity"
  error_target="Application Not Responding"

  while true; do
    result=$(adb shell dumpsys window 2>/dev/null | grep -i mCurrentFocus)

    if [[ $result == *"$error_target"* ]]; then
      # Используем переменную для многострочного сообщения с \n
      local MESSAGE_ERROR="==> Activity is NOT OKEY!\nCurrent activity: $result"
      draw_framed_message "${RED}" "$MESSAGE_ERROR"
      adb shell input keyevent KEYCODE_HOME
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
sleep 5
adb logcat -v tag TestLog:V *:S 2>&1 &
check_current_focus &
CHECK_CURRENT_FOCUS_PID=$!
./start_appium.sh &
APPIUM_PID=$!
sleep 2
printf "${G}STARTED COLLECTING LOGS FROM TESTS!${NC}"


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