#!/bin/bash

# Intelligent caffeinate wrapper for development servers
# Keeps Mac awake during server execution while allowing display sleep

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_TIMEOUT=14400  # 4 hours max
SERVER_CMD=""
USE_CAFFEINATE=true

# Help function
show_help() {
    cat << EOF
${BLUE}Intelligent Caffeinate Wrapper for Development Servers${NC}

${GREEN}Usage:${NC}
    $0 [OPTIONS] -- [SERVER_COMMAND]

${GREEN}Options:${NC}
    -t, --timeout SECONDS    Max timeout in seconds (default: 14400 = 4h)
    -n, --no-caffeinate      Don't use caffeinate (run normally)
    -h, --help               Show this help

${GREEN}Examples:${NC}
    # Start npm server with caffeinate
    $0 -- npm start

    # Start Parse server with caffeinate (2h max)
    $0 --timeout 7200 -- npm run parse-server

    # Start server without caffeinate
    $0 --no-caffeinate -- npm start

    # Start backend services
    $0 -- docker-compose up

${GREEN}What it does:${NC}
    - Prevents system sleep (keeps WLAN connected) ✅
    - Allows display sleep (saves battery) ✅
    - Auto-stops after timeout (protects battery) ✅
    - Stops when server stops (automatic cleanup) ✅

${YELLOW}Note:${NC}
    - Display can sleep (saves battery)
    - System stays awake (WLAN stays connected)
    - Server continues running even when display is off
EOF
}

# Parse arguments
TIMEOUT=$DEFAULT_TIMEOUT
SERVER_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -n|--no-caffeinate)
            USE_CAFFEINATE=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            SERVER_ARGS=("$@")
            break
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use -- to separate options from server command"
            show_help
            exit 1
            ;;
    esac
done

# Check if server command provided
if [ ${#SERVER_ARGS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No server command provided${NC}"
    echo "Usage: $0 [OPTIONS] -- [SERVER_COMMAND]"
    echo "Example: $0 -- npm start"
    exit 1
fi

SERVER_CMD="${SERVER_ARGS[*]}"

# Validate timeout
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -lt 300 ]; then
    echo -e "${RED}Error: Timeout must be at least 300 seconds (5 minutes)${NC}"
    exit 1
fi

if [ "$TIMEOUT" -gt 28800 ]; then
    echo -e "${YELLOW}Warning: Timeout > 8 hours. Consider using pmset instead.${NC}"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Show configuration
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Intelligent Caffeinate Wrapper for Servers${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Server:      $SERVER_CMD"
echo "  Caffeinate:  $USE_CAFFEINATE"
if [ "$USE_CAFFEINATE" = true ]; then
    echo "  Timeout:     $TIMEOUT seconds ($(($TIMEOUT / 3600))h $(($TIMEOUT % 3600 / 60))m)"
    echo "  Display:     Can sleep (saves battery)"
    echo "  System:      Stays awake (WLAN connected)"
fi
echo ""
echo -e "${GREEN}Command:${NC}"
if [ "$USE_CAFFEINATE" = true ]; then
    echo "  caffeinate -t $TIMEOUT -i -d $SERVER_CMD"
else
    echo "  $SERVER_CMD"
fi
echo ""

# Check battery status if using caffeinate
if [ "$USE_CAFFEINATE" = true ]; then
    BATTERY_STATUS=$(pmset -g batt | grep -o "[0-9]*%" | head -1 | sed 's/%//')
    POWER_SOURCE=$(pmset -g batt | grep -o "AC Power\|Battery Power" | head -1)

    if [ "$POWER_SOURCE" = "Battery Power" ]; then
        if [ -n "$BATTERY_STATUS" ] && [ "$BATTERY_STATUS" -lt 30 ]; then
            echo -e "${YELLOW}⚠️  Warning: Running on battery ($BATTERY_STATUS%)${NC}"
            echo -e "${YELLOW}   Consider plugging in your Mac for long-running servers${NC}"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            echo -e "${YELLOW}ℹ️  Running on battery. Display can sleep to save battery.${NC}"
        fi
    else
        echo -e "${GREEN}✅ Running on AC power. Full performance available.${NC}"
    fi
fi

# Setup signal handlers for clean exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping server...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    echo -e "${GREEN}Server stopped.${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Execute command
echo -e "${BLUE}Starting server...${NC}"
echo ""

START_TIME=$(date +%s)

if [ "$USE_CAFFEINATE" = true ]; then
    # Use caffeinate with timeout
    # -i: Prevent idle sleep (system sleep) → WLAN stays connected ✅
    # -d: Allow display sleep → Saves battery ✅
    # -t: Timeout in seconds → Auto-stop after timeout ✅
    caffeinate -t "$TIMEOUT" -i -d bash -c "$SERVER_CMD" &
    SERVER_PID=$!

    # Wait for server
    wait $SERVER_PID
    EXIT_CODE=$?
else
    # Run without caffeinate
    bash -c "$SERVER_CMD" &
    SERVER_PID=$!

    # Wait for server
    wait $SERVER_PID
    EXIT_CODE=$?
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
HOURS=$((DURATION / 3600))
MINUTES=$((DURATION % 3600 / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Server stopped successfully${NC}"
else
    echo -e "${RED}❌ Server stopped with exit code: $EXIT_CODE${NC}"
fi
echo "  Duration: ${HOURS}h ${MINUTES}m ${SECONDS}s"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

exit $EXIT_CODE
