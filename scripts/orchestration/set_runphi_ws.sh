#!/bin/bash

# Define the remote server and directory
# {USER}="root"
# {IP}="192.0.3.76"

current_dir=$(dirname -- "$(readlink -f -- "$0")")
runPHI_dir=$(dirname "${current_dir}")
runphi_dir=$(dirname "${runPHI_dir}")
script_dir=${runphi_dir}/scripts

source "${script_dir}"/common/set_environment.sh "${TARGET}" "${BACKEND}"

REMOTE_DIRECTORY="/usr/share/runPHI/"

# Create the directory on the remote server if it doesn't exist
ssh "${USER}@${IP}" "mkdir -p $REMOTE_DIRECTORY"

# Copy runPHI cell files into environment {IP} (e.g., QEMU/Jailhouse root cell)
scp -r ./runPHI_cell_configs "${USER}@${IP}:$REMOTE_DIRECTORY"

echo "Created directory and copied files to the remote server."
