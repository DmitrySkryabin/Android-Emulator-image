#!/bin/bash

./start_vnc.sh &
./start_emu.sh

./start_pixel_launch_monitor.sh &

./start_appium.sh

wait