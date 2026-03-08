#!/bin/bash

# --- CONFIG & SEMA UI COLORS ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;220m'
BG_SHADE='\033[48;5;236m'
NC='\033[0m'

# --- NUBAR ANALYTICS (Navigation Bar) ---
get_nubar() {
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.0f", $2+$4}')
    RAM=$(free | grep Mem | awk '{printf "%.0f", $3*100/$2}')
    UPT=$(uptime -p | sed 's/up //')
    SEL_IMG="${IMAGE:-NONE}"
    
    # Glass-Pill Style Top Bar
    echo -e " ${PURPLE}${NC}${BG_SHADE}${WHITE}  CPU: $CPU% ${NC}${PURPLE}${NC}  ${CYAN}${NC}${BG_SHADE}${WHITE}  RAM: $RAM% ${NC}${CYAN}${NC}  ${GOLD}${NC}${BG_SHADE}${WHITE}  $UPT ${NC}${GOLD}${NC}  ${GREEN}${NC}${BG_SHADE}${WHITE} 📦 SEL: $SEL_IMG ${NC}${GREEN}${NC}"
}

# --- DOKO LIVE MONITOR (Show All Containers) ---
render_grid() {
    if ! command -v docker &> /dev/null; then return; fi
    echo -e "  ${CYAN}  ACTIVE DOKO NODES${NC}"
    echo -e "  ${GRAY}┌──────────┬──────────┬──────────────┬──────────────┬────────────┐${NC}"
    echo -e "  ${GRAY}│${NC} ${WHITE}NAME${NC}      ${GRAY}│${NC} ${WHITE}ID${NC}        ${GRAY}│${NC} ${WHITE}LOCAL IP${NC}     ${GRAY}│${NC} ${WHITE}HOST:CONT${NC}    ${GRAY}│${NC} ${WHITE}STATUS${NC}     ${GRAY}│${NC}"
    echo -e "  ${GRAY}├──────────┼──────────┼──────────────┼──────────────┼────────────┤${NC}"
    docker ps -a --format "{{.Names}}|{{.ID}}|{{.Status}}|{{.Ports}}" | head -n 5 | while read -r line; do
        IFS='|' read -r name id status ports <<< "$line"
        ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null || echo "0.0.0.0")
        mapping=$(echo "$ports" | grep -oP '\d+->\d+' | head -n1 | sed 's/->/:/')
        p_stat=$([[ "$status" == *"Up"* ]] && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
        printf "  ${GRAY}│${NC} %-8.8s ${GRAY}│${NC} %-8.8s ${GRAY}│${NC} %-12.12s ${GRAY}│${NC} %-12.12s ${GRAY}│${NC} %-10b ${GRAY}│${NC}\n" "$name" "$id" "$ip" "${mapping:- ---}" "$p_stat"
    done
    echo -e "  ${GRAY}└──────────┴──────────┴──────────────┴──────────────┴────────────┘${NC}"
}

# --- HELPERS ---
gen_pass() { openssl rand -base64 12; }

# --- MAIN INTERFACE ---
OS_IMAGES=(
ubuntu:22.04
ubuntu:24.04
ubuntu:20.04
debian:12
debian:11
debian:10
debian:13
)

while true; do
    IMAGE=""
    clear
    get_nubar
    echo -e "${PURPLE}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🛰️  GENESIS DEPLOYMENT ENGINE${NC} ${GRAY}v25.0${NC}                 ${GRAY}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└────────────────────────────────────────────────────────────────────────────┘${NC}"
    render_grid

    echo -e "\n  ${GOLD}🌐 OS SELECTION MATRIX${NC}"
    echo -e "  ${GRAY}------------------------------------------------------------${NC}"
    for i in "${!OS_IMAGES[@]}"; do
        echo -e "  ${PURPLE}[$i]${NC} ${OS_IMAGES[$i]}"
    done
    echo -e "  ${GRAY}------------------------------------------------------------${NC}"
    
    echo -ne "  ${CYAN}λ${NC} ${WHITE}Enter OS number:${NC} "
    read osid

    IMAGE=${OS_IMAGES[$osid]}

    if [ -z "$IMAGE" ]; then
        echo -e "  ${RED}⚠ Invalid selection${NC}"
        sleep 1
    else
        echo -e "  ${GREEN}✔ Selected OS: $IMAGE${NC}"
        break
    fi
done

# --- RESOURCE CONFIGURATION ---
echo -e "\n  ${CYAN}⚙️  RESOURCE CONFIGURATION${NC}"
echo -ne "  ${GRAY}├─ Hostname   :${NC} "; read HOSTNAME
echo -ne "  ${GRAY}├─  user     :${NC} "; read USER
echo -ne "  ${GRAY}├─ User pass  :${NC} "; read USERPASS
echo -ne "  ${GRAY}├─ RAM        :${NC} "; read RAM
echo -ne "  ${GRAY}└─ CPU        :${NC} "; read CPU

# Security Logic
ROOTPASS=$(gen_pass)
PORT=$(shuf -i 2000-65000 -n1)
IP=$(curl -s ifconfig.me)

# --- DEPLOYMENT ---
echo -e "\n  ${GOLD}🚀 INITIATING VIRTUALIZATION...${NC}"
rm Dockerfile
cat > Dockerfile <<EOF
FROM $IMAGE

ENV container docker
ENV DEBIAN_FRONTEND=noninteractive

# packages
RUN apt-get update && apt-get install -y \
    systemd systemd-sysv dbus \
    openssh-server sudo \
    curl wget vim nano htop \
    net-tools iputils-ping \
    && apt-get clean

# ssh setup
RUN mkdir -p /var/run/sshd
RUN echo 'root:root' | chpasswd

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# enable ssh
RUN systemctl enable ssh || true

EXPOSE 22

STOPSIGNAL SIGRTMIN+3

CMD ["/lib/systemd/systemd"]
EOF
docker build -t $HOSTNAME .
docker run -d \
--name $HOSTNAME \
--hostname $HOSTNAME \
--memory="$RAM" \
--cpus="$CPU" \
--privileged \
--cgroupns=host \
-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
-p $PORT:22 \
$HOSTNAME
# Logging deployment
echo "$HOSTNAME $PORT $ROOTPASS $USER" >> deployments.log

echo -e "\n${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${NC}  ${WHITE}VPS CREATED SUCCESSFULLY!${NC}                               ${GREEN}│${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "  ${CYAN}CONNECTION DETAILS${NC}"
echo -e "  ${GRAY}├─ SSH Command :${NC} ${WHITE}ssh root@$IP -p $PORT${NC}"
echo -e "  ${GRAY}├─ Root Pass   :${NC} ${GOLD}$ROOTPASS${NC}"
echo -e "  ${GRAY}└─ OS Image    :${NC} ${PURPLE}$IMAGE${NC}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}\n"
