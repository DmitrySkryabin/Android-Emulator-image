#!/bin/bash

# Полностью убить процесс
adb shell am force-stop com.google.android.apps.nexuslauncher

# Перезапустить (лаунчер автоматически перезагрузится)
adb shell monkey -p com.google.android.apps.nexuslauncher -c android.intent.category.HOME 1

sleep 10