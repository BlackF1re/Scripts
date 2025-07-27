@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

:: Скрипт установки ffmpeg и регистрации утилиты в PATH

:: Настройки
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "INSTALL_DIR=%ProgramFiles%\ffmpeg"
set "ZIP_FILE=%TEMP%\ffmpeg.zip"
set "FFMPEG_BIN_PATH=" :: Будет определен динамически

:: Проверка наличия ffmpeg.exe
echo [1/4] Проверка наличия FFmpeg...
for /d %%d in ("%INSTALL_DIR%\ffmpeg-*-essentials_build") do (
    if exist "%%d\bin\ffmpeg.exe" (
        set "FFMPEG_BIN_PATH=%%d\bin"
        echo ffmpeg уже найден по пути: %%d\bin\ffmpeg.exe
        goto :path_check
    )
)

echo [1/4] Скачивание FFmpeg...
powershell -Command "Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%ZIP_FILE%' -UseBasicParsing"
if errorlevel 1 (
    echo Ошибка при скачивании FFmpeg.
    pause
    exit /b 1
)

echo [2/4] Распаковка в %INSTALL_DIR%...
rmdir /s /q "%INSTALL_DIR%" 2>nul
powershell -Command "Expand-Archive -LiteralPath '%ZIP_FILE%' -DestinationPath '%INSTALL_DIR%' -Force"
if errorlevel 1 (
    echo Ошибка при распаковке FFmpeg.
    pause
    exit /b 1
)

:: Динамическое определение папки bin после распаковки
for /d %%d in ("%INSTALL_DIR%\ffmpeg-*-essentials_build") do (
    if exist "%%d\bin\ffmpeg.exe" (
        set "FFMPEG_BIN_PATH=%%d\bin"
        goto :path_check
    )
)

echo Ошибка: Не удалось найти папку bin FFmpeg после установки.
pause
exit /b 1

:path_check
if not defined FFMPEG_BIN_PATH (
    echo Ошибка: Путь к FFmpeg bin не определен.
    pause
    exit /b 1
)

echo [3/4] Проверка и добавление %FFMPEG_BIN_PATH% в PATH пользователя...

:: Получаем текущий пользовательский PATH из реестра
for /f "usebackq tokens=2*" %%A in (`reg query "HKCU\Environment" /v PATH 2^>nul ^| findstr PATH`) do (
    set "USER_PATH=%%B"
)

:: Если PATH пустой, просто добавляем
if not defined USER_PATH (
    set "NEW_PATH=%FFMPEG_BIN_PATH%"
) else (
    :: Проверяем, нет ли уже BIN_DIR в PATH (case-insensitive)
    echo !USER_PATH! | findstr /i /c:"%FFMPEG_BIN_PATH:/\=\\%" >nul
    if errorlevel 1 (
        set "NEW_PATH=!USER_PATH!;%FFMPEG_BIN_PATH%"
    ) else (
        set "NEW_PATH=!USER_PATH!"
    )
)

:: Записываем обратно в реестр
reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%NEW_PATH%" /f >nul

echo [4/4] Установка завершена успешно.
echo Чтобы изменения вступили в силу, пожалуйста, перезапустите командную строку,
echo PowerShell или перезагрузите систему.
echo Проверьте, запустив: ffmpeg -version
pause
endlocal