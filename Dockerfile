FROM openjdk:18-jdk-slim

LABEL maintainer "Amr Salem"

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /
#=============================
# Install Dependenices 
#=============================
SHELL ["/bin/bash", "-c"]   

RUN apt update && apt install -y \
    # Базовые утилиты
    curl \        
    sudo \         
    wget \         
    unzip \         
    bzip2 \       
    
    # Графические библиотеки (критичны для эмулятора)
    # Direct Rendering Manager (для GPU)
    libdrm-dev \    
    # Обработка раскладки клавиатуры
    libxkbcommon-dev \ 
    # Generic Buffer Management (графика)
    libgbm-dev \ 
    # Звуковая система ALSA (даже без аудио нужен)   
    libasound-dev \ 
     # Network Security Services (для WebView)
    libnss3 \    
     # Поддержка курсора мыши  
    libxcursor1 \  
    # PulseAudio (многие приложения требуют)
    libpulse-dev \ 
    # Sync между процессами X11 
    libxshmfence-dev \ 
    
    # X11 и VNC
    xauth \        
    xvfb \         
    x11vnc \       
    fluxbox \      
    wmctrl \      
    
    # Дополнительные зависимости
    libdbus-glib-1-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
#==============================
# Android SDK ARGS
#==============================
ARG ARCH="x86_64" 
ARG TARGET="google_apis" 
ARG API_LEVEL="33"
ARG BUILD_TOOLS="33.0.0"
ARG ANDROID_ARCH=${ANDROID_ARCH_DEFAULT}
ARG ANDROID_API_LEVEL="android-${API_LEVEL}"
ARG ANDROID_APIS="${TARGET};${ARCH}"
ARG EMULATOR_PACKAGE="system-images;${ANDROID_API_LEVEL};${ANDROID_APIS}"
ARG PLATFORM_VERSION="platforms;${ANDROID_API_LEVEL}"
ARG BUILD_TOOL="build-tools;${BUILD_TOOLS}"
ARG ANDROID_CMD="commandlinetools-linux-11076708_latest.zip"
ARG ANDROID_SDK_PACKAGES="${EMULATOR_PACKAGE} ${PLATFORM_VERSION} ${BUILD_TOOL} platform-tools emulator"

#==============================
# Set JAVA_HOME - SDK
#==============================
ENV ANDROID_SDK_ROOT=/opt/android
ENV PATH "$PATH:$ANDROID_SDK_ROOT/cmdline-tools/tools:$ANDROID_SDK_ROOT/cmdline-tools/tools/bin:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/build-tools/${BUILD_TOOLS}"
ENV DOCKER="true"

#============================================
# Install required Android CMD-line tools
#============================================
RUN wget https://dl.google.com/android/repository/${ANDROID_CMD} -P /tmp && \
    unzip -d $ANDROID_SDK_ROOT /tmp/$ANDROID_CMD && \
    mkdir -p $ANDROID_SDK_ROOT/cmdline-tools/tools && \
    cd $ANDROID_SDK_ROOT/cmdline-tools && \
    mv NOTICE.txt source.properties bin lib tools/ && \
    cd $ANDROID_SDK_ROOT/cmdline-tools/tools && ls

#============================================
# Install required package using SDK manager
#============================================
RUN yes Y | sdkmanager --licenses 
RUN yes Y | sdkmanager --verbose --no_https ${ANDROID_SDK_PACKAGES} 

#============================================
# Create required emulator
#============================================
ARG EMULATOR_NAME="pixel_4"
ARG EMULATOR_DEVICE="pixel_4"
ENV EMULATOR_NAME=$EMULATOR_NAME
ENV DEVICE_NAME=$EMULATOR_DEVICE

RUN echo "no" | avdmanager --verbose create avd --force \
    --name "${EMULATOR_NAME}" \
    --device "${EMULATOR_DEVICE}" \
    --package "${EMULATOR_PACKAGE}"

#====================================
# Install latest nodejs, npm & appium
#====================================
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash && \
    apt-get -qqy install nodejs && \
    npm install -g npm && \
    npm i -g appium --unsafe-perm=true --allow-root && \
    appium driver install uiautomator2 && \
    exit 0 && \
    npm cache clean && \
    apt-get remove --purge -y npm && \  
    apt-get autoremove --purge -y && \
    apt-get clean && \
    rm -Rf /tmp/* && rm -Rf /var/lib/apt/lists/*


#===================
# Alias
#===================
ENV EMU=./start_emu.sh
ENV EMU_HEADLESS=./start_emu_headless.sh
ENV VNC=./start_vnc.sh
ENV APPIUM=./start_appium.sh


#===================
# Ports
#===================
ENV APPIUM_PORT=4444
ENV GRPC_PORT=5666
ENV VNC_PASSWORD=selenoid

#=========================
# Copying Scripts to root
#=========================
COPY . /

RUN chmod a+x start_vnc.sh && \
    chmod a+x start_emu.sh && \
    chmod a+x start_appium.sh && \
    chmod a+x start_emu_headless.sh 

RUN chmod a+x entrypoint.sh

#=======================
# framework entry point
#=======================
ENV GPU_MODE=guest
ENV RAM_SIZE=2048
ENV CPU_SIZE=2


# Установка simplelauncher
RUN mkdir -p /opt/app && \
    wget https://github.com/SimpleMobileTools/Simple-Launcher/releases/download/5.1.1/launcher-fdroid-release.apk -O /opt/app/simple-launcher.apk && \
    chmod 644 /opt/app/simple-launcher.apk
RUN chmod a+x start_install_launcher.sh

# Установка apk до запуска appium
RUN chmod a+x start_install_apk.sh

# Скрипт для перезапуска pixel launch
RUN chmod a+x start_reboot_pixel_launcher.sh


RUN echo "hw.ramSize=${RAM_SIZE}" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "vm.heapSize=256" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    # echo "hw.gpu.mode=swiftshader_indirect" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "hw.gpu.enabled=yes" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "hw.keyboard=yes" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "hw.camera.back=none" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "hw.camera.front=none" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "hw.audioInput=no" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "hw.audioOutput=no" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "hw.device.hash2=MD5:2fa0e16c8cceb7d385183284107c0c88" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini && \
    echo "net.dns1=8.8.8.8" >> /root/.android/avd/${EMULATOR_DEVICE}.avd/config.ini 

RUN mkdir -p "/root/.config/Android Open Source Project" 
RUN cp Emulator.conf "/root/.config/Android Open Source Project/Emulator.conf"

ENTRYPOINT ["/entrypoint.sh"]
