#!/bin/bash

# Check if Docker is installed, if not, install it
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    if [ -x "$(command -v apt-get)" ]; then
      sudo apt-get update -y
      sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
      sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo apt-get update -y
      sudo apt-get install -y docker-ce
    elif [ -x "$(command -v yum)" ]; then
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io
    elif [ -x "$(command -v apk)" ]; then
      sudo apk add --no-cache docker
    else
      echo "Cannot install Docker. Please install it manually."
      exit 1
    fi
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
  fi
}

# Check if Docker Compose is installed, if not, install it
check_docker_compose() {
  if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi
}

# Check if uuid-runtime package is installed, if not, install it
check_uuid_package() {
  if ! command -v uuidgen &> /dev/null; then
    echo "Installing uuid-runtime package..."
    if [ -x "$(command -v apt-get)" ]; then
      sudo apt-get update -y
      sudo apt-get install -y uuid-runtime
    elif [ -x "$(command -v yum)" ]; then
      sudo yum install -y uuid-runtime
    elif [ -x "$(command -v apk)" ]; then
      sudo apk add --no-cache util-linux
    else
      echo "Cannot install uuid-runtime package. Please install it manually."
      exit 1
    fi
  fi
}

# Function to generate a random UUID
generate_uuid() {
  uuidgen
}

# Function to ask RPC_KEY from user
ask_rpc_key() {
  read -p $'If you don\'t have go to https://chainmarket.pro\nPlease enter your RPC_KEY: ' RPC_KEY
  if [ -z "$RPC_KEY" ]; then
    echo "Error: RPC_KEY cannot be empty"
    ask_rpc_key
  fi
}

# Function to ask URL_RPC from user
ask_url_rpc() {
  read -p "Please enter your URL_RPC: " URL_RPC
  if [ -z "$URL_RPC" ]; then
    echo "Error: URL_RPC cannot be empty"
    ask_url_rpc
  fi
}

# Check and install Docker if necessary
check_docker

# Check and install Docker Compose if necessary
check_docker_compose

# Check and install uuid-runtime if necessary
check_uuid_package

# Check if the .env file already exists
if [ ! -f ".env" ]; then
  echo "Creating the .env file..."

  # Generate a random UUID
  UUID=$(generate_uuid)

  # Ask user to provide the value of RPC_KEY and URL_RPC
  ask_rpc_key
  ask_url_rpc

  # Write variables to the .env file
  echo "RANDOM_UUID=$UUID" > ".env"
  echo "RPC_KEY=$RPC_KEY" >> ".env"
  echo "URL_RPC=$URL_RPC" >> ".env"

  echo "The .env file has been created successfully."

else
  echo "The .env file already exists."
  source .env

  # Check if RANDOM_UUID is present in the .env file, generate if missing
  if [ -z "$RANDOM_UUID" ]; then
    echo "RANDOM_UUID is missing in the .env file. Generating new UUID..."
    UUID=$(generate_uuid)
    echo "RANDOM_UUID=$UUID" >> ".env"
  fi

  # Check if RPC_KEY is present in the .env file
  if [ -z "$RPC_KEY" ]; then
    echo "RPC_KEY is missing in the .env file."
    ask_rpc_key
    echo "RPC_KEY=$RPC_KEY" >> ".env"
  fi

  # Check if URL_RPC is present in the .env file
  if [ -z "$URL_RPC" ]; then
    echo "URL_RPC is missing in the .env file."
    ask_url_rpc
    echo "URL_RPC=$URL_RPC" >> ".env"
  fi
fi

# Check if docker-compose.yml exists, if not, create it
if [ ! -f "docker-compose.yml" ]; then
  echo "Creating the docker-compose.yml file..."

  cat <<EOL > docker-compose.yml
version: '3.8'

networks:
  backend-network:  # Define the custom network backend-network

services:
  mark1:
    image: byblaaz/mark1:latest
    ports:
      - "3100:3100"  # Expose the port of your Node.js application
    networks:
      - backend-network  # Use the custom network backend-network
    env_file:
      - .env  # Ensure the path is correct

  polo1:
    image: byblaaz/polo1:latest
    ports:
      - "98:80"  # Expose the Nginx port
    restart: always  # Automatically restart the container in case of unexpected shutdown
    networks:
      - backend-network  # Use the custom network backend-network
    env_file:
      - .env  # Ensure the path is correct
EOL

  echo "The docker-compose.yml file has been created successfully."
else
  echo "The docker-compose.yml file already exists."
fi


echo "Pulling the Docker images..."
docker pull byblaaz/mark1:latest
docker pull byblaaz/polo1:latest

echo "Starting Docker Compose..."
docker compose --env-file .env up
