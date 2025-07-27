@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

:: Настройки
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "INSTALL_DIR=%ProgramFiles%\ffmpeg"
set "ZIP_FILE=%TEMP%\ffmpeg.zip"
set "FFMPEG_EXE=%INSTALL_DIR%\ffmpeg-7.1.1-essentials_build\bin\ffmpeg.exe"

:: Проверка наличия ffmpeg.exe
if exist "%FFMPEG_EXE%" (
    echo ffmpeg найден по пути %FFMPEG_EXE%
) else (
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
)

:: Получаем путь к папке bin
for %%i in ("%FFMPEG_EXE%") do set "BIN_DIR=%%~dpi"
:: Убираем завершающий обратный слеш
set "BIN_DIR=%BIN_DIR:~0,-1%"

echo [3/4] Проверка и добавление %BIN_DIR% в PATH пользователя...

:: Получаем текущий пользовательский PATH из реестра
for /f "usebackq tokens=2*" %%A in (`reg query "HKCU\Environment" /v PATH 2^>nul ^| findstr PATH`) do (
    set "USER_PATH=%%B"
)

:: Если PATH пустой, просто добавляем
if not defined USER_PATH (
    set "NEW_PATH=%BIN_DIR%"
) else (
    :: Проверяем, нет ли уже BIN_DIR в PATH
    echo %USER_PATH% | findstr /i /c:"%BIN_DIR%" >nul
    if errorlevel 1 (
        set "NEW_PATH=%USER_PATH%;%BIN_DIR%"
    ) else (
        set "NEW_PATH=%USER_PATH%"
    )
)

:: Записываем обратно в реестр
reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%NEW_PATH%" /f >nul

echo [4/4] Установка завершена успешно.
echo Чтобы изменения вступили в силу, перезайдите в систему или выполните:
echo   refreshenv
echo Проверьте, запустив: ffmpeg -version
pause
endlocal
