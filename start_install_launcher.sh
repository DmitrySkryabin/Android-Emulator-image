#!/bin/bash

# echo "Waiting for device..."
# adb wait-for-device
# echo "Installing Simple Launcher..."
# adb install -r -t -g /opt/app/simple-launcher.apk
# echo "Setting as default launcher..."
# adb shell pm disable-user --user 0 com.google.android.apps.nexuslauncher
# adb shell pm disable-user --user 0 com.android.launcher3
# adb shell cmd package set-home-activity "com.simplemobiletools.launcher/com.simplemobiletools.launcher.activities.MainActivity"

echo "Ожидание полной загрузки Android..."
adb wait-for-device
until adb shell getprop sys.boot_completed | grep -q "1"; do sleep 5; done
echo "Система готова, устанавливаем лаунчер..."
max_retries=5
count=0
while [ $count -lt $max_retries ]; do
  if adb install -r -t -g /opt/app/simple-launcher.apk; then
    echo "Установка успешна!"
    break
  else
    echo "Попытка $((count+1))/$max_retries не удалась. Повторяем через 10 сек..."
    sleep 10
    ((count++))
  fi
done
[ $count -eq $max_retries ] && echo "Достигнуто максимальное количество попыток!"

echo "Настройка лаунчера..."
adb shell pm disable-user --user 0 com.google.android.apps.nexuslauncher 2>/dev/null || true
adb shell pm disable-user --user 0 com.android.launcher3 2>/dev/null || true
adb shell cmd package set-home-activity "com.simplemobiletools.launcher/com.simplemobiletools.launcher.activities.MainActivity"
' > /install_launcher.sh && 
chmod +x /install_launcher.sh
