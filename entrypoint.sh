#!/bin/bash


./start_vnc.sh &
./start_emu.sh

# Запуск установки лаунчера в фоне
/start_install_launcher.sh

# Ожидание завершения установки (опционально)
while ! adb shell pm list packages | grep -q "simplemobiletools"; do
    sleep 2
done

# # Тут мы устанвливаем апк отдельно (есть проблема с политиками, чтобы принять их)
# ./start_install_apk.sh

# Тут мы достойно просто перезапускаем пиксель лаунчер
# ./start_reboot_pixel_launcher.sh

./start_appium.sh

wait