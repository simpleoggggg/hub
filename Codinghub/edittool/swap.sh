#!/bin/bash

# --- CONFIGURATION ---
SWAP_FILE="/swapfile_auto"

# --- COLORS (Cyberpunk / Modern Palette) ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

# --- HELPER FUNCTIONS ---
total_ram_mb() { free -m | awk '/Mem:/ {print $2}'; }

# Visual RAM Bar Generator
draw_bar() {
    local percent=$1
    local width=30
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    local color=$GREEN
    [ "$percent" -gt 60 ] && color=$GOLD
    [ "$percent" -gt 85 ] && color=$RED
    
    printf "  ${GRAY}[${NC}"
    printf "${color}%0.s#${NC}" $(seq 1 $filled)
    [ $empty -gt 0 ] && printf "${GRAY}%0.s-${NC}" $(seq 1 $empty)
    printf "${GRAY}]${NC} ${WHITE}${percent}%%${NC}\n"
}

recommended_swap_mb() {
    RAM=$(total_ram_mb)
    if [ "$RAM" -le 2048 ]; then echo "$RAM"; elif [ "$RAM" -le 8192 ]; then echo 4096; else echo 8192; fi
}

recommended_zram_percent() {
    RAM=$(total_ram_mb)
    if [ "$RAM" -le 2048 ]; then echo 75; elif [ "$RAM" -le 8192 ]; then echo 50; else echo 30; fi
}

convert_to_mb() {
    input="$1"
    if [[ "$input" =~ ^[0-9]+[Gg]$ ]]; then echo $((${input%[Gg]} * 1024))
    elif [[ "$input" =~ ^[0-9]+[Mm]$ ]]; then echo ${input%[Mm]}
    elif [[ "$input" =~ ^[0-9]+$ ]]; then echo "$input"
    else echo 0; fi
}

# --- NEW TYPE UI UI ELEMENTS ---
show_details() {
    local mem_total=$(free -h | awk '/Mem:/ {print $2}')
    local mem_used=$(free -h | awk '/Mem:/ {print $3}')
    local swp_total=$(free -h | awk '/Swap:/ {print $2}')
    local swp_used=$(free -h | awk '/Swap:/ {print $3}')
    local ram_p=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')

    echo -e "  ${CYAN}MEMORY METRICS${NC}"
    echo -e "  ${GRAY}├─ RAM Usage :${NC} ${WHITE}$mem_used / $mem_total${NC}"
    draw_bar $ram_p
    echo -e "  ${GRAY}└─ Swap Usage:${NC} ${WHITE}$swp_used / $swp_total${NC}"
    
    echo -e "\n  ${CYAN}ACTIVE DEVICES${NC}"
    if [[ -z $(swapon --show) ]]; then
        echo -e "  ${RED}└─ No active swap detected!${NC}"
    else
        swapon --show --noheadings | awk '{printf "  \033[38;5;242m├─ \033[38;5;255m%-15s \033[38;5;141m[%s]\033[0m\n", $1, $3}'
    fi
}

# --- ZRAM SUB-MENU ---
zram_menu() {
    ZRAM_PERCENT=$(recommended_zram_percent)
    while true; do
        clear
        echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${PURPLE}│${NC}  ${CYAN}🌀 ZRAM OPTIMIZER${NC}                          ${GRAY}ACTIVE${NC}  ${PURPLE}│${NC}"
        echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
        show_details
        echo -e "\n  ${GOLD}CONFIGURATION${NC}"
        echo -e "  ${GRAY}├─ Auto Recommendation :${NC} ${GREEN}$(recommended_zram_percent)%${NC}"
        echo -e "  ${GRAY}└─ Current Buffer Target:${NC} ${WHITE}$ZRAM_PERCENT%${NC}"
        echo -e "\n  ${PURPLE}[1]${NC} Enable ZRAM (Auto)    ${PURPLE}[3]${NC} Resize ZRAM"
        echo -e "  ${PURPLE}[2]${NC} Disable ZRAM          ${PURPLE}[4]${NC} Set Custom %"
        echo -e "  ${PURPLE}[0]${NC} Back to Main"
        echo ""
        echo -ne "  ${CYAN}λ${NC} ${WHITE}Z-Command:${NC} "
        read opt

        case $opt in
            1)
                ZRAM_PERCENT=$(recommended_zram_percent)
                TOTAL=$(total_ram_mb)
                SIZE=$((TOTAL * ZRAM_PERCENT / 100))
                modprobe zram 2>/dev/null
                echo $((SIZE * 1024 * 1024)) > /sys/block/zram0/disksize 2>/dev/null
                mkswap /dev/zram0 >/dev/null
                swapon /dev/zram0
                echo -e "${GREEN}✔ ZRAM Active at ${SIZE}MB${NC}"; sleep 1 ;;
            2)
                swapoff /dev/zram0 2>/dev/null
                echo 1 > /sys/block/zram0/reset 2>/dev/null
                echo -e "${RED}✘ ZRAM Deactivated${NC}"; sleep 1 ;;
            3)
                TOTAL=$(total_ram_mb)
                SIZE=$((TOTAL * ZRAM_PERCENT / 100))
                swapoff /dev/zram0 2>/dev/null
                echo 1 > /sys/block/zram0/reset 2>/dev/null
                echo $((SIZE * 1024 * 1024)) > /sys/block/zram0/disksize 2>/dev/null
                mkswap /dev/zram0 >/dev/null
                swapon /dev/zram0
                echo -e "${GREEN}✔ Resized to ${SIZE}MB${NC}"; sleep 1 ;;
            4) read -p "Enter % (10-100): " val
               [[ "$val" =~ ^[0-9]+$ ]] && ZRAM_PERCENT=$val ;;
            0) break ;;
        esac
    done
}

# --- SWAP SUB-MENU ---
swap_menu() {
    while true; do
        clear
        echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${PURPLE}│${NC}  ${CYAN}💾 SWAP FILE MANAGER${NC}                      ${GRAY}STORAGE${NC}  ${PURPLE}│${NC}"
        echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
        show_details
        echo -e "\n  ${GRAY}Recommended Size :${NC} ${GOLD}$(recommended_swap_mb) MB${NC}"
        echo -e "\n  ${PURPLE}[1]${NC} Auto-Create Swap      ${PURPLE}[3]${NC} Resize File"
        echo -e "  ${PURPLE}[2]${NC} Delete Swap File      ${PURPLE}[4]${NC} Custom Size"
        echo -e "  ${PURPLE}[0]${NC} Back to Main"
        echo ""
        echo -ne "  ${CYAN}λ${NC} ${WHITE}S-Command:${NC} "
        read opt

        case $opt in
            1)
                SIZE=$(recommended_swap_mb)
                swapoff $SWAP_FILE 2>/dev/null
                rm -f $SWAP_FILE
                fallocate -l ${SIZE}M $SWAP_FILE && chmod 600 $SWAP_FILE
                mkswap $SWAP_FILE >/dev/null && swapon $SWAP_FILE
                echo -e "${GREEN}✔ Created ${SIZE}MB Swap${NC}"; sleep 1 ;;
            2)
                swapoff $SWAP_FILE 2>/dev/null
                rm -f $SWAP_FILE
                sed -i "\|$SWAP_FILE|d" /etc/fstab
                echo -e "${RED}✘ Swap Deleted${NC}"; sleep 1 ;;
            4)
                read -p "Size (e.g. 2G or 1024M): " input
                SIZE=$(convert_to_mb "$input")
                if [ "$SIZE" -gt 0 ]; then
                    swapoff $SWAP_FILE 2>/dev/null
                    fallocate -l ${SIZE}M $SWAP_FILE && chmod 600 $SWAP_FILE
                    mkswap $SWAP_FILE >/dev/null && swapon $SWAP_FILE
                fi ;;
            0) break ;;
        esac
    done
}

# --- MAIN LOOP ---
while true; do
    clear
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🧠 MEMORY CONTROL UNIT${NC} ${GRAY}v5.0${NC}          ${GRAY}$(date +"%H:%M:%S")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    show_details
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${PURPLE}[1]${NC} ${WHITE}ZRAM Optimizer${NC}        ${GRAY}(Compressed RAM)${NC}"
    echo -e "  ${PURPLE}[2]${NC} ${WHITE}Swap File Manager${NC}     ${GRAY}(Disk Paging)${NC}"
    echo -e "  ${PURPLE}[0]${NC} ${GRAY}Exit Manager${NC}"
    echo ""
    echo -ne "  ${CYAN}λ${NC} ${WHITE}Action:${NC} "
    read mainopt

    case $mainopt in
        1) zram_menu ;;
        2) swap_menu ;;
        0) echo -e "\n  ${CYAN}Memory clean. Exiting...${NC}"; exit 0 ;;
    esac
done
