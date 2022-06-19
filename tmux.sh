#!/bin/bash

apt update

apt install tmux -y

wget https://raw.githubusercontent.com/botkee/double/main/start.sh

chmod +x start.sh

tmux kill-server

tmux new-session -d -s vpnsetup;

tmux send-keys -t vpnsetup 'bash /root/start.sh' C-m;

tmux attach-session -d -t vpnsetup;
