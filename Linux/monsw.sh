#!/bin/bash
#monitor mode switcher

#checking utilities
for cmd in iw ip airmon-ng; do
    if ! command -v $cmd &>/dev/null; then
        echo "[err]  Package '$cmd' not found. Please install by:"
        case $cmd in
            iw|ip)
                echo "sudo apt install wireless-tools iproute2"
                ;;
            airmon-ng)
                echo "sudo apt install aircrack-ng"
                ;;
        esac
        exit 1
    fi
done

#getting all ifaces
interfaces=($(iw dev | grep Interface | awk '{print $2}'))

if [ ${#interfaces[@]} -eq 0 ]; then
    echo "[err]  Wireless interfaces not found."
    exit 1
fi

echo
echo "[ok]  Interfaces:"
for i in "${!interfaces[@]}"; do
    mode=$(iw dev "${interfaces[$i]}" info | grep type | awk '{print $2}')
    echo "  [$i]  ${interfaces[$i]} ($mode)"
done

#iface selection
echo
read -p "Select the interface: " choice
iface="${interfaces[$choice]}"

if [ -z "$iface" ]; then
    echo -e "\n[err]  Wrong selection."
    exit 1
fi

#current mode detecting
mode=$(iw dev "$iface" info | grep type | awk '{print $2}')
echo
echo "[info]  Current mode of $iface: $mode"

#mode switching
if [ "$mode" = "managed" ]; then
    echo
    echo "[info]  Switching $iface to monitor mode..."
    sudo airmon-ng check kill
    sudo ip link set "$iface" down
    sudo iw "$iface" set type monitor
    sudo ip link set "$iface" up
    echo "[ok]  $iface switched to monitor mode."
else
    echo
    echo "[info]  Switching $iface to managed mode..."
    sudo ip link set "$iface" down
    sudo iw "$iface" set type managed
    sudo ip link set "$iface" up
    sudo service NetworkManager restart
    sudo service wpa_supplicant restart
    echo
    echo "[ok]  $iface switched to managed mode."
fi
