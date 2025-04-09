#!/bin/bash


# URL для скачивания APK
APK_URL="${APK_URL}"
# Имя файла для сохранения
APK_FILE="app.apk"

# Скачивание APK с помощью wget
if wget -O "$APK_FILE" "$APK_URL"; then
    echo "Скачивание завершено: $APK_FILE"
    
    # Извлечение имени пакета с помощью aapt
    PACKAGE_NAME=$(aapt dump badging "$APK_FILE" | grep package:\ name | awk -F"'" '{print $2}')
    
    if [ -z "$PACKAGE_NAME" ]; then
        echo "Не удалось извлечь имя пакета."
        exit 1
    fi

    echo "Имя пакета: $PACKAGE_NAME"
    
    # Установка APK на устройство (предполагается, что adb установлен и устройство подключено)
    adb install -r "$APK_FILE"
    
    if [ $? -eq 0 ]; then
        echo "Установка завершена успешно."
        
        # # Запрос необходимых разрешений (замените на ваши конкретные разрешения)
        # PERMISSIONS=(
        #     "android.permission.ACCESS_FINE_LOCATION"
        #     "android.permission.ACCESS_COARSE_LOCATION"
        #     # "android.permission.INTERNET"
        #     # "android.permission.RECEIVE_BOOT_COMPLETED"
        #     # "android.permission.VIBRATE"
        #     # "android.permission.ACCESS_NOTIFICATION_POLICY"
        #     # Добавьте другие необходимые разрешения здесь
        # )

        # for PERMISSION in "${PERMISSIONS[@]}"; do
        #     adb shell pm grant "$PACKAGE_NAME" "$PERMISSION"  # Используем извлеченное имя пакета
        # done
        
        # echo "Все необходимые разрешения предоставлены."
        
        SDK_VERSION=$(adb shell getprop ro.build.version.sdk)
        # Проверяем, что версия SDK больше 32
        if [ "$SDK_VERSION" -ge 33 ]; then
            adb shell pm set-permission-flags $PACKAGE_NAME android.permission.ACCESS_NOTIFICATION_POLICY user-set
            # adb shell pm clear-permission-flags PACKAGE_NAME \
            # android.permission.POST_NOTIFICATIONS user-fixed
            echo "Версия SDK ($SDK_VERSION) больше или равна 33. Продолжаем выполнение..."
            adb shell appops set --uid "$PACKAGE_NAME" POST_NOTIFICATIONS allow || echo "Не удалось установить разрешение POST_NOTIFICATIONS."
        else
            echo "Версия SDK ($SDK_VERSION) не больше или равна 33. Не прописываем POST_NOTIFICATIONS allow."
        fi
        
    else
        echo "Ошибка при установке APK."
    fi
else
    echo "Не удалось скачать APK. Пропускаем установку."
fi

# Удаление загруженного файла (по желанию)
rm -f "$APK_FILE"