#!/bin/bash

# OS detect
source /etc/os-release

if [[ "$ID" == "ubuntu" ]]; then
    echo "Ubuntu detected"
    bash Ubuntu

elif [[ "$ID" == "debian" ]]; then
    echo "Debian detected"
    bash Debian

else
    echo "Unsupported OS: $ID"
fi
