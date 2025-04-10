#!/bin/bash

# Функция для проверки текущего лаунчера
get_current_launcher() {
  adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | grep -o 'com[^ ]*' | head -1
}

echo "Ожидание полной загрузки Android..."
adb wait-for-device
until adb shell getprop sys.boot_completed | grep -q "1"; do
  sleep 5
done
echo "Система готова."

# Установка лаунчера
echo "Установка Simple Launcher..."
for i in {1..5}; do
  if adb install -r -t -g /opt/app/simple-launcher.apk; then
    echo "Установка успешна!"
    break
  elif [ $i -eq 5 ]; then
    echo "Ошибка: не удалось установить лаунчер после 5 попыток"
    exit 1
  else
    echo "Попытка $i/5 не удалась, повтор через 10 сек..."
    sleep 10
  fi
done

echo "Настройка лаунчера..."
adb shell pm disable-user --user 0 com.google.android.apps.nexuslauncher 2>/dev/null || true
adb shell pm disable-user --user 0 com.android.launcher3 2>/dev/null || true

# Установка лаунчера по умолчанию (3 попытки)
for i in {1..3}; do
  echo "Попытка $i установить лаунчер по умолчанию..."
  adb shell cmd package set-home-activity "com.simplemobiletools.launcher/com.simplemobiletools.launcher.activities.MainActivity"
  
  sleep 3
  
  # Принудительный перезапуск
  echo "Принудительный перезапуск лаунчеров..."
  adb shell am force-stop com.simplemobiletools.launcher 2>/dev/null || true
  adb shell am force-stop com.google.android.apps.nexuslauncher 2>/dev/null || true
  adb shell am force-stop com.android.launcher3 2>/dev/null || true
  
  # Имитация нажатия HOME
  echo "Имитация нажатия HOME..."
  adb shell input keyevent KEYCODE_HOME
  sleep 2
  
  # Проверка результата
  current_launcher=$(get_current_launcher)
  if [[ "$current_launcher" == *"simplemobiletools"* ]]; then
    echo "Simple Launcher успешно активирован!"
    exit 0
  fi
done

# Если после 3 попыток не сработало
echo "Автоматическая активация не удалась. Текущий лаунчер: $current_launcher"
echo "Попробуйте вручную:"
echo "1. Нажать кнопку HOME"
echo "2. Выбрать Simple Launcher"
echo "3. Нажать 'Всегда'"
echo "Выполняю перезагрузку..."
adb reboot