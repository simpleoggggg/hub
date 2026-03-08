#!/bin/bash

# --- CONFIG & SEMA UI COLORS ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

SERVICE="wings"

# --- HELPER FUNCTIONS ---
get_status() {
    if systemctl is-active --quiet $SERVICE; then
        echo -e "${GREEN}ACTIVE${NC}"
    else
        echo -e "${RED}INACTIVE${NC}"
    fi
}

show_header() {
    clear
    STATUS=$(get_status)
    UPTIME=$(systemctl show -p ActiveEnterTimestamp $SERVICE | cut -d'=' -f2)
    
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🪽  WINGS CONTROL CENTER${NC} ${GRAY}v17.0${NC}          ${GRAY}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${CYAN}NODE DIAGNOSTICS${NC}"
    echo -e "  ${GRAY}├─ Service :${NC} ${WHITE}$SERVICE${NC}   ${GRAY}Status :${NC} $STATUS"
    echo -e "  ${GRAY}└─ Active  :${NC} ${GRAY}${UPTIME:-N/A}${NC}"
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
}

# --- AUTO SETUP SUB-MENU ---
auto_setup() {
    while true; do
        show_header
        echo -e "  ${GOLD}🚀 AUTO-SETUP PROTOCOLS${NC}"
        echo -e "  ${GRAY}├─ [1]${NC} Configure Node 01 ${GRAY}(Auto-Fetch)${NC}"
        echo -e "  ${GRAY}├─ [2]${NC} Configure Node 02 ${GRAY}(Manual Paste)${NC}"
        echo -e "  ${GRAY}├─ [3]${NC} Finalize Deployment ${GRAY}(Start Node)${NC}"
        echo -e "  ${GRAY}└─ [0]${NC} Back to Master Menu"
        echo ""
        echo -ne "  ${CYAN}λ${NC} ${WHITE}Setup-Action:${NC} "
        read -r s_choice

        case $s_choice in
            1) echo -e "\n  ${CYAN}➜ Running Config-01 Logic...${NC}"; sleep 2 ;;
            2) echo -e "\n  ${CYAN}➜ Running Config-02 Logic...${NC}"; sleep 2 ;;
            3) echo -e "\n  ${GREEN}➜ Deploying Wings Node...${NC}"; systemctl enable --now wings; sleep 2 ;;
            0) break ;;
        esac
    done
}

# --- MAIN CONTROLLER ---
while true; do
    show_header
    echo -e "  ${CYAN}SERVICE MANAGEMENT${NC}"
    echo -e "  ${GRAY}├─ [1]${NC} Start       ${GRAY}[4]${NC} Status"
    echo -e "  ${GRAY}├─ [2]${NC} Restart     ${GRAY}[5]${NC} Live  Logs"
    echo -e "  ${GRAY}└─ [3]${NC} Stop        ${GRAY}[6]${NC} Debug Mode ${GOLD}(Manual)${NC}"
    echo ""
    echo -e "  ${PURPLE}ADVANCED TOOLS${NC}"
    echo -e "  ${GRAY}├─ [A]${NC} ${WHITE}Auto-Setup Wizard${NC}  ${GRAY}(New)${NC}"
    echo -e "  ${GRAY}└─ [0]${NC} ${RED}Exit Manager${NC}"
    echo ""
    echo -ne "  ${CYAN}λ${NC} ${WHITE}Master Command:${NC} "
    read -r choice

    case $choice in
        1) sudo systemctl start $SERVICE; echo -e "  ${GREEN}✔ Started${NC}"; sleep 1 ;;
        2) sudo systemctl restart $SERVICE; echo -e "  ${CYAN}✔ Restarted${NC}"; sleep 1 ;;
        3) sudo systemctl stop $SERVICE; echo -e "  ${RED}✔ Stopped${NC}"; sleep 1 ;;
        4) echo -e "\n${WHITE}--- FULL SYSTEMCTL OUTPUT ---${NC}"; systemctl status $SERVICE --no-pager; read -p "Enter to return..." ;;
        5) echo -e "\n${GOLD}--- STREAMING LOGS (Ctrl+C to stop) ---${NC}"; journalctl -u $SERVICE -f ;;
        6) echo -e "\n${RED}⚠️  DEBUG MODE ACTIVATED${NC}"; sudo systemctl stop $SERVICE; sudo wings; read -p "Enter to return..." ;;
        [Aa]) auto_setup ;;
        0) echo -e "\n  ${GRAY}Closing Uplink... Goodbye.${NC}"; exit 0 ;;
        *) echo -e "  ${RED}⚠ Invalid Selection${NC}"; sleep 1 ;;
    esac
done
