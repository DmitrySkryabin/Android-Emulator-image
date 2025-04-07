#!/bin/bash

./start_vnc.sh &
./start_emu.sh
./start_appium.sh

wait