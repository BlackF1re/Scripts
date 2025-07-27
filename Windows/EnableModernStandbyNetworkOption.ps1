# Этот скрипт включает видимость опции "Сетевое подключение в ждущем режиме"
# в дополнительных параметрах электропитания Windows.
# Это позволяет резко сократить потребление в режиме сна S0, что критично при питании от батареи.

$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9"
$propertyName = "Attributes"
$propertyValue = 2 # 2 делает опцию видимой

if (-not (Test-Path $registryPath)) {
    Write-Host "Путь реестра не найден: $registryPath" -ForegroundColor Red
    Write-Host "Проверьте версию Windows или путь." -ForegroundColor Yellow
} else {
    try {
        Set-ItemProperty -LiteralPath $registryPath -Name $propertyName -Value $propertyValue -Force
        Write-Host "Опция 'Сетевое подключение в ждущем режиме' успешно включена в реестре." -ForegroundColor Green
        Write-Host "Чтобы увидеть изменение, возможно, потребуется перезагрузить компьютер." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Произошла ошибка при изменении реестра:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Убедитесь, что вы запустили PowerShell от имени администратора." -ForegroundColor Yellow
    }
}

# Задержка для чтения сообщения
Start-Sleep -Seconds 5