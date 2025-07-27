# ���� ������ �������� ��������� ����� "������� ����������� � ������ ������"
# � �������������� ���������� �������������� Windows.
# ��� ��������� ����� ��������� ����������� � ������ ��� S0, ��� �������� ��� ������� �� �������.

$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9"
$propertyName = "Attributes"
$propertyValue = 2 # 2 ������ ����� �������

if (-not (Test-Path $registryPath)) {
    Write-Host "���� ������� �� ������: $registryPath" -ForegroundColor Red
    Write-Host "��������� ������ Windows ��� ����." -ForegroundColor Yellow
} else {
    try {
        Set-ItemProperty -LiteralPath $registryPath -Name $propertyName -Value $propertyValue -Force
        Write-Host "����� '������� ����������� � ������ ������' ������� �������� � �������." -ForegroundColor Green
        Write-Host "����� ������� ���������, ��������, ����������� ������������� ���������." -ForegroundColor Yellow
    }
    catch {
        Write-Host "��������� ������ ��� ��������� �������:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "���������, ��� �� ��������� PowerShell �� ����� ��������������." -ForegroundColor Yellow
    }
}

# �������� ��� ������ ���������
Start-Sleep -Seconds 5