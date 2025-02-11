#!/bin/bash

LOG_FILE="/var/log/network_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting network setup script..."

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo."
    exit 1
fi

echo "User is root. Proceeding..."

# Install required packages
echo "Installing required packages..."
apt update && apt install -y qemu-kvm virt-manager libvirt-daemon-system virtinst libvirt-clients libvirt0 qemu-system
if [ $? -ne 0 ]; then
    echo "Failed to install required packages. Exiting..."
    exit 1
fi

echo "Required packages installed successfully."

# Detect available network interfaces
INTERFACES=$(ls /sys/class/net | tr '\n' ' ')

# Check if any interfaces were detected
if [ -z "$INTERFACES" ]; then
    whiptail --title "Error" --msgbox "No network interfaces detected!" 8 50
    echo "No network interfaces detected. Exiting..."
    exit 1
fi

echo "Detected interfaces: $INTERFACES"

# Create a selection menu with whiptail
SELECTED_INTERFACE=$(whiptail --title "Network Interface Selection" --menu "Choose an interface:" 15 50 5 $(for i in $INTERFACES; do echo "$i \"$i\""; done) 3>&1 1>&2 2>&3)

# Check if the user canceled the selection
if [ $? -ne 0 ]; then
    echo "User canceled interface selection. Exiting..."
    exit 1
fi

echo "User selected interface: $SELECTED_INTERFACE"

# Notify the user about connection changes
whiptail --title "Warning" --msgbox "The network connection will be temporarily disrupted. Proceeding in 10 seconds..." 8 50
sleep 10

# Add bridge connection
echo "Adding bridge connection..."
nmcli connection add type bridge ifname laboratorio1 autoconnect yes
if [ $? -ne 0 ]; then
    echo "Failed to add bridge connection. Exiting..."
    exit 1
fi

echo "Adding bridge-slave connection for interface $SELECTED_INTERFACE..."
nmcli connection add type bridge-slave ifname $SELECTED_INTERFACE master bridge-laboratorio1 autoconnect yes
if [ $? -ne 0 ]; then
    echo "Failed to add bridge-slave connection. Exiting..."
    exit 1
fi

# Bring down the existing wired connection
echo "Bringing down wired connection..."
nmcli connection down "Conexão cabeada 1"
if [ $? -ne 0 ]; then
    echo "Failed to bring down wired connection. Exiting..."
    exit 1
fi

# Bring up the bridge connection
echo "Bringing up bridge connection..."
nmcli connection up "bridge-laboratorio1"
if [ $? -ne 0 ]; then
    echo "Failed to bring up bridge connection. Exiting..."
    exit 1
fi

echo "Network setup completed successfully."

# Create bridge configuration file
echo "Creating bridge configuration file..."
cat <<EOF > config-bridge.xml
<network>
    <name>laboratorio1</name>
    <forward mode="bridge" />
    <bridge name="laboratorio1" />
</network>
EOF

# Define and start the virtual network
echo "Defining virtual network..."
virsh net-define config-bridge.xml
if [ $? -ne 0 ]; then
    echo "Failed to define virtual network. Exiting..."
    exit 1
fi

echo "Starting virtual network..."
virsh net-start --network laboratorio1
if [ $? -ne 0 ]; then
    echo "Failed to start virtual network. Exiting..."
    exit 1
fi

echo "Setting virtual network to autostart..."
virsh net-autostart laboratorio1
if [ $? -ne 0 ]; then
    echo "Failed to set virtual network to autostart. Exiting..."
    exit 1
fi

echo "Listing all virtual networks..."
virsh net-list --all

echo "Bridge and virtual network setup completed successfully."
