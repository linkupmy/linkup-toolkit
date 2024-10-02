#!/bin/bash
echo "Initializing LinkUp Zigbee Flashing Tool...."
sudo docker stop zigbee2mqtt
sleep 3

if [ -d /home/pi ]; then
    ZB_DIR="/home/pi/zigbee2mqtt-data"
elif [ -d /home/orangepi ]; then
    ZB_DIR="/home/orangepi/zigbee2mqtt-data"
else
    echo "Neither 'pi' nor 'orangepi' user detected in /home."
    exit 1
fi

LOCAL_DIR="$ZB_DIR/zb_firmware"
mkdir -p "$LOCAL_DIR"

if ! pip3 show pyserial > /dev/null 2>&1; then
    sudo pip3 install pyserial --upgrade || { echo "Failed to install pyserial"; exit 1; }
fi

if ! pip3 show xmodem > /dev/null 2>&1; then
    sudo pip3 install xmodem || { echo "Failed to install xmodem"; exit 1; }
fi

usage() {
    echo "Usage: $0"
    echo "Select a dongle and mode using the numeric options provided."
    exit 1
}

check_serial_device() {
    local SERIAL_PORT=$1
    if [[ ! -c $SERIAL_PORT ]]; then
        echo "No device connected at $SERIAL_PORT."
        exit 1
    else
        echo "Device connected at $SERIAL_PORT."
    fi
}

download_base_scripts() {
    echo "Downloading base scripts from GitHub..."
    case "$DONGLE_OPTION" in
        1 | 4)
            curl -L -o "$LOCAL_DIR/base1.py" "https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/base1.py" || { echo "Failed to download base1.py"; exit 1; }
            ;;
        2 | 3)
            curl -L -o "$LOCAL_DIR/base2.py" "https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/base2.py" || { echo "Failed to download base2.py"; exit 1; }
            ;;
        *)
            echo "Invalid dongle option."
            exit 1
            ;;
    esac
}

declare -A FIRMWARE_URLS

FIRMWARE_URLS["sonoff_dongle_p_coordinator"]="https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/sonoff_dongle_p/coordinator/CC1352P2_CC2652P_launchpad_coordinator_20230507.hex"
FIRMWARE_URLS["sonoff_dongle_p_router"]="https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/sonoff_dongle_p/router/CC1352P2_CC2652P_launchpad_router_20221102.hex"
FIRMWARE_URLS["sonoff_dongle_e_coordinator"]="https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/sonoff_dongle_e/coordinator/ncp-uart-hw-v7.4.4.0-zbdonglee-115200.gbl"
FIRMWARE_URLS["sonoff_dongle_e_router"]="https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/sonoff_dongle_e/router/router.gbl"
FIRMWARE_URLS["slzb_07_coordinator"]="https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/slzb_07/coordinator/ncp-uart-hw-v7.4.1.0-slzb-07-115200.gbl"
FIRMWARE_URLS["slzb_07p7_coordinator"]="https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/slzb_07p7/coordinator/CC1352P2_CC2652P_launchpad_coordinator_20230507.hex"
FIRMWARE_URLS["slzb_07p7_router"]="https://raw.githubusercontent.com/linkup-zbtools/tree/main/zb_firmware/slzb_07p7/router/CC1352P2_CC2652P_launchpad_router_20221102.hex"

echo "Select a Dongle Type:"
echo "1) Sonoff Dongle P"
echo "2) Sonoff Dongle E"
echo "3) SMLight SLZB-07"
echo "4) SMLight SLZB-07P7"
read -p "Enter option (1-4): " DONGLE_OPTION

SERIAL_PORT=""

case "$DONGLE_OPTION" in
    1)
        SERIAL_PORT="/dev/ttyUSB0"
        check_serial_device "$SERIAL_PORT"
        echo "Select a Mode for Sonoff Dongle P:"
        echo "1) Coordinator"
        echo "2) Router"
        read -p "Enter option (1-2): " MODE_OPTION
        ;;
    2)
        SERIAL_PORT="/dev/ttyACM0"
        check_serial_device "$SERIAL_PORT"
        echo "Select a Mode for Sonoff Dongle E:"
        echo "1) Coordinator"
        echo "2) Router"
        read -p "Enter option (1-2): " MODE_OPTION
        ;;
    3)
        SERIAL_PORT="/dev/ttyUSB0"
        check_serial_device "$SERIAL_PORT"
        echo "Select a Mode for SMLight SLZB-07:"
        echo "1) Coordinator"
        read -p "Enter option (1): " MODE_OPTION
        ;;
    4)
        SERIAL_PORT="/dev/ttyUSB0"
        check_serial_device "$SERIAL_PORT"
        echo "Select a Mode for SMLight SLZB-07P7:"
        echo "1) Coordinator"
        echo "2) Router"
        read -p "Enter option (1-2): " MODE_OPTION
        ;;
    *)
        echo "Invalid dongle type selected."
        usage
        ;;
esac

DONGLE_DIR="$LOCAL_DIR/$DONGLE_OPTION"
mkdir -p "$DONGLE_DIR"

download_base_scripts

COMMAND=""

case "$DONGLE_OPTION" in
    1)
        if [[ "$MODE_OPTION" -eq 1 ]]; then
            curl -L -o "$DONGLE_DIR/sonoff_dongle_p_coordinator.hex" "${FIRMWARE_URLS["sonoff_dongle_p_coordinator"]}" || { echo "Failed to download sonoff_dongle_p_coordinator.hex"; exit 1; }
            COMMAND="sudo python3 $LOCAL_DIR/base1.py -ewv -p $SERIAL_PORT --bootloader-sonoff-usb $DONGLE_DIR/sonoff_dongle_p_coordinator.hex"
        elif [[ "$MODE_OPTION" -eq 2 ]]; then
            curl -L -o "$DONGLE_DIR/sonoff_dongle_p_router.hex" "${FIRMWARE_URLS["sonoff_dongle_p_router"]}" || { echo "Failed to download sonoff_dongle_p_router.hex"; exit 1; }
            COMMAND="sudo python3 $LOCAL_DIR/base1.py -ewv -p $SERIAL_PORT --bootloader-sonoff-usb $DONGLE_DIR/sonoff_dongle_p_router.hex"
        else
            echo "Invalid mode option."
            usage
        fi
        ;;
    2)
        if [[ "$MODE_OPTION" -eq 1 ]]; then
            curl -L -o "$DONGLE_DIR/sonoff_dongle_e_coordinator.gbl" "${FIRMWARE_URLS["sonoff_dongle_e_coordinator"]}" || { echo "Failed to download sonoff_dongle_e_coordinator.gbl"; exit 1; }
            COMMAND="sudo python3 $LOCAL_DIR/base2.py flash -f $DONGLE_DIR/sonoff_dongle_e_coordinator.gbl -p $SERIAL_PORT"
        elif [[ "$MODE_OPTION" -eq 2 ]]; then
            curl -L -o "$DONGLE_DIR/sonoff_dongle_e_router.gbl" "${FIRMWARE_URLS["sonoff_dongle_e_router"]}" || { echo "Failed to download sonoff_dongle_e_router.gbl"; exit 1; }
            COMMAND="sudo python3 $LOCAL_DIR/base2.py flash -f $DONGLE_DIR/sonoff_dongle_e_router.gbl -p $SERIAL_PORT"
        else
            echo "Invalid mode option."
            usage
        fi
        ;;
    3)
        if [[ "$MODE_OPTION" -eq 1 ]]; then
            curl -L -o "$DONGLE_DIR/slzb_07_coordinator.gbl" "${FIRMWARE_URLS["slzb_07_coordinator"]}" || { echo "Failed to download slzb_07_coordinator.gbl"; exit 1; }
            COMMAND="sudo python3 $LOCAL_DIR/base2.py flash -f $DONGLE_DIR/slzb_07_coordinator.gbl -p $SERIAL_PORT"
        else
            echo "Invalid mode option."
            usage
        fi
        ;;
    4)
        if [[ "$MODE_OPTION" -eq 1 ]]; then
            curl -L -o "$DONGLE_DIR/slzb_07p7_coordinator.hex" "${FIRMWARE_URLS["slzb_07p7_coordinator"]}" || { echo "Failed to download slzb_07p7_coordinator.hex"; exit 1; }
            COMMAND="sudo python3 $LOCAL_DIR/base1.py -ewv -p $SERIAL_PORT --bootloader-sonoff-usb $DONGLE_DIR/slzb_07p7_coordinator.hex"
        elif [[ "$MODE_OPTION" -eq 2 ]]; then
            curl -L -o "$DONGLE_DIR/slzb_07p7_router.hex" "${FIRMWARE_URLS["slzb_07p7_router"]}" || { echo "Failed to download slzb_07p7_router.hex"; exit 1; }
            COMMAND="sudo python3 $LOCAL_DIR/base1.py -ewv -p $SERIAL_PORT --bootloader-sonoff-usb $DONGLE_DIR/slzb_07p7_router.hex"
        else
            echo "Invalid mode option."
            usage
        fi
        ;;
    *)
        echo "Invalid dongle option."
        exit 1
        ;;
esac

echo "Flashing firmware..."
echo "Executing: $COMMAND"
eval "$COMMAND"

sleep 5

if [[ "$DONGLE_OPTION" -eq 2 || "$DONGLE_OPTION" -eq 3 ]]; then
    NVM_FILE="$DONGLE_DIR/nvm3_initfile.gbl"
    curl -L -o "$NVM_FILE" "https://raw.githubusercontent.com/OmegaMonster/OmegaMonster.github.io/main/zb_firmware/nvm3_initfile.gbl" || { echo "Failed to download nvm3_initfile.gbl"; exit 1; }

    echo "Flashing nvm3_initfile.gbl using base2.py..."
    FLASH_COMMAND="sudo python3 $LOCAL_DIR/base2.py flash -f $NVM_FILE -p $SERIAL_PORT"
    echo "Executing: $FLASH_COMMAND"
    eval "$FLASH_COMMAND"
else
    echo "Skipping flashing nvm3_initfile.gbl for this dongle."
fi

echo "Flashing process completed."

rm -rf "$ZB_DIR/zb_firmware"
rm -rf zb_dongle_flash.sh
