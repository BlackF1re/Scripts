#!/bin/bash
# Скрипт полной проверки подключения к интернету

# --- Конфигурация ---
PING_HOST="8.8.8.8"
PING_COUNT=10
EXPECTED_DOWNLOAD_MBPS=800
# Опциональный тест iPerf3 до сервера провайдера
PROVIDER_IPERF_SERVER=""

# Цвета
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_BOLD_GREEN='\033[1;32m' # Жирный зеленый
COLOR_RESET='\033[0m'

# Цветные метки
ok_msg() { echo -e "${COLOR_GREEN}[ok] ${COLOR_RESET}$@"; }
info_msg() { echo -e "${COLOR_BLUE}[info] ${COLOR_RESET}$@"; }
warn_msg() { echo -e "${COLOR_YELLOW}[warn] ${COLOR_RESET}$@"; }
err_msg() { echo -e "${COLOR_RED}[err] ${COLOR_RESET}$@"; }

# Определение имени активного сетевого интерфейса
get_active_network_interface() {
    # Попытка найти Ethernet-интерфейс (с Link detected: yes)
    ETHERNET_IFACE=$(ip -o link show | awk -F': ' '$2 !~ /lo|vir|wl|docker/ && $2 ~ /^(en|eth)/ {print $2; exit}')
    if [ -n "$ETHERNET_IFACE" ]; then
        if sudo ethtool "$ETHERNET_IFACE" 2>/dev/null | grep -q "Link detected: yes"; then
            echo "$ETHERNET_IFACE"
            return
        fi
    fi

    # Если Ethernet не активен, попытка найти активный Wi-Fi интерфейс с state UP
    WIFI_IFACE=$(ip -o link show | awk -F': ' '$2 !~ /lo|vir|docker/ && $2 ~ /^(wl|wlan)/ {print $2; exit}')
    if [ -n "$WIFI_IFACE" ]; then
        if ip a show "$WIFI_IFACE" | grep -q "state UP"; then
            echo "$WIFI_IFACE"
            return
        fi
    fi
    echo ""
}

echo -e "${COLOR_GREEN}===================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}                 Старт проверки сети               ${COLOR_RESET}"
echo -e "${COLOR_GREEN}===================================================${COLOR_RESET}"

# Определение активного сетевого интерфейса
info_msg "Определение активного сетевого интерфейса..."
ACTIVE_IFACE=$(get_active_network_interface)

if [ -z "$ACTIVE_IFACE" ]; then
    err_msg "Не найден активный Ethernet или Wi-Fi интерфейс."
    err_msg "Убедитесь, что кабель подключен (для Ethernet) или Wi-Fi включен и подключен."
    exit 1
fi
info_msg "Используемый интерфейс: ${COLOR_BOLD_GREEN}${ACTIVE_IFACE}${COLOR_RESET}"

# --- СТАРТОВЫЕ ДАННЫЕ ---
echo -e "${COLOR_GREEN}\n===================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}                   Стартовые данные                  ${COLOR_RESET}"
echo -e "${COLOR_GREEN}====================================================${COLOR_RESET}"

# Проверка типа интерфейса и вывод информации
if [[ "$ACTIVE_IFACE" =~ ^(en|eth) ]]; then # Ethernet
    INTERFACE_TYPE="Ethernet"
    info_msg "Тип интерфейса: Ethernet"
    info_msg "Исполнение ethtool (требуются права root)..."
    ETHTOOL_OUTPUT=$(sudo ethtool $ACTIVE_IFACE 2>&1)

    if echo "$ETHTOOL_OUTPUT" | grep -q "No such device"; then
        err_msg "Устройство ${ACTIVE_IFACE} не найдено ethtool. Проблемы с драйверами или адаптером."
        err_msg "${ETHTOOL_OUTPUT}"
        exit 1
    fi
    
    # Извлечение и вывод Link Speed
    LINK_SPEED=$(echo "$ETHTOOL_OUTPUT" | grep "Speed:" | awk '{print $2}')
    if [ -n "$LINK_SPEED" ]; then
        ok_msg "Скорость адаптера (Link Speed): ${COLOR_BOLD_GREEN}${LINK_SPEED}${COLOR_RESET}"
    else
        warn_msg "Не удалось определить скорость адаптера (Link Speed) через ethtool."
    fi

    # Вывод Duplex, Port, Link detected
    echo "$ETHTOOL_OUTPUT" | grep -E "Duplex:|Port:|Link detected:" | while read -r line; do
        if [[ "$line" =~ ^Duplex: ]]; then
            duplex_val=$(echo "$line" | awk '{print $2}')
            ok_msg "Duplex: ${COLOR_BOLD_GREEN}${duplex_val}${COLOR_RESET}"
        elif [[ "$line" =~ ^Port: ]]; then
            port_val=$(echo "$line" | awk '{print $2}')
            ok_msg "Port: ${COLOR_BOLD_GREEN}${port_val}${COLOR_RESET}"
        elif [[ "$line" =~ ^Link\ detected: ]]; then
            link_val=$(echo "$line" | awk '{print $3}')
            ok_msg "Link detected: ${COLOR_BOLD_GREEN}${link_val}${COLOR_RESET}"
        else
            ok_msg "$line"
        fi
    done

elif [[ "$ACTIVE_IFACE" =~ ^(wl|wlan) ]]; then # Wi-Fi
    INTERFACE_TYPE="Wi-Fi"
    info_msg "Тип интерфейса: Wi-Fi"
    WIFI_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
    if [ -n "$WIFI_SSID" ]; then
        ok_msg "Подключено к Wi-Fi сети: ${COLOR_BOLD_GREEN}${WIFI_SSID}${COLOR_RESET}"
        # Извлечение и вывод Wi-Fi Bit Rate
        WIFI_BIT_RATE=$(iwconfig "$ACTIVE_IFACE" 2>/dev/null | grep -oP 'Bit Rate:\K[^ ]+')
        if [ -n "$WIFI_BIT_RATE" ]; then
            ok_msg "Скорость адаптера (Bit Rate): ${COLOR_BOLD_GREEN}${WIFI_BIT_RATE}${COLOR_RESET}"
        else
            warn_msg "Не удалось определить скорость адаптера (Bit Rate) через iwconfig."
        fi
    else
        warn_msg "Wi-Fi интерфейс активен, но не подключен к сети."
    fi
else
    warn_msg "Тип интерфейса ${ACTIVE_IFACE} не определен как Ethernet или Wi-Fi."
fi

# Проверка IP-адреса, шлюза и DNS (общая для обоих типов)
info_msg "Сетевые настройки (IP, Шлюз, DNS, MAC)..."
IP_ADDRESS=$(ip -4 addr show dev $ACTIVE_IFACE | grep 'inet ' | awk '{print $2}')
GATEWAY=$(ip r | grep default | grep $ACTIVE_IFACE | awk '{print $3}')
DNS_SERVERS=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
MAC_ADDRESS=$(ip link show dev $ACTIVE_IFACE | grep 'link/ether' | awk '{print $2}')

if [ -n "$IP_ADDRESS" ]; then
    ok_msg "IP-адрес: ${COLOR_BOLD_GREEN}${IP_ADDRESS}${COLOR_RESET}"
else
    err_msg "IP-адрес не получен. Проверьте DHCP или настройки сети."
    exit 1
fi

if [ -n "$GATEWAY" ]; then
    ok_msg "Шлюз: ${COLOR_BOLD_GREEN}${GATEWAY}${COLOR_RESET}"
else
    err_msg "Шлюз не найден. Проверьте настройки маршрутизации."
fi

ok_msg "DNS-серверы: ${COLOR_BOLD_GREEN}${DNS_SERVERS}${COLOR_RESET}"
ok_msg "MAC-адрес: ${COLOR_BOLD_GREEN}${MAC_ADDRESS}${COLOR_RESET}"

echo -e "${COLOR_GREEN}\n===================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}           Тестирование производительности           ${COLOR_RESET}"
echo -e "${COLOR_GREEN}====================================================${COLOR_RESET}"

# Проверка стабильности соединения и потерь пакетов (ping)
info_msg "Проверка стабильности соединения (Ping до ${COLOR_BOLD_GREEN}${PING_HOST}${COLOR_RESET})... (${COLOR_BOLD_GREEN}${PING_COUNT}${COLOR_RESET} пингов)"
PING_OUTPUT=$(ping -c $PING_COUNT $PING_HOST)
echo "$PING_OUTPUT" # Вывод сырого лога пинга

PACKET_LOSS=$(echo "$PING_OUTPUT" | grep "packet loss" | awk '{print $6}' | sed 's/%//')
MIN_RTT=$(echo "$PING_OUTPUT" | grep "min/avg/max" | awk -F'=' '{print $2}' | awk -F'/' '{print $1}')
AVG_RTT=$(echo "$PING_OUTPUT" | grep "min/avg/max" | awk -F'=' '{print $2}' | awk -F'/' '{print $2}')
MAX_RTT=$(echo "$PING_OUTPUT" | grep "min/avg/max" | awk -F'=' '{print $2}' | awk -F'/' '{print $3}' | awk '{print $1}')

info_msg "Результаты Ping:"
ok_msg "  Потеря пакетов: ${COLOR_BOLD_GREEN}${PACKET_LOSS}%${COLOR_RESET}"
ok_msg "  Минимальный RTT: ${COLOR_BOLD_GREEN}${MIN_RTT}${COLOR_RESET} ms"
ok_msg "  Средний RTT: ${COLOR_BOLD_GREEN}${AVG_RTT}${COLOR_RESET} ms" # Средний RTT уже выводится
ok_msg "  Максимальный RTT: ${COLOR_BOLD_GREEN}${MAX_RTT}${COLOR_RESET} ms"


# Тест реальной пропускной способности Интернета (speedtest-cli)
info_msg "Запуск теста скорости Интернета (speedtest-cli)..."
info_msg "Пожалуйста, подождите, это может занять 15-30 секунд."
SPEEDTEST_OUTPUT=$(speedtest-cli --single 2>&1)
echo "$SPEEDTEST_OUTPUT"

DOWNLOAD_SPEED=$(echo "$SPEEDTEST_OUTPUT" | grep "Download:" | awk '{print $2, $3}')
UPLOAD_SPEED=$(echo "$SPEEDTEST_OUTPUT" | grep "Upload:" | awk '{print $2, $3}')

if [ -n "$DOWNLOAD_SPEED" ] && [ -n "$UPLOAD_SPEED" ]; then
    info_msg "Результаты Speedtest:"
    ok_msg "  Скорость загрузки: ${COLOR_BOLD_GREEN}${DOWNLOAD_SPEED}${COLOR_RESET}"
    ok_msg "  Скорость выгрузки: ${COLOR_BOLD_GREEN}${UPLOAD_SPEED}${COLOR_RESET}"
else
    err_msg "Не удалось получить результаты Speedtest. Проверьте интернет-соединение."
fi

if [ -n "$PROVIDER_IPERF_SERVER" ]; then
    info_msg "Запуск теста iPerf3 до сервера провайдера (${COLOR_BOLD_GREEN}${PROVIDER_IPERF_SERVER}${COLOR_RESET})..."
    info_msg "Тест загрузки (Download - от сервера к устройству):"
    iperf3 -c $PROVIDER_IPERF_SERVER -P 8 -t 15 -R
    info_msg "Тест выгрузки (Upload - от устройства к серверу):"
    iperf3 -c $PROVIDER_IPERF_SERVER -P 8 -t 15
else
    info_msg "iPerf3 тест до сервера провайдера пропущен (IP-адрес сервера не указан)."
fi

echo -e "${COLOR_GREEN}\n===================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}                  Проверка завершена                 ${COLOR_RESET}"
echo -e "${COLOR_GREEN}====================================================${COLOR_RESET}"
