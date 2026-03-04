#!/bin/bash

# --- CONFIG & COLORS ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

CONTAINERS=("ttest-caddy" "ttest-php" "ttest-workers" "ttest-workspace" "ttest-database-1" "ttest-redis-1")
IMAGES=("mysql" "redis" "ttest-caddy" "ttest-php" "ttest-workers" "ttest-workspace")
DB_NAME="convoy"
DB_USER="convoy_user"

# --- HEADER ---
clear
echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${PURPLE}│${NC}  ${RED}🗑️  CONVOY SYSTEM UNINSTALLER${NC} ${GRAY}v1.0${NC}           ${PURPLE}│${NC}"
echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"

# --- SAFETY CHECK ---
echo -e "  ${RED}WARNING:${NC} This will permanently delete your database and containers."
echo -ne "  ${WHITE}Are you absolutely sure? (y/N):${NC} "
read confirm
if [[ $confirm != "y" ]]; then
    echo -e "  ${CYAN}Operation cancelled.${NC}"
    exit 0
fi

# 1. Stop & Remove Containers
echo -e "\n  ${CYAN}DOCKER OPERATIONS${NC}"
for c in "${CONTAINERS[@]}"; do
    if [ "$(docker ps -aq -f name=$c)" ]; then
        echo -ne "  ${GRAY}├─ Stopping/Removing ${NC}$c... "
        docker stop $c &>/dev/null
        docker rm $c &>/dev/null
        echo -e "${GREEN}✔ Done${NC}"
    else
        echo -e "  ${GRAY}├─ $c :${NC} ${GRAY}Not found${NC}"
    fi
done

# 2. Remove Images
echo -e "\n  ${CYAN}IMAGE PURGE${NC}"
for i in "${IMAGES[@]}"; do
    if [ "$(docker images -q $i)" ]; then
        echo -ne "  ${GRAY}├─ Deleting image ${NC}$i... "
        docker rmi $i -f &>/dev/null
        echo -e "${GREEN}✔ Deleted${NC}"
    else
        echo -e "  ${GRAY}├─ $i :${NC} ${GRAY}Not found${NC}"
    fi
done

# 3. Database Cleanup
echo -e "\n  ${CYAN}DATABASE CLEANUP${NC}"
echo -ne "  ${GRAY}└─ Dropping ${DB_NAME} & ${DB_USER}... "
if mariadb -e "status" &>/dev/null; then
    mariadb -e "DROP DATABASE IF EXISTS ${DB_NAME};"
    mariadb -e "DROP USER IF EXISTS '${DB_USER}'@'127.0.0.1';"
    mariadb -e "FLUSH PRIVILEGES;"
    echo -e "${GREEN}✔ Purged${NC}"
else
    echo -e "${RED}✘ MariaDB not running${NC}"
fi

# --- SUMMARY ---
echo -e "\n${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${NC}  ${WHITE}SYSTEM CLEANUP SUCCESSFUL!${NC}                              ${GREEN}│${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "  ${GRAY}All requested Docker assets and DB entries are gone.${NC}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
