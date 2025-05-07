# Сборка мобильного эмулятора новых версий Android без сервисов Google Play
# Для сборки с Google Play – используйте "google_apis_playstore" в EMULATOR_IMAGE_TYPE

# Данные для сборки разных платформ, которые нужно указать как аргументы далее по файлу:

# ┌────────────┬────────────┬─────────────┬─────────────┐
# │ Mobile 11  │ mobile_11  │ android-30  │ google_apis │
# ├────────────┼────────────┼─────────────┼─────────────┤
# │ Mobile 12  │ mobile_12  │ android-32  │ google_apis │
# │ Mobile 13  │ mobile_13  │ android-33  │ google_apis │
# │ Mobile 14  │ mobile_14  │ android-34  │ google_apis │
# │ TV 9       │ atv_9      │ android-28  │ android-tv  │
# └────────────┴────────────┴─────────────┴─────────────┘

# FROM golang:1.22 as go

# COPY tmp/devtools /devtools

# RUN \
#     apt-get update && \
#     wget -c http://ftp.us.debian.org/debian/pool/main/u/upx-ucl/upx-ucl_3.95-1_amd64.deb && \
#     apt-get install -y ./upx-ucl_3.95-1_amd64.deb && \
#     apt-get install -y libx11-dev && \
#     cd /devtools && \
#     GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" && \
#     upx /devtools/devtools

FROM ubuntu:20.04

# Если нужна последняя версия Appium – пишем "latest"
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


RUN \
    apt update && \
    apt remove -y libcurl4 && \
    apt install -y apt-transport-https ca-certificates tzdata locales libcurl4 curl gnupg && \
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
	    libglib2.0-0 && \
    apt-get clean && \
    rm -Rf /tmp/* && rm -Rf /var/lib/apt/lists/*

RUN \
    cd / && \
    npm install --prefix ./opt/ appium@$APPIUM_VERSION --drivers=uiautomator2@$UIAUTOMATOR_VERSION

COPY android.conf /etc/ld.so.conf.d/
COPY fluxbox/aerokube /usr/share/fluxbox/styles/
COPY fluxbox/init /root/.fluxbox/
COPY fluxbox/aerokube.png /usr/share/images/fluxbox/
# COPY --from=go /devtools/devtools /usr/bin/

ENV ANDROID_HOME=/opt/android-sdk-linux
ENV PATH=/opt/android-sdk-linux/platform-tools:/opt/android-sdk-linux/tools:/opt/android-sdk-linux/tools/bin:/opt/android-sdk-linux/emulator:$PATH
ENV LD_LIBRARY_PATH=${ANDROID_HOME}/emulator/lib64:${ANDROID_HOME}/emulator/lib64/gles_swiftshader:${ANDROID_HOME}/emulator/lib64/qt/lib:${ANDROID_HOME}/emulator/lib64/vulkan:${LD_LIBRARY_PATH}
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

ARG EMULATOR_IMAGE="system-images;${PLATFORM};${EMULATOR_IMAGE_TYPE};${ANDROID_ABI}"

ARG SDCARD_SIZE="64"
ARG USERDATA_SIZE="2048"

ARG SDK_BINARIES="sdk-tools-linux-4333796.zip"

RUN \
	curl -o /tmp/${EMULATOR_BINARIES} https://dl.google.com/android/repository/${EMULATOR_BINARIES} && \
	curl -o /tmp/${SDK_BINARIES} https://dl.google.com/android/repository/${SDK_BINARIES} && \
	mkdir -p /opt/android-sdk-linux /root/.config/Android\ Open\ Source\ Project/ && \
	mkdir -p /opt/android-emulator /root/.config/Android\ Open\ Source\ Project/ && \
	unzip -q /tmp/${SDK_BINARIES} -d /opt/android-sdk-linux && \
	unzip -q /tmp/${EMULATOR_BINARIES} -d /opt/android-emulator && \
	rm /tmp/${SDK_BINARIES} && \
	rm /tmp/${EMULATOR_BINARIES} && \
	yes | sdkmanager --licenses

RUN \
	sdkmanager "emulator" "tools" "platform-tools" "$BUILD_TOOLS" "platforms;$PLATFORM" "$EMULATOR_IMAGE" && \
	cp -vr /opt/android-emulator/emulator /opt/android-sdk-linux && \
	echo "no" | ( \
	    ([ -n "$AVD_NAME" ] && avdmanager create avd -n "$AVD_NAME" -k "$EMULATOR_IMAGE" --abi "$ANDROID_ABI" --device "$AVD_NAME" ) || \
	    avdmanager create avd -n "$AVD_NAME" -k "$EMULATOR_IMAGE" --abi "$ANDROID_ABI" \
    ) && \
	ldconfig && \
	( \
	    resize2fs /root/.android/avd/$AVD_NAME.avd/userdata.img "$USERDATA_SIZE"M || \
	    /opt/android-sdk-linux/emulator/qemu-img resize -f raw /root/.android/avd/$AVD_NAME.avd/userdata.img "$USERDATA_SIZE"M \
    ) && \
	([ -z "$REPLACE_IMG" ] || mv /root/.android/avd/$AVD_NAME.avd/userdata.img /root/.android/avd/$AVD_NAME.avd/userdata-qemu.img ) && \
	rm /opt/android-sdk-linux/system-images/$PLATFORM/$EMULATOR_IMAGE_TYPE/"$ANDROID_ABI"/userdata.img


ENV ENABLE_VNC="true"
ENV SHOW_LOGCAT="false"

COPY ["Emulator.conf", "/root/.config/Android Open Source Project/Emulator.conf"]
COPY emulator-snapshot.sh /usr/bin/

# Entrypoint
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]


# ENV AVD_NAME=${AVD_NAME}
# ENTRYPOINT ls /scripts  &&  /scripts/${AVD_NAME}/entrypoint.sh