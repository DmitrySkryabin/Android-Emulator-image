#!/bin/bash

BL='\033[0;34m'
G='\033[0;32m'
RED='\033[0;31m'
YE='\033[1;33m'
NC='\033[0m' # No Color

WIDHT=864
HEIGHT=1824
DPI=400

function run_emulator() {
  emulator_name=${EMULATOR_NAME}
  echo "hw.lcd.width=${WIDHT}" >> /root/.android/avd/${EMULATOR_NAME}.avd/config.ini && \
  echo "hw.lcd.height=${HEIGHT}" >> /root/.android/avd/${EMULATOR_NAME}.avd/config.ini && \
  echo "hw.lcd.density=${DPI}" >> /root/.android/avd/${EMULATOR_NAME}.avd/config.ini
  emulator \
    -avd "${emulator_name}" \
    -no-boot-anim \
    -no-audio \
    -memory 6144 \
    -gpu host \
    2>&1 | grep -v "libunwind" &
  printf "${G}==>  ${BL}Emulator has ${YE}${EMULATOR_NAME} ${BL}started in headed mode! ${NC}\n"
}

DISPLAY=:1
export DISPLAY

run_emulator