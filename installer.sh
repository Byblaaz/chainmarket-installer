#!/bin/bash

# Function to ask SYNC_CODE from user
ask_sync_code() {
  read -p $'If you don\'t have go to https://chainmarket.pro\nPlease enter your SYNC_CODE: ' SYNC_CODE
  if [ -z "$SYNC_CODE" ]; then
    echo "Error: SYNC_CODE cannot be empty"
    ask_sync_code
  fi
}

# Function to ask URL_RPC from user
ask_url_rpc() {
  read -p "Please enter your URL_RPC (or press Enter for null): " URL_RPC
  if [ -z "$URL_RPC" ]; then
    URL_RPC="null"
  fi
}

# Function to ask URL_WS from user
ask_url_ws() {
  read -p "Please enter your URL_WS (or press Enter for null): " URL_WS
  if [ -z "$URL_WS" ]; then
    URL_WS="null"
  fi
}

# Check and install Docker if necessary
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    # Insert installation steps for Docker here
  else
    echo "Docker is already installed."
  fi
}

# Check and install Docker Compose if necessary
check_docker_compose() {
  if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose not found. Installing Docker Compose..."
    # Insert installation steps for Docker Compose here
  else
    echo "Docker Compose is already installed."
  fi
}

# Check and install uuid-runtime if necessary
check_uuid_package() {
  if ! command -v uuid &> /dev/null; then
    echo "uuid-runtime not found. Installing uuid-runtime..."
    # Insert installation steps for uuid-runtime here
  else
    echo "uuid-runtime is already installed."
  fi
}

# Function to generate a random UUID
generate_uuid() {
  uuidgen
}

# Check if the .env file already exists
if [ ! -f ".env" ]; then
  echo "Creating the .env file..."

  # Generate a random UUID
  UUID=$(generate_uuid)

  # Ask user to provide the value of SYNC_CODE, URL_RPC, and URL_WS
  ask_sync_code
  ask_url_rpc
  ask_url_ws

  # Write variables to the .env file
  echo "RANDOM_UUID=$UUID" > ".env"
  echo "SYNC_CODE=$SYNC_CODE" >> ".env"
  echo "URL_RPC=$URL_RPC" >> ".env"
  echo "URL_WS=$URL_WS" >> ".env"

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

  # Check if SYNC_CODE is present in the .env file
  if [ -z "$SYNC_CODE" ]; then
    echo "SYNC_CODE is missing in the .env file."
    ask_sync_code
    echo "SYNC_CODE=$SYNC_CODE" >> ".env"
  fi

  # Check if URL_RPC is present in the .env file and not empty
  if [ -z "$URL_RPC" ]; then
    echo "URL_RPC is missing or null in the .env file."
    ask_url_rpc
    echo "URL_RPC=$URL_RPC" >> ".env"
  fi

  # Check if URL_WS is present in the .env file and not empty
  if [ -z "$URL_WS" ]; then
    echo "URL_WS is missing or null in the .env file."
    ask_url_ws
    echo "URL_WS=$URL_WS" >> ".env"
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
