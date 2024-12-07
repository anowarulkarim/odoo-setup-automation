#!/bin/bash

# Function to create the odoo folder and its subdirectories
create_odoo_structure() {
    local base_dir="/opt/odoo"

    # Step 1: Create the base directory (odoo)
    echo "Creating base directory: $base_dir"
    sudo mkdir -p "$base_dir"

    # Step 2: Create subdirectories: server, venv, and conf
    echo "Creating subdirectories inside $base_dir"
    sudo mkdir -p "$base_dir/server"
    sudo mkdir -p "$base_dir/venv"
    sudo mkdir -p "$base_dir/conf"

    # Step 3: Navigate to the server directory
    cd "$base_dir/server" || { echo "Failed to navigate to $base_dir/server"; exit 1; }

    # Confirmation message
    echo "Directories created successfully:"
    echo " - $base_dir"
    echo " - $base_dir/server"
    echo " - $base_dir/venv"
    echo " - $base_dir/conf"
}

# Function to create a directory, initialize Git, and clone
clone_odoo_repo() {
    local version=$1
    local base_dir="/opt/odoo"
    local server_dir="$base_dir/server/odoo_${version}"
    local git_url="https://www.github.com/odoo/odoo"
    local branch="--branch ${version}.0"

    # Step 1: Create necessary directories with sudo
    echo "Creating directory: $server_dir"
    sudo mkdir -p "$server_dir"

    # Step 2: Clone the specified branch
    echo "Cloning Odoo repository (branch: ${version}.0) into $server_dir"
    sudo git clone $git_url --depth 1 $branch --single-branch "$server_dir"

    # Check if cloning was successful
    if [[ $? -eq 0 ]]; then
        echo "Repository successfully cloned into $server_dir"
    else
        echo "Error: Failed to clone repository. Check the branch version and internet connection."
        return 1
    fi
}

# Function to create a virtual environment
create_virtualenv() {
    local version=$1
    local base_dir="/opt/odoo/venv"
    local venv_dir="$base_dir/odoo-${version}-env"

    # Step 1: Ensure the base directory exists
    echo "Ensuring base directory exists: $base_dir"
    sudo mkdir -p "$base_dir"

    # Step 2: Create the virtual environment using virtualenv
    echo "Creating virtual environment in: $venv_dir"
    sudo virtualenv "$venv_dir"

    # Step 3: Verify creation
    if [[ -d "$venv_dir" ]]; then
        echo "Virtual environment successfully created: $venv_dir"
        # Step 4: Set ownership and permissions
        echo "Setting permissions for the virtual environment..."
        sudo chown -R odoo:odoo "$venv_dir"
        sudo chmod -R +777 "$venv_dir"
        echo "Permissions set successfully."
    else
        echo "Error: Failed to create virtual environment."
        return 1
    fi
}

install() {
    local version=$1
    local server_dir="/opt/odoo/server/odoo_${version}"
    local venv_dir="/opt/odoo/venv/odoo-${version}-env"

    # Step 1: Install necessary dependencies
    echo "Installing required packages..."
    sudo apt update
    sudo apt install -y python3-pip libldap2-dev libpq-dev libsasl2-dev

    # Step 2: Check if the virtual environment exists
    if [[ ! -d "$venv_dir" ]]; then
        echo "Error: Virtual environment not found at $venv_dir. Please create it first."
        return 1
    fi

    # Step 3: Activate the virtual environment
    echo "Activating virtual environment: $venv_dir"
    source "$venv_dir/bin/activate"

    # Step 4: Navigate to the server directory
    echo "Navigating to server directory: $server_dir"
    if [[ -d "$server_dir" ]]; then
        cd "$server_dir" || { echo "Error: Failed to navigate to $server_dir"; return 1; }
    else
        echo "Error: Server directory not found: $server_dir"
        return 1
    fi

    # Step 5: Install dependencies from requirements.txt
    if [[ -f "requirements.txt" ]]; then
        echo "Installing Python dependencies from requirements.txt..."
        pip install -r requirements.txt
    else
        echo "Error: requirements.txt not found in $server_dir"
        return 1
    fi

    # Step 6: Deactivate the virtual environment
    deactivate
    echo "Virtual environment deactivated."

    echo "Installation complete for Odoo version ${version}."
}

create_conf_file() {
    local version="$1"
    local main_folder="/opt/odoo"
    local conf_file="$main_folder/conf/odoo${version}.conf"
    local db_user="odoo-${version}"
    local addons_path="$main_folder/server/odoo_${version}/addons,$main_folder/server/odoo_${version}/odoo/addons"
    local xmlrpc_port=$((8003 + $version))

    # Configuration file content
    conf_content="[options]
; This is the password that allows database operations
admin_passwd = 123456
db_host = localhost
db_port = 5432
db_password = 123456
db_user=$db_user
; Uncomment this to filter databases
; dbfilter=.*
; db_name=odoo_${version}_test
addons_path=$addons_path
xmlrpc_port=$xmlrpc_port
; Path to PostgreSQL binary
; pg_path = /usr/bin/psql
; pg_path = /usr/lib/postgresql/14/bin
; Uncomment this to specify a data directory
; data_dir = /home/odoo/.local/share/Odoo/"

    # Creating the configuration file
    echo "Creating configuration file for Odoo version $version..."
    echo "$conf_content" | sudo tee "$conf_file" > /dev/null

    # Setting permissions
    sudo chown odoo:odoo "$conf_file"
    sudo chmod -R +777 "$main_folder"
    
    echo "Configuration file for Odoo $version created at $conf_file"
}

create_odoo_service_file() {
    local version="$1"
    local service_file="/etc/systemd/system/odoo${version}.service"
    local log_dir="/var/log/odoo"

    # Step 1: Create the log directory if it doesn't exist
    echo "Creating log directory..."
    sudo mkdir -p "$log_dir"
    sudo chown -R odoo:odoo "$log_dir"

    # Step 2: Create the service file
    echo "Creating service file for Odoo $version..."

    # Define the content of the service file
    service_content="[Unit]
Description=Odoo ${version} Service
After=network.target

[Service]
Type=simple
User=odoo
Group=odoo
WorkingDirectory=/opt/odoo/server/odoo_${version}

# Set environment variables for virtual environment
Environment=\"VIRTUAL_ENV=/opt/odoo/venv/odoo-${version}-env\"
Environment=\"PATH=\$VIRTUAL_ENV/bin:\$PATH\"
Environment=\"PYTHONPATH=/opt/odoo/venv/odoo-${version}-env/lib/python3.12/site-packages\"

ExecStart=/opt/odoo/venv/odoo-${version}-env/bin/python3.12 /opt/odoo/server/odoo_${version}/odoo-bin -c /opt/odoo/conf/odoo${version}.conf

Restart=always
LimitNOFILE=4096
TimeoutStartSec=300

StandardOutput=append:/var/log/odoo/odoo.log
StandardError=append:/var/log/odoo/odoo.log"

    # Write the content to the service file
    echo "$service_content" | sudo tee "$service_file" > /dev/null

    # Set appropriate permissions
    sudo chmod +777 "$service_file"
    sudo systemctl daemon-reload

    # Confirm the service file creation
    echo "Service file for Odoo $version created at $service_file."
}

# Take input outside the functions
read -p "Enter the version for Odoo and virtual environment (e.g., 16, 17): " input_version

# Validate the input
if ! [[ "$input_version" =~ ^[0-9]+$ ]]; then
    echo "Error: Please enter a valid integer."
    exit 1
fi

# Call the functions with the input
create_odoo_structure
clone_odoo_repo "$input_version"
create_virtualenv "$input_version"
install "$input_version"
create_conf_file "$input_version"
create_odoo_service_file "$input_version"
