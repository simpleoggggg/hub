#!/bin/bash

# --- SEMA UI NETWORK MENU ---
# Features: Packet Loss Monitor, Traffic Shaper, Bandwidth Graph, VPS Health

# --- CONFIG & COLORS ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
BLUE='\033[38;5;39m'
NC='\033[0m'
BOLD='\033[1m'

# --- CONFIGURATION ---
TARGET_HOST="8.8.8.8"
PING_COUNT=10
REFRESH_INTERVAL=2
NETWORK_INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5}' | head -n1)
[ -z "$NETWORK_INTERFACE" ] && NETWORK_INTERFACE="eth0"

# --- UI HELPER FUNCTIONS ---
draw_bar() {
    local percent=$1
    local color=$2
    local width=30
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    
    printf "${GRAY}[${NC}"
    for ((i=1; i<=filled; i++)); do printf "${color}█${NC}"; done
    for ((i=1; i<=empty; i++)); do printf "${GRAY}░${NC}"; done
    printf "${GRAY}]${NC} ${WHITE}${percent}%%${NC}"
}

print_header() {
    local title="$1"
    local color="$2"
    echo -e "${color}┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${color}│${NC}  ${BOLD}${WHITE}$title${NC}${color}${NC}"
    echo -e "${color}└──────────────────────────────────────────────────────────────┘${NC}"
}

print_footer() {
    echo -e "\n${GRAY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "${CYAN}Press Enter to continue...${NC}"
    read
}

# --- 1. PACKET LOSS MONITOR (with detailed stats) ---
packet_loss_monitor() {
    while true; do
        clear
        print_header "📊 PACKET LOSS MONITOR (Target: $TARGET_HOST)" "$PURPLE"
        
        echo -e "${WHITE}Testing connection...${NC}\n"
        
        # Run ping test and capture output
        local ping_output=$(ping -c $PING_COUNT $TARGET_HOST 2>&1)
        local loss=$(echo "$ping_output" | grep -oP '\d+(?=% packet loss)')
        [ -z "$loss" ] && loss=100
        
        # Get RTT statistics
        local rtt_stats=$(echo "$ping_output" | grep -oP 'min/avg/max.*? = \K[^/]+/[^/]+/[^/]+')
        local min_rtt=$(echo "$rtt_stats" | cut -d'/' -f1)
        local avg_rtt=$(echo "$rtt_stats" | cut -d'/' -f2)
        local max_rtt=$(echo "$rtt_stats" | cut -d'/' -f3)
        
        # Display packet loss with visual indicator
        echo -ne "${WHITE}Packet Loss :${NC} "
        if [ "$loss" -eq 0 ]; then
            echo -e "${GREEN}✔ 0% (Excellent)${NC}"
        elif [ "$loss" -lt 3 ]; then
            echo -e "${GOLD}⚠ $loss% (Acceptable)${NC}"
        else
            echo -e "${RED}✘ $loss% (Critical)${NC}"
        fi
        
        # Draw loss bar
        echo -ne "             "
        draw_bar $((100 - loss)) $([ "$loss" -lt 3 ] && echo "$GREEN" || echo "$RED")
        echo ""
        
        # Display RTT stats if available
        if [ -n "$avg_rtt" ]; then
            echo -e "\n${WHITE}Latency Stats (ms):${NC}"
            printf "  ${GRAY}Min:${NC} ${CYAN}%7.2f${NC}   ${GRAY}Avg:${NC} ${PURPLE}%7.2f${NC}   ${GRAY}Max:${NC} ${GOLD}%7.2f${NC}\n" $min_rtt $avg_rtt $max_rtt
        else
            echo -e "\n${RED}✘ No response from host${NC}"
        fi
        
        echo -e "\n${GRAY}Options: [R]efresh | [C]hange Target | [M]ain Menu${NC}"
        echo -ne "${CYAN}λ${NC} ${WHITE}Choice:${NC} "
        read -n1 opt
        echo ""
        
        case $opt in
            [Rr]) continue ;;
            [Cc]) 
                echo -ne "\n${WHITE}Enter target host/IP:${NC} "
                read new_target
                [ -n "$new_target" ] && TARGET_HOST=$new_target
                ;;
            [Mm]) return ;;
        esac
    done
}

# --- 2. TRAFFIC SHAPING LIMITER ---
traffic_shaper() {
    clear
    print_header "🚦 TRAFFIC SHAPING LIMITER (Interface: $NETWORK_INTERFACE)" "$CYAN"
    
    # Show current limits
    echo -e "${WHITE}Current Configuration:${NC}"
    if tc qdisc show dev $NETWORK_INTERFACE 2>/dev/null | grep -q "tbf"; then
        local current_rate=$(tc qdisc show dev $NETWORK_INTERFACE | grep -oP 'rate \K[0-9]+[a-zA-Z]*')
        echo -e "  ${GREEN}✔ Active Limit: ${BOLD}${current_rate:-Unknown}${NC}\n"
    else
        echo -e "  ${GRAY}○ No active limits${NC}\n"
    fi
    
    echo -e "${WHITE}Select Limit:${NC}"
    echo -e "  ${PURPLE}[1]${NC} ${WHITE}1 Mbps${NC}   ${GRAY}(Basic)${NC}"
    echo -e "  ${PURPLE}[2]${NC} ${WHITE}5 Mbps${NC}   ${GRAY}(Standard)${NC}"
    echo -e "  ${PURPLE}[3]${NC} ${WHITE}10 Mbps${NC}  ${GRAY}(Premium)${NC}"
    echo -e "  ${PURPLE}[4]${NC} ${WHITE}50 Mbps${NC}  ${GRAY}(High-speed)${NC}"
    echo -e "  ${PURPLE}[5]${NC} ${WHITE}100 Mbps${NC} ${GRAY}(Ultra)${NC}"
    echo -e "  ${PURPLE}[C]${NC} ${WHITE}Custom Rate${NC}"
    echo -e "  ${PURPLE}[R]${NC} ${RED}Remove Limits${NC}"
    echo -e "  ${PURPLE}[0]${NC} ${GRAY}Back${NC}"
    echo ""
    echo -ne "${CYAN}λ${NC} ${WHITE}Selection:${NC} "
    read topt
    
    case $topt in
        1) tc qdisc replace dev $NETWORK_INTERFACE root tbf rate 1mbit burst 32kbit latency 50ms
           echo -e "${GREEN}✔ Limit set to 1 Mbps${NC}" ;;
        2) tc qdisc replace dev $NETWORK_INTERFACE root tbf rate 5mbit burst 64kbit latency 50ms
           echo -e "${GREEN}✔ Limit set to 5 Mbps${NC}" ;;
        3) tc qdisc replace dev $NETWORK_INTERFACE root tbf rate 10mbit burst 128kbit latency 50ms
           echo -e "${GREEN}✔ Limit set to 10 Mbps${NC}" ;;
        4) tc qdisc replace dev $NETWORK_INTERFACE root tbf rate 50mbit burst 256kbit latency 50ms
           echo -e "${GREEN}✔ Limit set to 50 Mbps${NC}" ;;
        5) tc qdisc replace dev $NETWORK_INTERFACE root tbf rate 100mbit burst 512kbit latency 50ms
           echo -e "${GREEN}✔ Limit set to 100 Mbps${NC}" ;;
        [Cc])
           echo -ne "\n${WHITE}Enter rate (e.g., 20mbit, 500kbit):${NC} "
           read custom_rate
           if [ -n "$custom_rate" ]; then
               tc qdisc replace dev $NETWORK_INTERFACE root tbf rate $custom_rate burst 32kbit latency 50ms
               echo -e "${GREEN}✔ Limit set to $custom_rate${NC}"
           fi
           ;;
        [Rr]) 
           tc qdisc del dev $NETWORK_INTERFACE root 2>/dev/null
           echo -e "${RED}✔ Limits removed${NC}" ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    sleep 2
}

# --- 3. REAL-TIME BANDWIDTH GRAPH ---
bandwidth_graph() {
    clear
    print_header "📈 REAL-TIME BANDWIDTH MONITOR (Interface: $NETWORK_INTERFACE)" "$PURPLE"
    echo -e "${GRAY}Press Ctrl+C to return to menu${NC}\n"
    
    # Initialize variables
    local max_rx_speed=0
    local max_tx_speed=0
    local history=()
    local history_size=50
    
    # Get initial values
    local rx_bytes_old=$(cat /sys/class/net/$NETWORK_INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx_bytes_old=$(cat /sys/class/net/$NETWORK_INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)
    
    # Trap Ctrl+C to return to menu
    trap 'echo -e "\n${GREEN}Returning to menu...${NC}"; sleep 1; return' INT
    
    while true; do
        # Get current bytes
        local rx_bytes=$(cat /sys/class/net/$NETWORK_INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx_bytes=$(cat /sys/class/net/$NETWORK_INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)
        
        # Calculate speeds (KB/s)
        local rx_speed=$(( (rx_bytes - rx_bytes_old) / 1024 / REFRESH_INTERVAL ))
        local tx_speed=$(( (tx_bytes - tx_bytes_old) / 1024 / REFRESH_INTERVAL ))
        
        # Update max speeds
        [ $rx_speed -gt $max_rx_speed ] && max_rx_speed=$rx_speed
        [ $tx_speed -gt $max_tx_speed ] && max_tx_speed=$tx_speed
        
        # Clear and redraw
        clear
        print_header "📈 REAL-TIME BANDWIDTH MONITOR (Interface: $NETWORK_INTERFACE)" "$PURPLE"
        echo -e "${GRAY}Press Ctrl+C to return to menu${NC}\n"
        
        # Display speeds
        printf "${WHITE}DOWNLOAD${NC} ${CYAN}▼${NC} %8d KB/s  ${WHITE}UPLOAD${NC} ${PURPLE}▲${NC} %8d KB/s\n" $rx_speed $tx_speed
        echo -e "${WHITE}MAX      ${NC} ${GRAY}▼${NC} %8d KB/s  ${GRAY}▲${NC} %8d KB/s\n" $max_rx_speed $max_tx_speed
        
        # Draw bandwidth bars
        local max_scale=1000
        local rx_bar=$((rx_speed * 50 / max_scale))
        local tx_bar=$((tx_speed * 50 / max_scale))
        
        echo -ne "${CYAN}RX:${NC} "
        for ((i=1; i<=rx_bar && i<=50; i++)); do echo -ne "${CYAN}█${NC}"; done
        echo -e " ${WHITE}$rx_speed KB/s${NC}"
        
        echo -ne "${PURPLE}TX:${NC} "
        for ((i=1; i<=tx_bar && i<=50; i++)); do echo -ne "${PURPLE}█${NC}"; done
        echo -e " ${WHITE}$tx_speed KB/s${NC}"
        
        # Update old values
        rx_bytes_old=$rx_bytes
        tx_bytes_old=$tx_bytes
        
        sleep $REFRESH_INTERVAL
    done
    
    # Reset trap
    trap - INT
}

# --- 4. VPS HEALTH DASHBOARD ---
health_dashboard() {
    while true; do
        clear
        print_header "🖥️  VPS HEALTH DASHBOARD (System Monitor)" "$GOLD"
        
        # Get system info
        local hostname=$(hostname)
        local uptime_info=$(uptime -p | sed 's/up //')
        local kernel=$(uname -r)
        local os=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)
        [ -z "$os" ] && os="Linux"
        
        # System Info
        echo -e "${WHITE}System Information:${NC}"
        echo -e "  ${GRAY}Hostname :${NC} ${CYAN}$hostname${NC}"
        echo -e "  ${GRAY}OS       :${NC} $os"
        echo -e "  ${GRAY}Kernel   :${NC} $kernel"
        echo -e "  ${GRAY}Uptime   :${NC} $uptime_info"
        
        # Get resource usage
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
        [ -z "$cpu_usage" ] && cpu_usage=0
        
        local ram_total=$(free -h | awk '/Mem:/ {print $2}')
        local ram_used=$(free -h | awk '/Mem:/ {print $3}')
        local ram_percent=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
        
        local disk_total=$(df -h / | awk 'NR==2 {print $2}')
        local disk_used=$(df -h / | awk 'NR==2 {print $3}')
        local disk_percent=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
        
        local load_1min=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
        local load_5min=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f2 | xargs)
        local load_15min=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f3 | xargs)
        
        echo -e "\n${WHITE}Resource Usage:${NC}"
        
        # CPU
        echo -ne "  ${GRAY}CPU    :${NC} "
        draw_bar $cpu_usage $([ $cpu_usage -lt 50 ] && echo "$GREEN" || [ $cpu_usage -lt 80 ] && echo "$GOLD" || echo "$RED")
        echo -e ""
        
        # RAM
        echo -ne "  ${GRAY}RAM    :${NC} "
        draw_bar $ram_percent $([ $ram_percent -lt 50 ] && echo "$GREEN" || [ $ram_percent -lt 80 ] && echo "$GOLD" || echo "$RED")
        echo -e " ${WHITE}($ram_used / $ram_total)${NC}"
        
        # Disk
        echo -ne "  ${GRAY}DISK   :${NC} "
        draw_bar $disk_percent $([ $disk_percent -lt 50 ] && echo "$GREEN" || [ $disk_percent -lt 80 ] && echo "$GOLD" || echo "$RED")
        echo -e " ${WHITE}($disk_used / $disk_total)${NC}"
        
        # Load Average
        echo -e "\n${WHITE}Load Average:${NC}"
        echo -e "  ${GRAY}1min :${NC} ${CYAN}$load_1min${NC}   ${GRAY}5min :${NC} ${PURPLE}$load_5min${NC}   ${GRAY}15min:${NC} ${GOLD}$load_15min${NC}"
        
        # Network Info
        local ip_addr=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7}' | head -n1)
        [ -z "$ip_addr" ] && ip_addr="Unknown"
        
        echo -e "\n${WHITE}Network:${NC}"
        echo -e "  ${GRAY}Interface :${NC} $NETWORK_INTERFACE"
        echo -e "  ${GRAY}IP Address:${NC} $ip_addr"
        
        # Top processes
        echo -e "\n${WHITE}Top CPU Processes:${NC}"
        echo -e "  ${GRAY}PID   %CPU  COMMAND${NC}"
        ps aux --sort=-%cpu | head -4 | tail -3 | awk '{printf "  %-6s %-5s %s\n", $2, $3, $11}'
        
        echo -e "\n${GRAY}Options: [R]efresh | [D]etailed View | [M]ain Menu${NC}"
        echo -ne "${CYAN}λ${NC} ${WHITE}Choice:${NC} "
        read -n1 opt
        echo ""
        
        case $opt in
            [Rr]) continue ;;
            [Dd])
                echo -e "\n${WHITE}Detailed System Info:${NC}"
                echo -e "  ${GRAY}Memory Details:${NC}"
                free -h | awk 'NR==1{printf "  %-8s %-8s %-8s %-8s\n", $1, $2, $3, $4} NR==2{printf "  %-8s %-8s %-8s %-8s\n", $1, $2, $3, $4}'
                echo -e "\n  ${GRAY}Disk Usage:${NC}"
                df -h | grep '^/dev/' | awk '{printf "  %-15s %-8s %-8s %-8s %s\n", $1, $2, $3, $4, $5}'
                print_footer
                ;;
            [Mm]) return ;;
        esac
    done
}

# --- SHOW NETWORK INFO SUMMARY ---
show_network_summary() {
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🌐 NETWORK OPERATIONS CENTER${NC} ${GRAY}v8.0${NC}${PURPLE}${NC}"
    echo -e "${PURPLE}├──────────────────────────────────────────────────────────────┤${NC}"
    
    # Get network stats
    local ip_addr=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7}' | head -n1)
    [ -z "$ip_addr" ] && ip_addr="Unknown"
    
    local rx_bytes=$(cat /sys/class/net/$NETWORK_INTERFACE/statistics/rx_bytes 2>/dev/null | numfmt --to=iec)
    local tx_bytes=$(cat /sys/class/net/$NETWORK_INTERFACE/statistics/tx_bytes 2>/dev/null | numfmt --to=iec)
    
    printf "${PURPLE}│${NC}  ${WHITE}%-15s${NC} : ${GREEN}%-30s${NC} ${PURPLE}│${NC}\n" "Interface" "$NETWORK_INTERFACE"
    printf "${PURPLE}│${NC}  ${WHITE}%-15s${NC} : ${CYAN}%-30s${NC} ${PURPLE}│${NC}\n" "IP Address" "$ip_addr"
    printf "${PURPLE}│${NC}  ${WHITE}%-15s${NC} : ${PURPLE}%-10s${NC} ${WHITE}TX:${NC} ${GOLD}%-15s${NC} ${PURPLE}│${NC}\n" "Traffic" "$rx_bytes" "$tx_bytes"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# --- MAIN NETWORK MENU ---
while true; do
    clear
    
    # Show header with network summary
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}███████╗███████╗███╗   ███╗ █████╗     ${WHITE}███╗   ██╗███████╗████████╗${NC}  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}██╔════╝██╔════╝████╗ ████║██╔══██╗    ${WHITE}████╗  ██║██╔════╝╚══██╔══╝${NC}  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}███████╗█████╗  ██╔████╔██║███████║    ${WHITE}██╔██╗ ██║█████╗     ██║   ${NC}  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}╚════██║██╔══╝  ██║╚██╔╝██║██╔══██║    ${WHITE}██║╚██╗██║██╔══╝     ██║   ${NC}  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}███████║███████╗██║ ╚═╝ ██║██║  ██║    ${WHITE}██║ ╚████║███████╗   ██║   ${NC}  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}╚══════╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝    ${WHITE}╚═╝  ╚═══╝╚══════╝   ╚═╝   ${NC}  ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  ${GRAY}NETWORK OPERATIONS CENTER${NC}                          ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    
    # Show network summary
    local ip_addr=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7}' | head -n1)
    [ -z "$ip_addr" ] && ip_addr="Not connected"
    
    printf "${PURPLE}║${NC}  ${WHITE}%-12s${NC} : ${GREEN}%-20s${NC}  ${WHITE}%-12s${NC} : ${CYAN}%-20s${NC} ${PURPLE}║${NC}\n" "Interface" "$NETWORK_INTERFACE" "IP Address" "$ip_addr"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    
    # Menu options
    echo -e "${PURPLE}║${NC}  ${PURPLE}[1]${NC} ${WHITE}📊 Packet Loss Monitor${NC}     ${GRAY}Test connection quality${NC}        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${PURPLE}[2]${NC} ${WHITE}🚦 Traffic Shaping${NC}          ${GRAY}Limit bandwidth usage${NC}          ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${PURPLE}[3]${NC} ${WHITE}📈 Live Bandwidth Graph${NC}     ${GRAY}Real-time traffic monitor${NC}      ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${PURPLE}[4]${NC} ${WHITE}🖥️  VPS Health Dashboard${NC}    ${GRAY}System resource monitor${NC}        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${PURPLE}[5]${NC} ${WHITE}🔄 Network Info${NC}             ${GRAY}Show detailed network info${NC}     ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${PURPLE}[0]${NC} ${GRAY}◀ Exit to Master Menu${NC}                                          ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -ne "${CYAN}λ${NC} ${WHITE}Network Command:${NC} "
    read main
    
    case $main in
        1) packet_loss_monitor ;;
        2) traffic_shaper ;;
        3) bandwidth_graph ;;
        4) health_dashboard ;;
        5) 
            clear
            print_header "🌐 NETWORK INTERFACE DETAILS" "$CYAN"
            echo -e "${WHITE}Interface:${NC} $NETWORK_INTERFACE"
            echo -e "${WHITE}IP Address:${NC} $(ip addr show $NETWORK_INTERFACE 2>/dev/null | grep 'inet ' | awk '{print $2}')"
            echo -e "\n${WHITE}Routing Table:${NC}"
            ip route show
            echo -e "\n${WHITE}Interface Statistics:${NC}"
            ip -s link show $NETWORK_INTERFACE
            print_footer
            ;;
        0) 
            echo -e "${GREEN}Returning to Master Menu...${NC}"
            sleep 1
            exit 0 
            ;;
        *) 
            echo -e "${RED}Invalid option!${NC}"
            sleep 1
            ;;
    esac
done
