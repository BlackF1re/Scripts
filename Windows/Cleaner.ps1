#Requires -RunAsAdministrator

<#
.SYNOPSIS
    ������������� ������ ��� ������� ������������� ��������� ������ Windows.
    ������� ��������� �����, ���� ����������, �������, ����, ���� ���������,
    ���� ��������, ����� ����������� ��������, ���� �������� � ��.
    ����� �������� � ������� ����� �������������� �����.

.DESCRIPTION
    ���� ������ ��������� ��������� �������� �������:
    - ������� ��������� ��������� ������ (C:\Windows\Temp)
    - ������� ��������� ������ ������������ (%TEMP%)
    - ������� ���� Windows Update (SoftwareDistribution\Download)
    - ������� ������� ��� ���� ������
    - ������� ���� DNS
    - ������� ���� Windows Store
    - ������� ������� ������� Windows (� ���������� ���������� ������)
    - ������� ����� Prefetch (�����������)
    - ������� ���� �������� (Thumbnail Cache)
    - ������� ������ ����������� �������� (Delivery Optimization Files)
    - ������� ���� DirectX Shader (��� NVIDIA, AMD, �����)
    - ������� ������ ������� �� ������� Windows (Windows Error Reporting)
    - �������� ������ ����� � Temp-�����������
    - ������� ����� ���������� ��������� (Chrome, Edge)

    ������ �������� ��������� ����� �� ��������� ����� �� � ����� �������.

.NOTES
    �����: Gemini AI
    ����: 27 ���� 2025
    ������: 1.1

.EXAMPLE
    .\Clean-WindowsSystem.ps1
    ��������� ������ ��� ������������� ������� �������.
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
        # ���������� ��������� ����� � ����������
        return [Math]::Round($drive.Free / 1MB, 2)
    } catch {
        Write-HostRed "�� ������� �������� ��������� ����� ��� ����� $($DriveLetter): $($_.Exception.Message)"
        return 0
    }
}

Write-HostGreen "������ ������������� ������� ������� Windows..."
Write-HostYellow "��������: ��� ���������� ����� ������� ��������� ����� ��������������."
Write-HostYellow "��������� �������� ����� ����������� ������������ ��� ������� ���������� � ����."
Write-Host ""

# ����� ���������� ����� �� �������
$freeSpaceBeforeMB = Get-DriveFreeSpaceMB -DriveLetter "C"
Write-HostGreen "�������� �� ����� C: �� �������: $($freeSpaceBeforeMB) MB"
Write-Host ""

# --- 1. ������� ��������� ��������� ������ ---
Write-HostGreen "1/13: ������� ��������� ��������� ������ (C:\Windows\Temp)..."
try {
    Get-ChildItem -Path C:\Windows\Temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "C:\Windows\Temp ������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� C:\Windows\Temp: $($_.Exception.Message)"
}

# --- 2. ������� ��������� ������ ������������ ---
Write-HostGreen "2/13: ������� ��������� ������ ������������ (%TEMP%)..."
try {
    $userTempPath = [System.IO.Path]::GetTempPath()
    Get-ChildItem -Path $userTempPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "$userTempPath ������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� %TEMP%: $($_.Exception.Message)"
}

# --- 3. ������� ���� Windows Update ---
Write-HostGreen "3/13: ������� ���� Windows Update (SoftwareDistribution\Download)..."
try {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path C:\Windows\SoftwareDistribution\Download\* -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Host "��� Windows Update ������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ��� Windows Update: $($_.Exception.Message)"
}

# --- 4. ������� ������� ��� ���� ������ ---
Write-HostGreen "4/13: ������� ������� ��� ���� ������..."
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "������� �������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� �������: $($_.Exception.Message)"
}

# --- 5. ������� ���� DNS ---
Write-HostGreen "5/13: ������� ���� DNS..."
try {
    ipconfig /flushdns
    Write-Host "��� DNS ������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ��� DNS: $($_.Exception.Message)"
}

# --- 6. ������� ���� Windows Store ---
Write-HostGreen "6/13: ������� ���� Windows Store..."
try {
    & "wsreset.exe" -c # -c ��������� ��� UI
    Start-Sleep -Seconds 5 # ���� ����� �� ����������
    Write-Host "��� Windows Store ������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ��� Windows Store: $($_.Exception.Message)"
}

# --- 7. ������� ������� ������� Windows ---
Write-HostGreen "7/13: ������� ������� ������� Windows..."
try {
    $logsToClear = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object {
        $_.IsEnabled -and $_.IsLogWritable -and
        ($_.LogName -notmatch "Microsoft-Windows-Diagnostics-Performance/Operational" -and
         $_.LogName -notmatch "Microsoft-Windows-USBVideo/Analytic" -and
         $_.LogName -notmatch "Microsoft-Windows-Kernel-EventTracing/Event" -and
         $_.LogName -notmatch "ForwardedEvents" -and
         $_.LogName -notmatch "HardwareEvents") # ������� HardwareEvents, ����� ������ ����������
    }

    $clearedCount = 0
    foreach ($log in $logsToClear) {
        try {
            Clear-WinEvent -LogName $log.LogName -Confirm:$false -ErrorAction Stop
            #Write-Host "������ ������� '$($log.LogName)' ������." -ForegroundColor DarkGray # ���������������� ��� ���������� ������
            $clearedCount++
        } catch [System.UnauthorizedAccessException] {
            Write-HostYellow "������ �������� ��� ������� ������� ������� '$($log.LogName)': $($_.Exception.Message)"
        } catch {
            Write-HostYellow "�� ������� �������� ������ ������� '$($log.LogName)': $($_.Exception.Message)"
        }
    }
    Write-Host "������� �������: $clearedCount �������, ��������� ��������� ��-�� ������ ��� ��������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "����� ������ ��� ��������� �������� �������: $($_.Exception.Message)"
}

# --- 8. ������� ����� Prefetch ---
Write-HostGreen "8/13: ������� ����� Prefetch..."
try {
    $prefetchPath = "C:\Windows\Prefetch"
    if (Test-Path $prefetchPath) {
        # ������� ����� ������ 7 ����
        Get-ChildItem -Path $prefetchPath -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force -ErrorAction SilentlyContinue
        # ������� �����, �������� ������ ��������� 1000, ���� �� ������� �����
        $files = Get-ChildItem -Path $prefetchPath -File | Sort-Object LastWriteTime -Descending
        if ($files.Count -gt 1000) {
            $filesToDelete = $files | Select-Object -Skip 1000
            $filesToDelete | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "������� $($filesToDelete.Count) ������ ������ Prefetch." -ForegroundColor DarkGray
        }
        Write-Host "����� Prefetch ��������������." -ForegroundColor DarkGray
    } else {
        Write-HostYellow "����� Prefetch �� �������."
    }
} catch {
    Write-HostRed "�� ������� ��������/�������������� ����� Prefetch: $($_.Exception.Message)"
}

# --- 9. ������� ���� �������� (Thumbnail Cache) ---
Write-HostGreen "9/13: ������� ���� �������� (Thumbnail Cache)..."
try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue # ������������� ��������� ��� ������� ��������
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    Start-Process explorer # ��������� ��������� �������
    Write-Host "��� �������� ������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ��� ��������: $($_.Exception.Message)"
}

# --- 10. ������� ������ ����������� �������� (Delivery Optimization Files) ---
Write-HostGreen "10/13: ������� ������ ����������� �������� (Delivery Optimization Files)..."
try {
    # ������� ������������� ������
    Stop-Service -Name Dosvc -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    # ������������� ������
    Start-Service -Name Dosvc -ErrorAction SilentlyContinue
    Write-Host "����� ����������� �������� �������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ����� ����������� ��������: $($_.Exception.Message)"
}

# --- 11. ������� ���� DirectX Shader ---
Write-HostGreen "11/13: ������� ���� DirectX Shader..."
try {
    # ����� ���� DirectX
    Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    # ���� NVIDIA
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\NVIDIA Corporation\NV_Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    # ���� AMD (���� ����� �������������, ��� �����)
    Remove-Item -Path "$env:LOCALAPPDATA\AMD\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\AMD\ATI\ACE\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "���� DirectX Shader �������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ���� DirectX Shader: $($_.Exception.Message)"
}

# --- 12. ������� ������ ������� �� ������� Windows (Windows Error Reporting) ---
Write-HostGreen "12/13: ������� ������ ������� �� ������� Windows..."
try {
    Remove-Item -Path "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\ProgramData\Microsoft\Windows\WER\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "����� ������� �� ������� �������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ����� ������� �� ������� Windows: $($_.Exception.Message)"
}

# --- 13. �������� ������ ����� � Temp-����������� ---
Write-HostGreen "13/13: �������� ������ ����� �� ��������� �����������..."
try {
    $tempPaths = @("$env:LOCALAPPDATA\Temp", "C:\Windows\Temp")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
                ($_.GetFileSystemInfos()).Count -eq 0
            } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "������ ����� �������." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� ������� ������ �����: $($_.Exception.Message)"
}

# --- �������������: ������� ����� ��������� (������ �������, ��� ������ �������� ����� ������������ ���������� ������� ���������) ---
Write-HostYellow "����������: ������ ������� ����� ��������� ������� �������� ��������� �/��� ������������� �� ���������� �������."
Write-HostYellow "������ ������� ����� Chrome � Edge (������� ����):"
try {
    # Chrome Cache (����� ����� ������ �������, ��������, Default, Profile 1 � �.�.)
    Get-ChildItem -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    # Edge Cache
    Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "���� Chrome � Edge ������� (�������)." -ForegroundColor DarkGray
} catch {
    Write-HostRed "�� ������� �������� ���� ���������: $($_.Exception.Message)"
}


Write-Host ""
Write-HostGreen "������� ������� Windows ���������!"

# ����� ���������� ����� ����� �������
$freeSpaceAfterMB = Get-DriveFreeSpaceMB -DriveLetter "C"
Write-HostGreen "�������� �� ����� C: ����� �������: $($freeSpaceAfterMB) MB"

$freedSpaceMB = $freeSpaceAfterMB - $freeSpaceBeforeMB
if ($freedSpaceMB -gt 0) {
    Write-HostGreen "����� �������������� �����: $($freedSpaceMB) MB"
} elseif ($freedSpaceMB -lt 0) {
    Write-HostYellow "��������: ����� ���������� ����� ���������� �� $($freedSpaceMB * -1) MB. ��� ����� ���� ������� � �������� ���������� �������."
} else {
    Write-HostYellow "����� ���������� ����� �� ���������."
}

Write-Host "��� ������� ���������� ��������� ��������� � ����, ������������� ������������� �������." -ForegroundColor Yellow
Read-Host "������� Enter ��� ������..."