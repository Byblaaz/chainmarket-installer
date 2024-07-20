#!/bin/bash
# Set data env
echo "-------- Setting data env --------"
ENV_FILE=".env"
ask_variable() {
    local var_name=$1
    local var_value

    if [ "$var_name" == "URL_RPC" ] || [ "$var_name" == "URL_WS" ]; then
        read -p "Enter value for $var_name (or type 'null'): " var_value
    else
        read -p "Enter value for $var_name: " var_value
    fi

    echo "$var_name=$var_value" >> $ENV_FILE
}

generate_uuid() {
    local uuid=$(uuidgen)
    echo "RANDOM_UUID=$uuid" >> $ENV_FILE
}

if [ -f "$ENV_FILE" ]; then
    echo "$ENV_FILE found. Checking for required variables..."
else
    echo "$ENV_FILE not found. Creating $ENV_FILE..."
    touch $ENV_FILE
fi

variable_exists() {
    local var_name=$1
    grep -q "^$var_name=" "$ENV_FILE"
}

if ! variable_exists "SYNC_CODE"; then
    ask_variable "SYNC_CODE"
fi

if ! variable_exists "URL_RPC"; then
    ask_variable "URL_RPC"
fi

if ! variable_exists "URL_WS"; then
    ask_variable "URL_WS"
fi

if ! variable_exists "POLO1"; then
    ask_variable "POLO1"
fi

if ! variable_exists "NGINX"; then
    ask_variable "NGINX"
fi

if ! variable_exists "RANDOM_UUID"; then
    generate_uuid
fi

echo "🟢All required variables are set in $ENV_FILE."

# Check data .env
IS_ACCESSIBLE=false
if [ ! -f .env ]; then
    echo -e "\e[31m🔴.env file not found!\e[0m"
    exit 1
fi

export $(grep -v '^#' .env | xargs)

if [ -z "$URL_RPC" ]; then
    echo "The environment variable URL_RPC is not set."
    exit 1
fi

if [ -z "$URL_WS" ]; then
    echo "The environment variable URL_WS is not set."
    exit 1
fi


# Installation jq
sudo apt-get install jq -y

if jq --version > /dev/null 2>&1; then
    echo "🟢jq successfully installed."
else
    echo "🔴Error: jq installation failed."
fi

#Install websocat for testing
echo "-------- Installation websocat --------"
WEBOSCAT_URL="https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl"
FILE_NAME="websocat.x86_64-unknown-linux-musl"
DEST_PATH="/usr/local/bin/websocat"
wget -q $WEBOSCAT_URL -O $FILE_NAME

if [ $? -ne 0 ]; then
    echo "🔴Error: Impossible to download websocat"
    exit 1
fi
chmod +x $FILE_NAME
sudo mv $FILE_NAME $DEST_PATH

if [ $? -ne 0 ]; then
    echo "🔴Error: Impossible to move websocat"
    exit 1
fi


if command -v websocat >/dev/null 2>&1; then
    echo "🟢websocat is installed and ready to use."
else
    echo "🔴Error: websocat was not installed correctly."
    exit 1
fi


#CHECK PORT CONTAINERS
echo "-------- Checking PORT containers --------"
# Function to check if a port is in use
is_port_in_use() {
    local port=$1
    if lsof -i:$port > /dev/null 2>&1; then
        return 0 # Port is in use
    else
        return 1 # Port is not in use
    fi
}

# Function to find the next available port starting from a given port
find_next_available_port() {
    local start_port=$1
    while is_port_in_use $start_port; do
        start_port=$((start_port+1))
    done
    echo $start_port
}

# Function to get the current value of a variable from the .env file
get_env_value() {
    local var_name=$1
    if [ -f .env ]; then
        local value=$(grep "^$var_name=" .env | cut -d '=' -f2)
        echo $value
    fi
}

# Get the current values of POLO1 and NGINX from the .env file, if they exist
current_polo1=$(get_env_value "POLO1")
current_nginx=$(get_env_value "NGINX")

# Check if POLO1 is already set in the .env file
if [ -n "$current_polo1" ]; then
    echo "🟠POLO1 is already set to $current_polo1 in the .env file. Not modifying."
else
    # Check if port 3100 is in use
    if is_port_in_use 3100; then
        # Find the next available port starting from 3100
        next_port=$(find_next_available_port 3100)
        echo "🟢Port 3100 is in use. Setting POLO1 to the next available port: $next_port"
        echo "POLO1=$next_port" >> .env
    else
        echo "🟢Port 3100 is not in use. Setting POLO1 to 3100"
        echo "POLO1=3100" >> .env
    fi
fi

# Check if NGINX is already set in the .env file
if [ -n "$current_nginx" ]; then
    echo "🟠NGINX is already set to $current_nginx in the .env file. Not modifying."
else
    # Check if port 8081 is in use
    if is_port_in_use 8081; then
        # Find the next available port starting from 8081
        next_port=$(find_next_available_port 8081)
        echo "🟢Port 8081 is in use. Setting NGINX to the next available port: $next_port"
        echo "NGINX=$next_port" >> .env
    else
        echo "🟢Port 8081 is not in use. Setting NGINX to 8081"
        echo "NGINX=8081" >> .env
    fi
fi



#HTTP RPC TEST
echo "-------- Checking RPC accessible inside --------"
if [ -n "$URL_RPC" ] && [ "$URL_RPC" != "null" ]; then
   RESPONSE=$(curl -s -H "Content-type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' "$URL_RPC")

   if [ -z "$RESPONSE" ]; then
       echo "🟠Failed to get a valid response from RPC server."
   else
       BLOCK_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')

       if [ -n "$BLOCK_NUMBER" ]; then
           echo "🟢HTTP - Latest block: $((BLOCK_NUMBER))"
       else
           echo -e "\e[31m🔴Failed to get latest blockNumber HTTP RPC.\e[0m"
           IS_ACCESSIBLE=true
       fi
   fi
else
    echo "🟠The environment variable URL_RPC is not set or is empty."
fi

#WEBSOCKET RPC TEST
if [ -n "$URL_WS" ] && [ "$URL_WS" != "null" ]; then
  get_block_number() {
      echo '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | websocat $URL_WS | jq -r '.result'
  }
  RESULT_HEX=$(get_block_number)
  if [ -z "$RESULT_HEX" ] || [ "$RESULT_HEX" == "null" ]; then
      echo -e "\e[31m🔴Failed to get block number HTTP WS.\e[0m"
      IS_ACCESSIBLE=true
  fi
  if [ "$RESULT_HEX" != "" ]; then
    RESULT_DECIMAL=$(printf "%d\n" "$RESULT_HEX")
    echo "🟢WEBSOCKET- Latest block: $RESULT_DECIMAL"
  fi
else
    echo "🟠The environment variable URL_WS is not set or is empty."
fi

if [ "$IS_ACCESSIBLE" == "true" ]; then
    echo -e "\e[31m🔴RPC is not accessible from the inside. Please check your RPC endpoints.\e[0m"
    exit 1
fi

#----------------------
#Checking RPC outside
# API URLs
API_WS_URL="https://check.chainmarket.pro/check_ws"
API_RPC_URL="https://check.chainmarket.pro/check_rpc"


getIpServer() {
    PUBLIC_IP=$(curl -s ipv4.icanhazip.com)
    echo $PUBLIC_IP
}

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -n "$URL_RPC" ]; then
    if [[ "$URL_RPC" == *"127.0.0.1"* ]]; then
        URL_RPC=$(echo "$URL_RPC" | sed 's/127.0.0.1/'"$(getIpServer)"'/')
    fi

    if [[ "$URL_RPC" == *"localhost"* ]]; then
        URL_RPC=$(echo "$URL_RPC" | sed 's/localhost/'"$(getIpServer)"'/')
    fi
fi

if [ -n "$URL_WS" ]; then
    if [[ "$URL_WS" == *"127.0.0.1"* ]]; then
        URL_WS=$(echo "$URL_WS" | sed 's/127.0.0.1/'"$(getIpServer)"'/')
    fi

    if [[ "$URL_WS" == *"localhost"* ]]; then
        URL_WS=$(echo "$URL_WS" | sed 's/localhost/'"$(getIpServer)"'/')
    fi
fi


echo "-------- Checking RPC accessible outside --------"
check_ws_rpc() {
    local url_ws=$1
    local response=$(curl -s "${API_WS_URL}?url_ws=${url_ws}")

    if [ -z "$response" ]; then
        echo -e "\e[31m🔴Failed to get a valid response from API for WebSocket.\e[0m"
        return
    fi

    local accessible=$(echo "$response" | jq -r '.accessible')
    if [ "$accessible" == "true" ]; then
        echo -e "\e[31m🔴WebSocket RPC is accessible.\e[0m"
        echo -e "\e[31m Your RPC Websocket is externally accessible! Please change this before continue\e[0m"
        IS_ACCESSIBLE=true
    else
        echo "🟢WebSocket RPC is not accessible."
    fi
}

check_http_rpc() {
    local url_rpc=$1
    local response=$(curl -s "${API_RPC_URL}?url_rpc=${url_rpc}")

    if [ -z "$response" ]; then
        echo -e "\e[31m🔴Failed to get a valid response from API for HTTP.\e[0m"
        return
    fi

    local accessible=$(echo "$response" | jq -r '.accessible')
    if [ "$accessible" == "true" ]; then
        echo -e "\e[31m🔴HTTP RPC is accessible.\e[0m"
        echo -e "\e[31m Your RPC HTTP is externally accessible! Please change this before continue\e[0m"
        IS_ACCESSIBLE=true
    else
        echo "🟢HTTP RPC is not accessible."
    fi
}

if [ -n "$URL_WS" ] && [ "$URL_WS" != "null" ]; then
  check_ws_rpc "$URL_WS"
fi

if [ -n "$URL_RPC" ] && [ "$URL_RPC" != "null" ]; then
  check_http_rpc "$URL_RPC"
fi

if [ "$IS_ACCESSIBLE" == "true" ]; then
    echo -e "\e[31m🔴RPC is accessible from the outside. Please secure your RPC endpoints.\e[0m"
    echo -e "\e[31m If your rpc is accessible from the outside, we can't guarantee its security \e[0m"
    exit 1
else
    echo "🟢RPC checks completed successfully. None are accessible from the outside."
fi

#Create docker compose
cat <<EOF > docker-compose.yml
version: '3.8'

networks:
  backend-network:
    driver: bridge

services:
  mark1:
    image: byblaaz/mark1:latest
    container_name: mark1
    ports:
      - "$POLO1:$POLO1"
    networks:
      - backend-network
    env_file:
      - .env

  polo1:
    image: byblaaz/polo1:latest
    container_name: polo1
    network_mode: host
    restart: always
    env_file:
      - .env
EOF

echo "Pulling the Docker images..."
docker pull byblaaz/mark1:latest
docker pull byblaaz/polo1:latest

echo "Starting Docker Compose..."
docker compose --env-file .env up -d
