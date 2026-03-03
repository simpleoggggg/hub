#!/bin/bash

# --- CONFIGURATION ---
PROTECTED_USERS=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc")

# --- COLORS (Modern Palette) ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

# --- LOGIC FUNCTIONS ---
is_protected() {
    for u in "${PROTECTED_USERS[@]}"; do
        [[ "$1" == "$u" ]] && return 0
    done
    return 1
}

get_users() {
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd
}

is_sudo() {
    groups "$1" 2>/dev/null | grep -qw sudo
}

is_locked() {
    passwd -S "$1" 2>/dev/null | awk '{print $2}' | grep -q "L"
}

# --- NEW TYPE UI COMPONENTS ---
show_users() {
    mapfile -t USERS < <(get_users)
    echo -e "\n  ${CYAN}REGISTERED USERS${NC}"
    echo -e "  ${GRAY}ID   USERNAME          STATUS${NC}"
    echo -e "  ${GRAY}───  ───────────────   ──────────────${NC}"
    for i in "${!USERS[@]}"; do
        user="${USERS[$i]}"
        status="${GRAY}User${NC}"
        is_sudo "$user" && status="${GOLD}Sudo ⭐${NC}"
        is_locked "$user" && status="${RED}Locked 🔒${NC}"
        
        printf "  ${PURPLE}%-3d${NC}  %-15s   %-20b\n" $((i+1)) "$user" "$status"
    done
    echo ""
}

select_user() {
    show_users
    echo -ne "  ${CYAN}»${NC} ${WHITE}Select User ID:${NC} "
    read choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#USERS[@]}" ]; then
        SELECTED="${USERS[$((choice-1))]}"
        return 0
    fi
    echo -e "  ${RED}⚠ Invalid selection.${NC}"
    return 1
}

set_password() {
    echo -ne "  ${WHITE}Auto generate password? (y/n):${NC} "
    read yn
    if [[ "$yn" == "y" ]]; then
        PASS=$(openssl rand -base64 12)
        echo "$1:$PASS" | chpasswd
        echo -e "  ${GREEN}✔ New Password:${NC} ${WHITE}$PASS${NC}"
    else
        passwd "$1"
    fi
}

# --- MAIN LOOP ---
while true; do
    clear
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}👤 USER OVERLORD PRO${NC} ${GRAY}v4.0${NC}          ${GRAY}$(date +"%H:%M:%S")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    
    # --- MENU SIDEBAR ---
    echo -e "  ${CYAN}SINGLE USER ACTIONS${NC}"
    echo -e "  ${GRAY}├─${NC} ${PURPLE}[1]${NC} ${WHITE}Create New User${NC}      ${GRAY}[4]${NC} ${WHITE}Lock Account${NC}"
    echo -e "  ${GRAY}├─${NC} ${PURPLE}[2]${NC} ${WHITE}Delete User${NC}          ${GRAY}[5]${NC} ${WHITE}Unlock Account${NC}"
    echo -e "  ${GRAY}├─${NC} ${PURPLE}[3]${NC} ${WHITE}Reset Password${NC}       ${GRAY}[6]${NC} ${WHITE}Expiry Date${NC}"
    echo ""
    echo -e "  ${CYAN}BULK & ADVANCED${NC}"
    echo -e "  ${GRAY}├─${NC} ${PURPLE}[9]${NC}  ${GOLD}Bulk Pass Reset${NC}      ${GRAY}[12]${NC} ${WHITE}List All Users${NC}"
    echo -e "  ${GRAY}├─${NC} ${PURPLE}[10]${NC} ${RED}Bulk Lock${NC}            ${GRAY}[8]${NC}  ${WHITE}Login History${NC}"
    echo -e "  ${GRAY}└─${NC} ${PURPLE}[11]${NC} ${GREEN}Bulk Unlock${NC}"
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${PURPLE}[0]${NC} ${GRAY}Exit Manager${NC}"
    echo ""
    echo -ne "  ${CYAN}λ${NC} ${WHITE}Action:${NC} "
    read opt

    case $opt in
        1)
            echo -ne "  ${WHITE}New username:${NC} "
            read user
            useradd -m "$user"
            echo -ne "  ${WHITE}Grant Sudo? (y/n):${NC} "
            read sudo
            [[ "$sudo" == "y" ]] && usermod -aG sudo "$user"
            set_password "$user"
            sleep 2
            ;;

        2)
            if select_user; then
                if is_protected "$SELECTED"; then
                    echo -e "  ${RED}⚠ Access Denied: System User Protected.${NC}"
                else
                    userdel -r "$SELECTED"
                    echo -e "  ${GREEN}✔ User $SELECTED purged.${NC}"
                fi
            fi
            sleep 2
            ;;

        3) if select_user; then set_password "$SELECTED"; fi; sleep 2 ;;

        4)
            if select_user; then
                passwd -l "$SELECTED"
                echo -e "  ${RED}🔒 $SELECTED has been locked.${NC}"
            fi
            sleep 2
            ;;

        5)
            if select_user; then
                passwd -u "$SELECTED"
                echo -e "  ${GREEN}🔓 $SELECTED has been unlocked.${NC}"
            fi
            sleep 2
            ;;

        6)
            if select_user; then
                read -p "  Expiry Date (YYYY-MM-DD): " date
                chage -E "$date" "$SELECTED"
                echo -e "  ${GREEN}✔ Expiry updated.${NC}"
            fi
            sleep 2
            ;;

        8)
            if select_user; then
                echo -e "${CYAN}--- Login History for $SELECTED ---${NC}"
                last "$SELECTED" | head -n 10
                read -p "  Press Enter..."
            fi
            ;;

        9)
            show_users
            read -p "  Enter IDs (Space separated): " nums
            for n in $nums; do
                user="${USERS[$((n-1))]}"
                [[ -n "$user" ]] && set_password "$user"
            done
            sleep 2
            ;;

        10)
            show_users
            read -p "  IDs to LOCK: " nums
            for n in $nums; do
                user="${USERS[$((n-1))]}"
                [[ -n "$user" ]] && passwd -l "$user" && echo -e "  ${RED}Locked $user${NC}"
            done
            sleep 2
            ;;

        11)
            show_users
            read -p "  IDs to UNLOCK: " nums
            for n in $nums; do
                user="${USERS[$((n-1))]}"
                [[ -n "$user" ]] && passwd -u "$user" && echo -e "  ${GREEN}Unlocked $user${NC}"
            done
            sleep 2
            ;;

        12)
            show_users
            read -p "  Press Enter to return..."
            ;;

        0)
            echo -e "\n  ${CYAN}Goodbye!${NC}"
            exit 0
            ;;
    esac
done
