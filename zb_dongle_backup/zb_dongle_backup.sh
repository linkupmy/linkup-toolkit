#!/bin/bash

echo "Initializing script..."
echo "Please ensure you done requesting backup on port 8080."
read -p "Have you pressed the backup button on port 8080? (yes/no): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    echo "Backup process canceled. Please confirm the backup on port 8080 and run the script again."
    exit 1
fi

if sudo pip3 show zigpy &>/dev/null; then
    echo "Tool 1 is already installed."
else
    echo "Tool 1 is not installed. Installing Tool 1..."
    sudo pip3 install zigpy
fi

if sudo pip3 show zigpy-cli &>/dev/null; then
    echo "Tool 2 is already installed."
else
    echo "Tool 2 is not installed. Installing Tool 2..."
    sudo pip3 install zigpy-cli
fi

echo "Which dongle would you like to restore backup?"
echo "1: Sonoff Dongle P"
echo "2: Sonoff Dongle E"
echo "3: SLZB-07"
echo "4: SLZB-07P7"
echo "5: SLZB-06"
echo "6: SLZB-06M"

read -p "Please select an option (1, 2, 3, 4, 5, or 6): " user_choice

if [[ $(sudo docker ps -q --filter "name=zigbee2mqtt") ]]; then
    echo "Stopping the Zigbee2MQTT container..."
    sudo docker stop zigbee2mqtt
else
    echo "Zigbee2MQTT container is not running."
fi

echo "Please unplug the coordinator and replace it with the Spare Dongle."
read -p "Is your spare dongle's firmware matching with the coordinator firmware? (yes/no): " firmware_confirmation

if [[ "$firmware_confirmation" != "yes" ]]; then
    echo "Firmware mismatch. Please update the firmware of the spare dongle and run the script again."
    exit 1
fi

perform_backup() {
    if [ -c /dev/ttyUSB0 ]; then
        echo "/dev/ttyUSB0 is available."
    elif [ -c /dev/ttyACM0 ]; then
        echo "/dev/ttyACM0 is available."
    else
        echo "No dongle detected on /dev/ttyUSB0 or /dev/ttyACM0."
        exit 1
    fi

    if [ -d /home/pi ]; then
        home_dir="/home/pi"
    elif [ -d /home/orangepi ]; then
        home_dir="/home/orangepi"
    else
        echo "Neither 'pi' nor 'orangepi' user detected in /home."
        exit 1
    fi

    backup_file="$home_dir/zigbee2mqtt-data/coordinator_backup.json"
    backup_dir="$home_dir/zigbee2mqtt-data/backup"
    
    if [ -d "$backup_dir" ]; then
        echo "Clearing the existing backup directory..."
        sudo rm -rf "$backup_dir/*"
    fi

    sudo mkdir -p "$backup_dir"
    sudo cp -r "$home_dir/zigbee2mqtt-data/"* "$backup_dir/"
    echo "Backup of files completed. All files are copied to $backup_dir."

    if [ -f "$backup_file" ]; then
        echo "Backup file found: $backup_file"
        
        if [[ $(find "$backup_file" -mmin -5) ]]; then
            echo "The backup file is recent. Proceeding with restore."
            case $user_choice in
                1)
                    echo "Restoring using Sonoff Dongle P..."
                    sudo zigpy radio zip /dev/ttyUSB0 restore "$backup_file"
                    ;;
                2)
                    echo "Restoring using Sonoff Dongle E..."
                    sudo zigpy radio ezsp /dev/ttyACM0 restore "$backup_file"
                    ;;
                3)
                    echo "Restoring using SLZB-07..."
                    sudo zigpy radio ezsp /dev/ttyUSB0 restore "$backup_file"
                    ;;
                4)
                    echo "Restoring using SLZB-07P7..."
                    sudo zigpy radio zip /dev/ttyUSB0 restore "$backup_file"
                    ;;
                5|6)
                    echo "Is this configured via:"
                    echo "1: USB"
                    echo "2: Network"
                    read -p "Please enter 1 or 2: " config_choice
                    if [[ "$config_choice" == "1" ]]; then
                        if [ -c /dev/ttyUSB0 ]; then
                            echo "/dev/ttyUSB0 is available for SLZB-06 or SLZB-06M."
                            echo "Restoring using SLZB-06 or SLZB-06M over USB..."
                            if [ "$user_choice" -eq 5 ]; then
                                sudo zigpy radio zip /dev/ttyUSB0 restore "$backup_file"
                            elif [ "$user_choice" -eq 6 ]; then
                                sudo zigpy radio ezsp /dev/ttyUSB0 restore "$backup_file"
                            fi
                        else
                            echo "No USB device found."
                            exit 1
                        fi
                    elif [[ "$config_choice" == "2" ]]; then
                        read -p "Please enter the IP address: " ip_address
                        if [ "$user_choice" -eq 5 ]; then
                            echo "Restoring using SLZB-06 over network with IP: $ip_address..."
                            sudo zigpy radio zip "tcp://$ip_address:6638" restore "$backup_file"
                        elif [ "$user_choice" -eq 6 ]; then
                            echo "Restoring using SLZB-06M over network with IP: $ip_address..."
                            sudo zigpy radio ezsp "tcp://$ip_address:6638" restore "$backup_file"
                        fi
                    else
                        echo "Invalid configuration option selected."
                        exit 1
                    fi
                    ;;
                *)
                    echo "Invalid option selected."
                    exit 1
                    ;;
            esac
        else
            echo "The backup file is not recent. Last modified time is older than 5 minutes."
            exit 1
        fi
    else
        echo "Backup file not found in $home_dir/zigbee2mqtt-data."
        exit 1
    fi
}

case $user_choice in
    1|2|3|4|5|6)
        perform_backup
        ;;
    *)
        echo "Invalid option selected. Please run the script again and choose a valid option."
        exit 1
        ;;
esac

echo "Backup process completed for the selected dongle."
rm -rf zb_dongle_backup.sh
