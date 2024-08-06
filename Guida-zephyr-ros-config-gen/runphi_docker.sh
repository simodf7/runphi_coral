#!/bin/bash

# Path to the temporary file
TEMP_FILE="/tmp/bridge_created"

# Container name
CONTAINER_NAME="jhqemu"

# Function to start a shell inside the running container
start_shell_in_container() {
	  docker exec -it "$CONTAINER_NAME" /bin/bash -l
  }

  # Check if the container is already running
  if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
	    echo "Container $CONTAINER_NAME is already running. Starting a shell inside the container..."
	      start_shell_in_container
      else
  #echo "Container $CONTAINER_NAME is not running. Proceeding with setup..."

  # Check if the temporary file exists
  if [ ! -f "$TEMP_FILE" ]; then
  	# Source the script
  	source ~/runphi/scripts/qemu/setup_bridge.sh
  	# Create the temporary file to indicate the script has been sourced
	touch "$TEMP_FILE"
  fi

  docker run -it --rm \
  --user root \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /dev/net:/dev/net \
  -e "TERM=xterm-256color" \
  --net=host \
  --name "$CONTAINER_NAME" \
  -v ./runphi:/home runphidocker \
  /bin/bash -l
  fi
