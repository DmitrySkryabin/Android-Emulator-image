# Сборка мобильного эмулятора новых версий Android без сервисов Google Play
# Для сборки с Google Play – используйте "google_apis_playstore" в EMULATOR_IMAGE_TYPE

# Данные для сборки разных платформ, которые нужно указать как аргументы далее по файлу:

# ┌────────────┬────────────┬─────────────┬─────────────┐
# │ Mobile 11  │ mobile_11  │ android-30  │ google_apis │
# ├────────────┼────────────┼─────────────┼─────────────┤
# │ Mobile 12  │ mobile_12  │ android-32  │ google_apis │
# │ Mobile 13  │ mobile_13  │ android-33  │ google_apis │
# │ Mobile 14  │ mobile_14  │ android-34  │ google_apis │
# │ TV 9       │ atv_9      │ android-28  │ android-tv  │
# └────────────┴────────────┴─────────────┴─────────────┘


FROM ubuntu:20.04

# Если нужна последняя версия Appium – пишем "latest"
# ARG APPIUM_VERSION="2.16.0"
# ARG UIAUTOMATOR_VERSION="3.0.1"
ARG APPIUM_VERSION="2.5.1"
ARG UIAUTOMATOR_VERSION="3.0.1"

# Replace AVD_NAME with information in table
ARG AVD_NAME="mobile_13"
ENV AVD_NAME=${AVD_NAME}

# Replace PLATFORM with information in table
ARG PLATFORM="android-33"

# Replace EMULATOR_IMAGE_TYPE with information in table
ARG EMULATOR_IMAGE_TYPE="google_apis"

# google_apis
ARG ANDROID_ABI="x86_64"
ARG BUILD_TOOLS="build-tools;35.0.0"

# Если собираем Android 11-13, оставляем как ниже
ARG EMULATOR_BINARIES="emulator-linux_x64-10696886.zip"

# Если собираем Android 14, комменируем строку выше и раскомментируем ту, что ниже
# ARG EMULATOR_BINARIES="emulator-linux_x64-11237101.zip"

# --- Установка основных зависимостей и Node.js/Appium ---
RUN \
    apt update && \
    # apt remove -y libcurl4 && \
    apt install -y apt-transport-https ca-certificates tzdata locales curl gnupg && \
	curl --silent --location https://deb.nodesource.com/setup_18.x | bash - && \
	apt install -y --no-install-recommends \
	    curl \
	    iproute2 \
	    nodejs \
	    openjdk-8-jdk-headless \
	    unzip \
	    xvfb \
	    libpulse0 \
		libxcomposite1 \
		libxcursor1 \
		libxi6 \
		libasound2 \
        fluxbox \
        x11vnc \
        feh \
        wmctrl \
	    libglib2.0-0 \
        libcurl4 && \
    # Обновляем хеш команд после установки nodejs/npm (Необходимо для выполнения npm в следующем шаге RUN или в текущем, если объединить)
    hash -r && \
    # --- Очистка после установки apt (добавлено для уменьшения размера) ---
    apt autoremove -y && \
    apt clean && \
    rm -Rf /var/lib/apt/lists/* && rm -Rf /tmp/*

# --- Установка Appium (вынесена в отдельный RUN, как в вашем оригинале) ---
RUN \
    cd / && \
    npm install --prefix ./opt/ appium@$APPIUM_VERSION --drivers=uiautomator2@$UIAUTOMATOR_VERSION && \
    # --- Очистка кэша npm (добавлено для уменьшения размера) ---
    npm cache clean --force

COPY android.conf /etc/ld.so.conf.d/
COPY fluxbox/aerokube /usr/share/fluxbox/styles/
COPY fluxbox/init /root/.fluxbox/
COPY fluxbox/aerokube.png /usr/share/images/fluxbox/

ENV ANDROID_HOME=/opt/android-sdk-linux
ENV PATH=/opt/android-sdk-linux/platform-tools:/opt/android-sdk-linux/tools:/opt/android-sdk-linux/tools/bin:/opt/android-sdk-linux/emulator:$PATH
ENV LD_LIBRARY_PATH=${ANDROID_HOME}/emulator/lib64:${ANDROID_HOME}/emulator/lib64/gles_swiftshader:${ANDROID_HOME}/emulator/lib64/qt/lib:${ANDROID_HOME}/emulator/lib64/vulkan:${LD_LIBRARY_PATH}
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

ARG EMULATOR_IMAGE="system-images;${PLATFORM};${EMULATOR_IMAGE_TYPE};${ANDROID_ABI}"

ARG SDCARD_SIZE="64"
ARG USERDATA_SIZE="2048"

ARG SDK_BINARIES="sdk-tools-linux-4333796.zip"

# --- Объединенный RUN для скачивания SDK, установки, создания AVD и очистки ---
RUN \
	# Скачивание SDK и эмулятора
	curl -o /tmp/${EMULATOR_BINARIES} https://dl.google.com/android/repository/${EMULATOR_BINARIES} && \
	curl -o /tmp/${SDK_BINARIES} https://dl.google.com/android/repository/${SDK_BINARIES} && \
	# Создание директорий
	mkdir -p /opt/android-sdk-linux /root/.config/Android\ Open\ Source\ Project/ && \
	mkdir -p /opt/android-emulator /root/.config/Android\ Open\ Source\ Project/ && \
	# Распаковка
	unzip -q /tmp/${SDK_BINARIES} -d /opt/android-sdk-linux && \
	unzip -q /tmp/${EMULATOR_BINARIES} -d /opt/android-emulator && \
	# --- Удаление временных архивов сразу после распаковки (уже было в оригинале, сохранено) ---
	rm /tmp/${SDK_BINARIES} && \
	rm /tmp/${EMULATOR_BINARIES} && \
	# Принятие лицензий SDK (необходимо перед установкой компонентов)
	yes | sdkmanager --licenses && \
	# Установка компонентов SDK
	sdkmanager "emulator" "tools" "platform-tools" "$BUILD_TOOLS" "platforms;$PLATFORM" "$EMULATOR_IMAGE" && \
	# Копирование эмулятора в папку SDK
    cp -vr /opt/android-emulator/emulator /opt/android-sdk-linux && \
    # --- Удаление временной папки эмулятора (добавлено для уменьшения размера) ---
    rm -rf /opt/android-emulator && \
	# Создание AVD - Исправлено: использован if/else вместо ( ... ) для совместимости с /bin/sh
    echo "no" | avdmanager create avd -n "$AVD_NAME" -k "$EMULATOR_IMAGE" --abi "$ANDROID_ABI" && \
	# Обновление кеша библиотек
	ldconfig && \
	# Изменение размера userdata.img - Исправлено: использован || вместо ( ... || ... ) для совместимости с /bin/sh
    resize2fs /root/.android/avd/$AVD_NAME.avd/userdata.img "$USERDATA_SIZE"M || \
    /opt/android-sdk-linux/emulator/qemu-img resize -f raw /root/.android/avd/$AVD_NAME.avd/userdata.img "$USERDATA_SIZE"M && \
    # Условное перемещение userdata.img - Исправлено: убраны группирующие скобки ( ... ) для совместимости с /bin/sh
	[ -z "$REPLACE_IMG" ] || mv /root/.android/avd/$AVD_NAME.avd/userdata.img /root/.android/avd/$AVD_NAME.avd/userdata-qemu.img && \
	# --- Удаление userdata.img из папки образа системы (уже было в оригинале, сохранено) ---
	rm /opt/android-sdk-linux/system-images/$PLATFORM/$EMULATOR_IMAGE_TYPE/"$ANDROID_ABI"/userdata.img


ENV ENABLE_VNC="true"
ENV SHOW_LOGCAT="false"

COPY ["Emulator.conf", "/root/.config/Android Open Source Project/Emulator.conf"]

# Entrypoint
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]