#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Всеобъемлющий скрипт для очистки нерелевантных системных данных Windows.
    Очищает временные файлы, кэши обновлений, корзину, логи, кэши браузеров,
    кэши миниатюр, файлы оптимизации доставки, кэши шейдеров и др.
    Также замеряет и выводит объем освобожденного места.

.DESCRIPTION
    Этот скрипт выполняет следующие операции очистки:
    - Очистка системных временных файлов (C:\Windows\Temp)
    - Очистка временных файлов пользователя (%TEMP%)
    - Очистка кэша Windows Update (SoftwareDistribution\Download)
    - Очистка корзины для всех дисков
    - Очистка кэша DNS
    - Очистка кэша Windows Store
    - Очистка журнала событий Windows (с улучшенной обработкой ошибок)
    - Очистка папки Prefetch (оптимизация)
    - Очистка кэша миниатюр (Thumbnail Cache)
    - Очистка файлов оптимизации доставки (Delivery Optimization Files)
    - Очистка кэша DirectX Shader (для NVIDIA, AMD, общие)
    - Очистка файлов отчетов об ошибках Windows (Windows Error Reporting)
    - Удаление пустых папок в Temp-директориях
    - Очистка кэшей популярных браузеров (Chrome, Edge)

    Скрипт замеряет свободное место на системном диске до и после очистки.

.NOTES
    Автор: Gemini AI
    Дата: 27 июля 2025
    Версия: 1.1

.EXAMPLE
    .\Clean-WindowsSystem.ps1
    Запускает скрипт для всеобъемлющей очистки системы.
#>

function Write-HostGreen {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-HostYellow {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-HostRed {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Get-DriveFreeSpaceMB {
    param([string]$DriveLetter = "C")
    try {
        $drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
        # Возвращаем свободное место в мегабайтах
        return [Math]::Round($drive.Free / 1MB, 2)
    } catch {
        Write-HostRed "Не удалось получить свободное место для диска $($DriveLetter): $($_.Exception.Message)"
        return 0
    }
}

Write-HostGreen "Начало всеобъемлющей очистки системы Windows..."
Write-HostYellow "Внимание: Для выполнения этого скрипта требуются права администратора."
Write-HostYellow "Некоторые операции могут потребовать перезагрузки для полного вступления в силу."
Write-Host ""

# Замер свободного места до очистки
$freeSpaceBeforeMB = Get-DriveFreeSpaceMB -DriveLetter "C"
Write-HostGreen "Свободно на диске C: до очистки: $($freeSpaceBeforeMB) MB"
Write-Host ""

# --- 1. Очистка системных временных файлов ---
Write-HostGreen "1/13: Очистка системных временных файлов (C:\Windows\Temp)..."
try {
    Get-ChildItem -Path C:\Windows\Temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "C:\Windows\Temp очищен." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить C:\Windows\Temp: $($_.Exception.Message)"
}

# --- 2. Очистка временных файлов пользователя ---
Write-HostGreen "2/13: Очистка временных файлов пользователя (%TEMP%)..."
try {
    $userTempPath = [System.IO.Path]::GetTempPath()
    Get-ChildItem -Path $userTempPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "$userTempPath очищен." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить %TEMP%: $($_.Exception.Message)"
}

# --- 3. Очистка кэша Windows Update ---
Write-HostGreen "3/13: Очистка кэша Windows Update (SoftwareDistribution\Download)..."
try {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path C:\Windows\SoftwareDistribution\Download\* -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Host "Кэш Windows Update очищен." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить кэш Windows Update: $($_.Exception.Message)"
}

# --- 4. Очистка корзины для всех дисков ---
Write-HostGreen "4/13: Очистка корзины для всех дисков..."
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "Корзина очищена." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить корзину: $($_.Exception.Message)"
}

# --- 5. Очистка кэша DNS ---
Write-HostGreen "5/13: Очистка кэша DNS..."
try {
    ipconfig /flushdns
    Write-Host "Кэш DNS очищен." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить кэш DNS: $($_.Exception.Message)"
}

# --- 6. Очистка кэша Windows Store ---
Write-HostGreen "6/13: Очистка кэша Windows Store..."
try {
    & "wsreset.exe" -c # -c запускает без UI
    Start-Sleep -Seconds 5 # Даем время на выполнение
    Write-Host "Кэш Windows Store очищен." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить кэш Windows Store: $($_.Exception.Message)"
}

# --- 7. Очистка журнала событий Windows ---
Write-HostGreen "7/13: Очистка журнала событий Windows..."
try {
    $logsToClear = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object {
        $_.IsEnabled -and $_.IsLogWritable -and
        ($_.LogName -notmatch "Microsoft-Windows-Diagnostics-Performance/Operational" -and
         $_.LogName -notmatch "Microsoft-Windows-USBVideo/Analytic" -and
         $_.LogName -notmatch "Microsoft-Windows-Kernel-EventTracing/Event" -and
         $_.LogName -notmatch "ForwardedEvents" -and
         $_.LogName -notmatch "HardwareEvents") # Добавил HardwareEvents, часто бывает недоступен
    }

    $clearedCount = 0
    foreach ($log in $logsToClear) {
        try {
            Clear-WinEvent -LogName $log.LogName -Confirm:$false -ErrorAction Stop
            #Write-Host "Журнал событий '$($log.LogName)' очищен." -ForegroundColor DarkGray # Закомментировано для уменьшения вывода
            $clearedCount++
        } catch [System.UnauthorizedAccessException] {
            Write-HostYellow "Доступ запрещен для очистки журнала событий '$($log.LogName)': $($_.Exception.Message)"
        } catch {
            Write-HostYellow "Не удалось очистить журнал событий '$($log.LogName)': $($_.Exception.Message)"
        }
    }
    Write-Host "Журналы событий: $clearedCount очищено, некоторые пропущены из-за ошибок или настроек." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Общая ошибка при обработке журналов событий: $($_.Exception.Message)"
}

# --- 8. Очистка папки Prefetch ---
Write-HostGreen "8/13: Очистка папки Prefetch..."
try {
    $prefetchPath = "C:\Windows\Prefetch"
    if (Test-Path $prefetchPath) {
        # Удаляем файлы старше 7 дней
        Get-ChildItem -Path $prefetchPath -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force -ErrorAction SilentlyContinue
        # Удаляем файлы, оставляя только последние 1000, если их слишком много
        $files = Get-ChildItem -Path $prefetchPath -File | Sort-Object LastWriteTime -Descending
        if ($files.Count -gt 1000) {
            $filesToDelete = $files | Select-Object -Skip 1000
            $filesToDelete | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "Удалено $($filesToDelete.Count) старых файлов Prefetch." -ForegroundColor DarkGray
        }
        Write-Host "Папка Prefetch оптимизирована." -ForegroundColor DarkGray
    } else {
        Write-HostYellow "Папка Prefetch не найдена."
    }
} catch {
    Write-HostRed "Не удалось очистить/оптимизировать папку Prefetch: $($_.Exception.Message)"
}

# --- 9. Очистка кэша миниатюр (Thumbnail Cache) ---
Write-HostGreen "9/13: Очистка кэша миниатюр (Thumbnail Cache)..."
try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue # Останавливаем Проводник для полного удаления
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    Start-Process explorer # Запускаем Проводник обратно
    Write-Host "Кэш миниатюр очищен." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить кэш миниатюр: $($_.Exception.Message)"
}

# --- 10. Очистка файлов оптимизации доставки (Delivery Optimization Files) ---
Write-HostGreen "10/13: Очистка файлов оптимизации доставки (Delivery Optimization Files)..."
try {
    # Сначала останавливаем службу
    Stop-Service -Name Dosvc -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    # Перезапускаем службу
    Start-Service -Name Dosvc -ErrorAction SilentlyContinue
    Write-Host "Файлы оптимизации доставки очищены." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить файлы оптимизации доставки: $($_.Exception.Message)"
}

# --- 11. Очистка кэша DirectX Shader ---
Write-HostGreen "11/13: Очистка кэша DirectX Shader..."
try {
    # Общие кэши DirectX
    Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    # Кэши NVIDIA
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\NVIDIA Corporation\NV_Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    # Кэши AMD (пути могут варьироваться, это общие)
    Remove-Item -Path "$env:LOCALAPPDATA\AMD\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\AMD\ATI\ACE\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Кэши DirectX Shader очищены." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить кэши DirectX Shader: $($_.Exception.Message)"
}

# --- 12. Очистка файлов отчетов об ошибках Windows (Windows Error Reporting) ---
Write-HostGreen "12/13: Очистка файлов отчетов об ошибках Windows..."
try {
    Remove-Item -Path "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\ProgramData\Microsoft\Windows\WER\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Файлы отчетов об ошибках очищены." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить файлы отчетов об ошибках Windows: $($_.Exception.Message)"
}

# --- 13. Удаление пустых папок в Temp-директориях ---
Write-HostGreen "13/13: Удаление пустых папок во временных директориях..."
try {
    $tempPaths = @("$env:LOCALAPPDATA\Temp", "C:\Windows\Temp")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
                ($_.GetFileSystemInfos()).Count -eq 0
            } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "Пустые папки удалены." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось удалить пустые папки: $($_.Exception.Message)"
}

# --- Дополнительно: Очистка кэшей браузеров (только примеры, для полных настроек лучше использовать встроенные функции браузеров) ---
Write-HostYellow "Примечание: Полная очистка кэшей браузеров требует закрытия браузеров и/или использования их встроенных средств."
Write-HostYellow "Пример очистки кэшей Chrome и Edge (базовые пути):"
try {
    # Chrome Cache (может иметь разные профили, например, Default, Profile 1 и т.д.)
    Get-ChildItem -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    # Edge Cache
    Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Кэши Chrome и Edge очищены (базовые)." -ForegroundColor DarkGray
} catch {
    Write-HostRed "Не удалось очистить кэши браузеров: $($_.Exception.Message)"
}


Write-Host ""
Write-HostGreen "Очистка системы Windows завершена!"

# Замер свободного места после очистки
$freeSpaceAfterMB = Get-DriveFreeSpaceMB -DriveLetter "C"
Write-HostGreen "Свободно на диске C: после очистки: $($freeSpaceAfterMB) MB"

$freedSpaceMB = $freeSpaceAfterMB - $freeSpaceBeforeMB
if ($freedSpaceMB -gt 0) {
    Write-HostGreen "Объем освобожденного места: $($freedSpaceMB) MB"
} elseif ($freedSpaceMB -lt 0) {
    Write-HostYellow "Внимание: Объем свободного места уменьшился на $($freedSpaceMB * -1) MB. Это может быть связано с фоновыми операциями системы."
} else {
    Write-HostYellow "Объем свободного места не изменился."
}

Write-Host "Для полного вступления некоторых изменений в силу, рекомендуется перезагрузить систему." -ForegroundColor Yellow
Read-Host "Нажмите Enter для выхода..."