#!/bin/bash

# restart_pixel_launcher.sh
# Мониторит логи и перезапускает Pixel Launcher при ошибках

PACKAGE="com.google.android.apps.nexuslauncher"
LOG_TAG="PixelLauncher|AndroidRuntime"
MAX_RETRIES=3
SLEEP_INTERVAL=5

function restart_launcher() {
    echo "$(date +'%T') - Обнаружен краш лаунчера. Перезапуск..."
    adb shell am force-stop $PACKAGE
    adb shell monkey -p $PACKAGE -c android.intent.category.HOME 1
}

function monitor_logs() {
    adb logcat -c  # Очищаем старые логи
    adb logcat | grep --line-buffered -E "$LOG_TAG" | while read -r line; do
        if [[ "$line" == *"not responding"* || "$line" == *"ANR"* && "$line" == *"$PACKAGE"* ]]; then
            restart_launcher
            # Сохраняем лог ошибки
            echo "$(date +'%Y-%m-%d %T') - $line" >> launcher_crash.log
        fi
    done
}

# Основной цикл
for ((i=1; i<=$MAX_RETRIES; i++)); do
    echo "Мониторинг логов (попытка $i/$MAX_RETRIES)..."
    monitor_logs
    sleep $SLEEP_INTERVAL
done

echo "Мониторинг завершен."
exit 0