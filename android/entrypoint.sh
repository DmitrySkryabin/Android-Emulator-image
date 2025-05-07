#!/bin/bash
CHROMEDRIVER_PORT=9515
BOOTSTRAP_PORT=4725
EMULATOR=emulator-5554
APPIUM_ARGS=${APPIUM_ARGS:-""}
EMULATOR_ARGS=${EMULATOR_ARGS:-""}
PORT=${PORT:-"4444"}
DISPLAY_NUM=99
export DISPLAY=":$DISPLAY_NUM"
# SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-"1920x1080x24"}
# SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-"800x900x24"}
SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-"1280x1024x24"}
SKIN=${SKIN:-"864x1824"}
WIDHT=864
HEIGHT=1824
DPI=400
STOP=""
VERBOSE=${VERBOSE:-""}

if [ -z "$VERBOSE" ]; then
    if [ -z "$APPIUM_ARGS" ]; then
        APPIUM_ARGS="--log-level error"
    fi
else
    EMULATOR_ARGS="$EMULATOR_ARGS -verbose"
fi


clean() {
  STOP="yes"
  if [ -n "$APPIUM_PID" ]; then
    kill -TERM "$APPIUM_PID"
  fi
  if [ -n "$EMULATOR_PID" ]; then
    kill -TERM "$EMULATOR_PID"
  fi
  if [ -n "$X11VNC_PID" ]; then
    kill -TERM "$X11VNC_PID"
  fi
  if [ -n "$DEVTOOLS_PID" ]; then
    kill -TERM "$DEVTOOLS_PID"
  fi
  if [ -n "$XVFB_PID" ]; then
    kill -TERM "$XVFB_PID"
  fi
}

trap clean SIGINT SIGTERM

/usr/bin/xvfb-run -e /dev/stdout -l -n "$DISPLAY_NUM" -s "-ac -screen 0 $SCREEN_RESOLUTION -noreset -listen tcp" /usr/bin/fluxbox -display "$DISPLAY" -log /tmp/fluxbox.log 2>/dev/null &
XVFB_PID=$!

retcode=1
until [ $retcode -eq 0 ] || [ -n "$STOP" ]; do
  DISPLAY="$DISPLAY" wmctrl -m >/dev/null 2>&1
  retcode=$?
  if [ $retcode -ne 0 ]; then
    echo Waiting X server...
    sleep 0.1
  fi
done
if [ -n "$STOP" ]; then exit 0; fi

if [ "$ENABLE_VNC" != "true" ] && [ "$ENABLE_VIDEO" != "true" ]; then
    EMULATOR_ARGS="$EMULATOR_ARGS -no-window"
fi

echo "hw.lcd.width=${WIDHT}" >> /root/.android/avd/${AVD_NAME}.avd/config.ini && \
echo "hw.lcd.height=${HEIGHT}" >> /root/.android/avd/${AVD_NAME}.avd/config.ini && \
echo "hw.lcd.density=${DPI}" >> /root/.android/avd/${AVD_NAME}.avd/config.ini

ANDROID_AVD_HOME=/root/.android/avd DISPLAY="$DISPLAY" \ 
  /opt/android-sdk-linux/emulator/emulator ${EMULATOR_ARGS} \
  -no-boot-anim \
  -no-audio \
  -no-jni \
  -avd $AVD_NAME \
  -gpu host \
  -memory 6144 \
  -ranchu \
  -qemu \
  -enable-kvm &
EMULATOR_PID=$!

# Выключаем анимации, клавиатуры и автозаполнение данных, включаем отображение тапов
adb shell settings put global development_settings_enabled 1
adb shell settings put global window_animation_scale 0.0
adb shell settings put global transition_animation_scale 0.0
adb shell settings put global animation_duration_scale 0.0
adb shell settings put global network_recommendations_enabled 0
adb shell settings put secure autofill_service null
adb shell settings put secure spell_checker_enabled 0
adb shell settings put secure show_ime_with_hard_keyboard 0
adb shell settings put system pointer_location 1

if [ "$ENABLE_VNC" == "true" ]; then
    x11vnc -display "$DISPLAY" -passwd selenoid -shared -forever -loop500 -rfbport 5900 -rfbportv6 5900 -logfile /tmp/x11vnc.log &
    X11VNC_PID=$!
fi

while [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" != "1" ] && [ -z "$STOP" ] ; do sleep 1; done
if [ -n "$STOP" ]; then exit 0; fi

if [ "$SHOW_LOGCAT" == "true" ]; then
    # adb logcat *:E &
    adb logcat *:E | grep -iE "crash|exception|error" &
fi
# sleep 5
# adb shell am force-stop com.google.android.apps.nexuslauncher
# sleep 5

# function check_current_focus() {
#   printf "==> Checking emulator running activity \n"
#   start_time=$(date +%s)
#   i=0
#   timeout=60
#   target="com.google.android.apps.nexuslauncher.NexusLauncherActivity"
#   error_target="mCurrentFocus=Window{a49c871 u0 Application Not Responding: com.android.systemui}"

#   while true; do
#     result=$(adb shell dumpsys window 2>/dev/null | grep -i mCurrentFocus)

#     if [[ $result == *"$target"* ]]; then
#       printf "==>  Activity is okay: \n"
#       printf "$result\n"
#       break
#     else
#       # adb shell input keyevent KEYCODE_HOME
#       # printf "==> Menu button is pressed \n"
#       printf "==> Activity is NOOOT OKEY: \n"
#       printf "$result\n"
#       adb shell am force-stop com.android.systemui
#       printf "==>FORCE-STOP SYSTEM UI \n"
#       i=$(( (i+1) % 8 ))
#     fi

#     current_time=$(date +%s)
#     elapsed_time=$((current_time - start_time))
#     if [ $elapsed_time -gt $timeout ]; then
#       printf "==> Timeout after ${timeout} seconds elapsed 🕛.. \n"
#       return 1
#     fi
#     sleep 4
#   done
# }
# function check_current_focus() {
#   printf "==> Checking emulator running activity \n"
#   start_time=$(date +%s)
#   i=0
#   timeout=60
#   target="com.google.android.apps.nexuslauncher.NexusLauncherActivity"
#   error_target="mCurrentFocus=Window{a49c871 u0 Application Not Responding: com.android.systemui}"

#   while true; do
#     result=$(adb shell dumpsys window 2>/dev/null | grep -i mCurrentFocus)

#     if [[ $result == *"$error_target"* ]]; then
#       printf "==>  Activity is NOT okay: \n"
#       printf "$result\n"
#       adb shell input keyevent KEYCODE_HOME
#       printf "==> Menu button is pressed \n"
#       i=$(( (i+1) % 8 ))
#     else
#       # adb shell input keyevent KEYCODE_HOME
#       # printf "==> Menu button is pressed \n"
#       printf "==> Activity is OKEY: \n"
#       printf "$result\n"
#       break
#     fi

#     current_time=$(date +%s)
#     elapsed_time=$((current_time - start_time))
#     if [ $elapsed_time -gt $timeout ]; then
#       printf "==> Timeout after ${timeout} seconds elapsed 🕛.. \n"
#       return 1
#     fi
#     sleep 4
#   done
# }

function check_current_focus() {
  printf "==> Checking emulator running activity \n"
  start_time=$(date +%s)
  i=0
  timeout=60
  target="com.google.android.apps.nexuslauncher.NexusLauncherActivity"
  error_target="Application Not Responding: com.android.systemui}"

  while true; do
    result=$(adb shell dumpsys window 2>/dev/null | grep -i mCurrentFocus)

    if [[ $result == *"$error_target"* ]]; then
      printf "==>  Activity is NOT okay: \n"
      printf "$result\n"
      adb shell input keyevent KEYCODE_HOME
      printf "==> Menu button is pressed \n"
      i=$(( (i+1) % 8 ))
    else
      # adb shell input keyevent KEYCODE_HOME
      # printf "==> Menu button is pressed \n"
      printf "==> Activity is OKEY: \n"
      printf "$result\n"
    fi
    sleep 10
  done
}

sleep 10
check_current_focus &

/opt/node_modules/.bin/appium -a 0.0.0.0 -p "$PORT" --log-timestamp --log-no-colors ${APPIUM_ARGS}  &
APPIUM_PID=$!

wait
