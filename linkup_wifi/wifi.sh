#!/bin/bash

restart_network_selection() {
    echo ""
    echo "Returning to network selection process..."
    echo ""
    main
}

main() {
    if ! command -v nmcli &> /dev/null; then
        echo ""
        echo "Installing required tool for LinkUp Network Config"
        sudo apt-get install -y network-manager > /dev/null 2>&1
        echo ""
    fi

    echo "Welcome to LinkUp Hub Network Config"
    echo ""

    LAN_IP=""
    WIFI_IP=""
    WIFI_SSID=""

    if nmcli device status | grep -q "ethernet.*connected"; then
        LAN_IP=$(nmcli -g IP4.ADDRESS dev show | grep -m 1 '^[0-9]' | cut -d'/' -f1)
    fi

    if nmcli device status | grep -q "wifi.*connected"; then
        WIFI_IP=$(nmcli -g IP4.ADDRESS dev show | grep -m 1 '^[0-9]' | cut -d'/' -f1)
        WIFI_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
    fi

    echo ""
    if [[ -n "$LAN_IP" && -n "$WIFI_IP" ]]; then
        echo "The device is connected to the network via both LAN and Wi-Fi."
        echo "LAN IP address: $LAN_IP"
        echo "Wi-Fi IP address: $WIFI_IP (Connected to SSID: $WIFI_SSID)"
    elif [[ -n "$LAN_IP" ]]; then
        echo "The device is connected to the network via LAN."
        echo "LAN IP address: $LAN_IP"
    elif [[ -n "$WIFI_IP" ]]; then
        echo "The device is connected to the network via Wi-Fi."
        echo "Wi-Fi IP address: $WIFI_IP (Connected to SSID: $WIFI_SSID)"
    else
        echo "The device is not connected to any network."
    fi
    echo ""

    echo "Would you like to join a new network?"
    echo "1.) Yes"
    echo "2.) No"
    echo "3.) Others"
    echo ""
    read -p "Choose an option (1, 2, or 3): " JOIN_NEW_NETWORK

    echo ""
    if [[ "$JOIN_NEW_NETWORK" != "1" ]]; then
        if [[ "$JOIN_NEW_NETWORK" == "3" ]]; then
            others_menu
        else
            echo "Thank you for using LinkUp Hub Network Config"
            exit 0
        fi
    fi

    display_wifi_networks

    while true; do
        echo ""
        echo "Would you like to join any of the network listed?"
        echo "1.) Yes"
        echo "2.) Other Network"
        echo "3.) No"
        echo ""
        read -p "Choose an option (1, 2, or 3): " JOIN_SPECIFIC_NETWORK

        echo ""
        if [[ "$JOIN_SPECIFIC_NETWORK" == "3" ]]; then
            echo "Thank you for using LinkUp Hub Network Config"
            exit 0
        elif [[ "$JOIN_SPECIFIC_NETWORK" == "2" ]]; then
            read -p "Please enter the SSID: " SSID
            read -p "Please enter the Password: " PASSWORD
            break
        elif [[ "$JOIN_SPECIFIC_NETWORK" == "1" ]]; then
            read -p "Enter the number of the SSID you want to join: " SSID_NUMBER

            if [[ "$SSID_NUMBER" =~ ^[0-9]+$ ]] && (( SSID_NUMBER >= 1 && SSID_NUMBER <= ${#WIFI_LIST[@]} )); then
                SSID="${WIFI_LIST[$((SSID_NUMBER-1))]}"
                echo "You selected \"$SSID\"."

                echo "Would you like to join the \"$SSID\" network?"
                echo "1.) Yes"
                echo "2.) No"
                echo ""
                read -p "Is this correct? (1 or 2): " CONFIRM_SSID

                echo ""
                if [[ "$CONFIRM_SSID" == "1" ]]; then
                    read -p "Please enter the Password for \"$SSID\": " PASSWORD
                    break
                else
                    display_wifi_networks
                fi
            else
                echo "Invalid selection. Please try again."
            fi
        else
            echo "Invalid option. Please try again."
        fi
    done

    echo ""
    echo "Connecting to \"$SSID\"..."
    nmcli device wifi connect "$SSID" password "$PASSWORD" > /dev/null 2>&1

    # Wait briefly for connection and IP assignment
    sleep 5

    # Verify that the network connection is active and matches the desired SSID
    CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
    WIFI_IP=$(nmcli -g IP4.ADDRESS dev show | grep -m 1 '^[0-9]' | cut -d'/' -f1)

    if [[ "$CURRENT_SSID" == "$SSID" && -n "$WIFI_IP" && "$WIFI_IP" != "127.0.0.1" ]]; then
        echo "Successfully connected to \"$SSID\"!"
        echo "IP address in \"$SSID\" network: $WIFI_IP"
    else
        echo "Failed to connect to \"$SSID\". Either the network is unavailable or the password is incorrect."
        echo "Please check your credentials and network availability, then try again."
    fi

    echo ""
    echo "Thank you for using LinkUp Hub Network Config"
    exit 0
}

others_menu() {
    echo ""
    echo "What Other LinkUp Hub Network Config Options would you like?"
    echo "1.) Delete Existing Wireless Network Connection"
    echo "2.) No (Exit)"
    echo ""
    read -p "Choose an option (1 or 2): " OTHER_OPTION

    echo ""
    if [[ "$OTHER_OPTION" == "1" ]]; then
        list_unused_wifi_connections
    else
        echo "Thank you for using LinkUp Hub Network Config"
        exit 0
    fi
}

list_unused_wifi_connections() {
    echo ""
    echo "Listing unused Wi-Fi connections..."
    echo ""

    mapfile -t unused_wifi_connections < <(nmcli connection show | awk '$3 == "wifi" && $4 == "--" {print $1}')

    if [[ ${#unused_wifi_connections[@]} -eq 0 ]]; then
        echo "No unused Wi-Fi connections found."
        restart_network_selection
    fi

    echo "Unused Wi-Fi connections:"
    for i in "${!unused_wifi_connections[@]}"; do
        echo "$((i+1)).) ${unused_wifi_connections[$i]}"
    done

    echo ""
    read -p "Would you like to delete any of these unused connections? (Enter the number or 0 to cancel): " DELETE_CHOICE

    echo ""
    if [[ "$DELETE_CHOICE" == "0" ]]; then
        echo "No connection deleted. Returning to the main menu."
        restart_network_selection
    fi

    if [[ "$DELETE_CHOICE" =~ ^[0-9]+$ ]] && (( DELETE_CHOICE >= 1 && DELETE_CHOICE <= ${#unused_wifi_connections[@]} )); then
        SSID_TO_DELETE="${unused_wifi_connections[$((DELETE_CHOICE-1))]}"
        echo "You selected \"$SSID_TO_DELETE\"."

        read -p "Are you sure you want to delete \"$SSID_TO_DELETE\"? (y/n): " CONFIRM_DELETE
        if [[ "$CONFIRM_DELETE" == "y" || "$CONFIRM_DELETE" == "Y" ]]; then
            nmcli connection delete "$SSID_TO_DELETE"
            if [[ $? -eq 0 ]]; then
                echo "Successfully deleted \"$SSID_TO_DELETE\"."
            else
                echo "Failed to delete \"$SSID_TO_DELETE\". Please check the connection and try again."
            fi
        else
            echo "No changes made."
        fi
    else
        echo "Invalid selection. No connection deleted."
    fi

    restart_network_selection
}

display_wifi_networks() {
    echo ""
    echo "Scanning for available Wi-Fi networks..."
    sudo nmcli device wifi rescan > /dev/null 2>&1
    echo ""
    echo "This is the possible Wi-Fi network available around your LinkUp Hub:"

    mapfile -t WIFI_LIST < <(nmcli -f SSID,SIGNAL,CHAN dev wifi | tail -n +2 | awk '{print $1}')
    for i in "${!WIFI_LIST[@]}"; do
        echo "$((i+1)).) ${WIFI_LIST[$i]}"
    done
    echo ""
}

main
