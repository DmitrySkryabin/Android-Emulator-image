#!/bin/bash

# === Начало блока переменных и базовой настройки ===
BOOTSTRAP_PORT=4725    # Порт для Appium Bootstrap (внутренний протокол)
APPIUM_ARGS=${APPIUM_ARGS:-""} # Дополнительные аргументы для Appium, можно передать как ENV VAR при запуске контейнера (по умолчанию пусто)
EMULATOR_ARGS=${EMULATOR_ARGS:-""} # Дополнительные аргументы для эмулятора, можно передать как ENV VAR (по умолчанию пусто)
PORT=${PORT:-"4444"} # Порт, на котором будет слушать Appium, можно переопределить через ENV VAR (по умолчанию 4444)

DISPLAY_NUM=99       # Номер виртуального дисплея
export DISPLAY=":$DISPLAY_NUM" # Устанавливает переменную окружения DISPLAY для всех графических приложений
SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-"1280x1024x24"} # Разрешение экрана для виртуального дисплея (по умолчанию 1280x1024x24)

# Переменные для настройки разрешения и плотности через config.ini - см. далее
WIDTH=864  # Ширина
HEIGHT=1824 # Высота
DPI=400    # Плотность точек на дюйм

STOP=""        # Флаг для сигнализации о завершении работы (используется в функции clean)
VERBOSE=${VERBOSE:-""} # Флаг для включения подробного вывода (по умолчанию пусто)


# Настройка логирования Appium и эмулятора в зависимости от флага VERBOSE
if [ -z "$VERBOSE" ]; then # Если VERBOSE не задан или пуст
    if [ -z "$APPIUM_ARGS" ]; then # Если APPIUM_ARGS не задан
        APPIUM_ARGS="--log-level error" # Установить минимальный уровень логирования для Appium
    fi
else # Если VERBOSE задан
    EMULATOR_ARGS="$EMULATOR_ARGS -verbose" # Добавить подробный вывод для эмулятора
fi
# === Конец блока переменных ===


# === Функция чистки (вызывается при получении сигналов завершения) ===
clean() {
  STOP="yes" # Устанавливаем флаг остановки
  echo "Получен сигнал завершения. Инициирую чистку процессов."

  # Остановка процессов, если они запущены (проверяем наличие PID и отправляем TERM сигнал)
  # Проверка kill -0 $PID >/dev/null 2>&1 используется для того, чтобы убедиться,
  # что процесс с таким PID существует, прежде чем пытаться его убить.
  if [ -n "$APPIUM_PID" ] && kill -0 "$APPIUM_PID" >/dev/null 2>&1; then
    echo "Останавливаю Appium (PID: $APPIUM_PID)..."
    kill -TERM "$APPIUM_PID"
  fi
  if [ -n "$EMULATOR_PID" ] && kill -0 "$EMULATOR_PID" >/dev/null 2>&1; then
    echo "Останавливаю Эмулятор (PID: $EMULATOR_PID)..."
    kill -TERM "$EMULATOR_PID"
  fi
  if [ -n "$X11VNC_PID" ] && kill -0 "$X11VNC_PID" >/dev/null 2>&1; then
    echo "Останавливаю x11vnc (PID: $X11VNC_PID)..."
    kill -TERM "$X11VNC_PID"
  fi
  # DEVTOOLS_PID не определён в предоставленном коде, возможно, это остаток
  if [ -n "$DEVTOOLS_PID" ] && kill -0 "$DEVTOOLS_PID" >/dev/null 2>&1; then
     echo "Останавливаю Devtools (PID: $DEVTOOLS_PID)..."
    kill -TERM "$DEVTOOLS_PID"
  fi
  if [ -n "$XVFB_PID" ] && kill -0 "$XVFB_PID" >/dev/null 2>&1; then
    echo "Останавливаю Xvfb (PID: $XVFB_PID)..."
    kill -TERM "$XVFB_PID"
  fi

  # Дать процессам немного времени на завершение самостоятельно
  sleep 2

  echo "Чистка завершена."
}

# Установка ловушек (trap): при получении сигналов SIGINT (Ctrl+C) или SIGTERM (остановка Docker)
# будет вызвана функция clean. Можно добавить EXIT для вызова при любом выходе.
trap clean SIGINT SIGTERM
# === Конец функции чистки ===


# === Запуск X сервера и оконного менеджера ===
# xvfb-run запускает команду на виртуальном дисплее.
# -e /dev/stdout перенаправляет вывод ошибок Xvfb в stdout контейнера
# -l создает файл .Xauthority
# -n "$DISPLAY_NUM" использует указанный номер дисплея
# -s "...": дополнительные аргументы для X-сервера (разрешение, не сбрасывать, слушать tcp)
# /usr/bin/fluxbox: запускает оконный менеджер Fluxbox на виртуальном дисплее
# -display "$DISPLAY": указывает Fluxbox использовать наш виртуальный дисплей
# -log /tmp/fluxbox.log: файл для логов Fluxbox
# 2>/dev/null: перенаправляет stderr Fluxbox в никуда (можно изменить для отладки)
# & запускает в фоне
/usr/bin/xvfb-run -e /dev/stdout -l -n "$DISPLAY_NUM" -s "-ac -screen 0 $SCREEN_RESOLUTION -noreset -listen tcp" /usr/bin/fluxbox -display "$DISPLAY" -log /tmp/fluxbox.log 2>/dev/null &
XVFB_PID=$! # Сохраняем PID процесса Xvfb для последующей чистки

# Ожидание готовности X сервера (проверяем через wmctrl)
retcode=1 # Код возврата команды wmctrl
until [ $retcode -eq 0 ] || [ -n "$STOP" ]; do # Ждем, пока wmctrl вернет 0 (сервер готов) или пока не установлен флаг STOP
  DISPLAY="$DISPLAY" wmctrl -m >/dev/null 2>&1 # Проверяем состояние оконного менеджера
  retcode=$? # Получаем код возврата wmctrl
  if [ $retcode -ne 0 ]; then
    echo Waiting X server... # Выводим сообщение, если сервер еще не готов
    sleep 0.1 # Короткая задержка перед следующей попыткой
  fi
done
if [ -n "$STOP" ]; then exit 0; fi # Если флаг STOP установлен во время ожидания, выходим
# === Конец запуска X сервера ===


# === Настройка и запуск эмулятора ===
# Опция -no-window, если VNC и Video отключены
if [ "$ENABLE_VNC" != "true" ] && [ "$ENABLE_VIDEO" != "true" ]; then
    EMULATOR_ARGS="$EMULATOR_ARGS -no-window"
fi

# Эти строки модифицируют файл конфигурации AVD ПЕРЕД запуском эмулятора.
echo "hw.lcd.width=${WIDTH}" >> /root/.android/avd/${AVD_NAME}.avd/config.ini && \
echo "hw.lcd.height=${HEIGHT}" >> /root/.android/avd/${AVD_NAME}.avd/config.ini && \
echo "hw.lcd.density=${DPI}" >> /root/.android/avd/${AVD_NAME}.avd/config.ini

# Запуск самого эмулятора
# ANDROID_AVD_HOME: Устанавливает переменную окружения для эмулятора, указывая каталог AVDs
# DISPLAY="$DISPLAY": Указывает эмулятору использовать наш виртуальный дисплей
# /opt/android-sdk-linux/emulator/emulator: Полный путь к исполняемому файлу эмулятора
# ${EMULATOR_ARGS}: Дополнительные аргументы запуска
# -no-boot-anim: Отключает анимацию загрузки (ускоряет старт)
# -no-audio: Отключает звук
# -no-jni: Отключает JNI (может помочь в некоторых случаях)
# -avd $AVD_NAME: Указывает, какой AVD запускать (использует переменную из Dockerfile/ENV)
# -gpu host: Пытается использовать GPU хоста (Будет использовать xvfb)
# -memory 6144: Выделяет 6144 МБ ОЗУ эмулятору (может отличаться в зависимости от AVD)
# -ranchu -qemu -enable-kvm: Опции для использования KVM ускорения (требуется на хосте)
# & запускает в фоне
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
EMULATOR_PID=$! # Сохраняем PID эмулятора для последующей чистки
# === Конец запуска эмулятора ===


# === Запуск VNC сервера (если включен) ===
if [ "$ENABLE_VNC" == "true" ]; then
    # x11vnc запускает VNC сервер
    # -display "$DISPLAY": Подключается к нашему виртуальному дисплею
    # -passwd selenoid: Устанавливает пароль для VNC (здесь "selenoid")
    # -shared: Разрешает несколько подключений
    # -forever: Работает до остановки
    # -loop500: Проверяет состояние дисплея каждые 500 мс
    # -rfbport 5900: Порт для VNC подключения (обычный)
    # -rfbportv6 5900: Порт для VNC подключения (IPv6)
    # -logfile /tmp/x11vnc.log: Файл лога VNC
    # & запускает в фоне
    x11vnc -display "$DISPLAY" -passwd selenoid -shared -forever -loop500 -rfbport 5900 -rfbportv6 5900 -logfile /tmp/x11vnc.log &
    X11VNC_PID=$! # Сохраняем PID x11vnc для чистки
fi
# === Конец запуска VNC ===


# === ОЖИДАНИЕ ПОЛНОЙ ЗАГРУЗКИ ЭМУЛЯТОРА ===
# Это КРИТИЧЕСКИ ВАЖНЫЙ блок. ADB команды, которые настраивают систему (settings put),
# и Appium не будут работать корректно, пока эмулятор полностью не загрузится.
# Мы ждем, пока системное свойство 'sys.boot_completed' станет равным '1'.
# adb shell getprop sys.boot_completed: Получает значение этого свойства
# tr -d '\r': Удаляет символы возврата каретки, которые adb shell может добавлять
while [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" != "1" ] && [ -z "$STOP" ] ; do
    echo -n "." # Выводим точку, чтобы показать, что ждем
    sleep 1 # Ждем 1 секунду перед следующей проверкой
done
echo "" # Новая строка после завершения ожидания
if [ -n "$STOP" ]; then exit 0; fi # Если флаг STOP установлен во время ожидания, выходим
# === Конец ожидания загрузки ===


# === НАЧАЛО БЛОКА НАСТРОЙКИ ADB SHELL ===
# Теперь, когда эмулятор гарантированно загружен и ADB должен быть доступен,
# выполняем команды настройки через ADB shell.

echo "--- Настройка эмулятора через ADB shell ---"
# Команды ADB shell для настройки различных параметров системы Android.
# Используются для оптимизации производительности и поведения эмулятора в тестовой среде.
# || echo "WARN: ..." добавляет вывод предупреждения, если команда не выполнилась успешно.
adb shell settings put global development_settings_enabled 1 || echo "WARN: Failed to set development_settings_enabled"
adb shell settings put global window_animation_scale 0.0 || echo "WARN: Failed to set window_animation_scale"
adb shell settings put global transition_animation_scale 0.0 || echo "WARN: Failed to set transition_animation_scale"
adb shell settings put global animation_duration_scale 0.0 || echo "WARN: Failed to set animation_duration_scale"
adb shell settings put global network_recommendations_enabled 0 || echo "WARN: Failed to set network_recommendations_enabled"
adb shell settings put secure autofill_service null || echo "WARN: Failed to set autofill_service"
adb shell settings put secure spell_checker_enabled 0 || echo "WARN: Failed to set spell_checker_enabled"
adb shell settings put secure show_ime_with_hard_keyboard 0 || echo "WARN: Failed to set show_ime_with_hard_keyboard"
adb shell settings put system pointer_location 1 || echo "WARN: Failed to set pointer_location"
adb shell pm disable-user com.google.android.inputmethod.latin || echo "WARN: Failed to disable inputmethod.latin"
adb shell pm disable-user com.google.android.tts || echo "WARN: Failed to disable tts"
adb shell pm disable-user com.google.android.googlequicksearchbox || echo "WARN: Failed to disable googlequicksearchbox"
echo "--- Настройка эмулятора завершена ---"

# === КОНЕЦ БЛОКА ===


# === Логирование Logcat (если включено) ===
if [ "$SHOW_LOGCAT" == "true" ]; then
    # Запускает adb logcat в фоне для отображения логов эмулятора
    # Фильтрует ошибки (level E) и ищет ключевые слова для крашей/исключений
    adb logcat *:E | grep -iE "crash|exception|error" &
fi
# === Конец логирования Logcat ===


# === Функция проверки текущего фокуса активности ===
# Эта функция пытается убедиться, что эмулятор находится на главном экране (лаунчере)
# и не висит в состоянии ANR (Application Not Responding) для SystemUI.
# Запсукаем в фоне и держим в работе все время работы контейнера
function check_current_focus() {
  printf "==> Checking emulator running activity \n"
  target="com.google.android.apps.nexuslauncher.NexusLauncherActivity" # Активити которое мы считаем нормальным
  error_target="Application Not Responding: com.android.systemui}" # Ошибка которую мы ловим

  while true; do
    result=$(adb shell dumpsys window 2>/dev/null | grep -i mCurrentFocus) # Получаем нынешнюю активити

    if [[ $result == *"$error_target"* ]]; then
      # Получили что текущая активность ошибочная
      printf "==>  Activity is NOT okay: \n"
      printf "$result\n"
      adb shell input keyevent KEYCODE_HOME # Нажимаем на кнопку домой
      printf "==> Menu button is pressed \n"
    else
      # Активити нормальная
      printf "==> Activity is OKEY: \n"
      printf "$result\n"
    fi
    sleep 10
  done
}

# Запускаем проверку фокуса активности в фоне.
check_current_focus &

# === Запуск Appium сервера ===
# Используем полный путь к бинарнику appium для надежности.
# -a 0.0.0.0: Appium будет слушать на всех сетевых интерфейсах
# -p "$PORT": Порт для Appium (по умолчанию 4444)
# --log-timestamp: Добавляет метки времени в логи
# --log-no-colors: Отключает цветной вывод в логах (для лучшего парсинга в логах контейнера)
# ${APPIUM_ARGS}: Дополнительные аргументы для Appium
# & запускает в фоне
/opt/node_modules/.bin/appium -a 0.0.0.0 -p "$PORT" --log-timestamp --log-no-colors ${APPIUM_ARGS}  &
APPIUM_PID=$! # Сохраняем PID Appium для чистки
# === Конец запуска Appium ===


# === Ожидание завершения фоновых процессов ===
# Команда 'wait' без аргументов будет ждать завершения ВСЕХ фоновых процессов (&).
# Скрипт будет работать до тех пор, пока запущен хотя бы один из фоновых процессов (эмулятор, Appium, Xvnc, Xvfb).
wait
# === Конец скрипта ===