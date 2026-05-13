#!/bin/bash

# Intelligent caffeinate wrapper for Xcode builds and tests
# Prevents sleep during builds/tests while protecting battery life

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_TIMEOUT=7200  # 2 hours max
MODE="build"
SCHEME="FIN1"
PROJECT="FIN1.xcodeproj"
DESTINATION="${IOS_SIM_DEST:-platform=iOS Simulator,name=iPhone 16,OS=18.6}"
SDK="iphonesimulator"
CONFIGURATION="Debug"

# Help function
show_help() {
    cat << EOF
${BLUE}Intelligent Caffeinate Wrapper for Xcode Builds/Tests${NC}

${GREEN}Usage:${NC}
    $0 [OPTIONS] [COMMAND]

${GREEN}Options:${NC}
    -m, --mode MODE          Mode: build, test, clean, archive (default: build)
    -s, --scheme SCHEME      Scheme name (default: FIN1)
    -p, --project PROJECT    Project file (default: FIN1.xcodeproj)
    -d, --destination DEST   Destination (default: iPhone 16 OS=18.6; override IOS_SIM_DEST)
    -k, --sdk SDK            SDK (default: iphonesimulator)
    -c, --config CONFIG      Configuration (default: Debug)
    -t, --timeout SECONDS    Max timeout in seconds (default: 7200 = 2h)
    -n, --no-caffeinate      Don't use caffeinate (run normally)
    -h, --help               Show this help

${GREEN}Examples:${NC}
    # Build with caffeinate (2h max timeout)
    $0 --mode build

    # Test with caffeinate (1h max timeout)
    $0 --mode test --timeout 3600

    # Build without caffeinate
    $0 --mode build --no-caffeinate

    # Custom build command
    $0 --mode build --scheme MyApp --project MyApp.xcodeproj

${GREEN}Modes:${NC}
    build     - Build the project
    test      - Run tests
    clean     - Clean build folder
    archive   - Create archive (Release config)

${YELLOW}Note:${NC} Caffeinate prevents sleep during execution. Use with caution on battery!
EOF
}

# Parse arguments
USE_CAFFEINATE=true
TIMEOUT=$DEFAULT_TIMEOUT

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -s|--scheme)
            SCHEME="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT="$2"
            shift 2
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -k|--sdk)
            SDK="$2"
            shift 2
            ;;
        -c|--config)
            CONFIGURATION="$2"
            shift 2
            ;;
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
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate timeout
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -lt 60 ]; then
    echo -e "${RED}Error: Timeout must be at least 60 seconds${NC}"
    exit 1
fi

if [ "$TIMEOUT" -gt 14400 ]; then
    echo -e "${YELLOW}Warning: Timeout > 4 hours. Consider using pmset instead.${NC}"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if project exists (xcodeproj is a directory, not a file)
if [ ! -d "$PROJECT" ] && [ ! -f "$PROJECT" ]; then
    echo -e "${RED}Error: Project file not found: $PROJECT${NC}"
    exit 1
fi

# Build xcodebuild command based on mode
build_xcodebuild_command() {
    local cmd="xcodebuild"

    case $MODE in
        build)
            cmd="$cmd -project $PROJECT -scheme $SCHEME -sdk $SDK -configuration $CONFIGURATION -destination '$DESTINATION' build"
            ;;
        test)
            cmd="$cmd -project $PROJECT -scheme $SCHEME -sdk $SDK -destination '$DESTINATION' test"
            ;;
        clean)
            cmd="$cmd -project $PROJECT -scheme $SCHEME clean"
            ;;
        archive)
            cmd="$cmd -project $PROJECT -scheme $SCHEME -configuration Release archive -archivePath ./build/FIN1.xcarchive"
            ;;
        *)
            echo -e "${RED}Error: Unknown mode: $MODE${NC}"
            echo "Valid modes: build, test, clean, archive"
            exit 1
            ;;
    esac

    echo "$cmd"
}

# Get xcodebuild command
XCODEBUILD_CMD=$(build_xcodebuild_command)

# Show configuration
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Intelligent Caffeinate Wrapper for Xcode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Mode:        $MODE"
echo "  Scheme:      $SCHEME"
echo "  Project:     $PROJECT"
echo "  SDK:         $SDK"
echo "  Config:      $CONFIGURATION"
if [ "$MODE" != "clean" ]; then
    echo "  Destination: $DESTINATION"
fi
echo "  Caffeinate:  $USE_CAFFEINATE"
if [ "$USE_CAFFEINATE" = true ]; then
    echo "  Timeout:     $TIMEOUT seconds ($(($TIMEOUT / 60)) minutes)"
fi
echo ""
echo -e "${GREEN}Command:${NC}"
if [ "$USE_CAFFEINATE" = true ]; then
    echo "  caffeinate -t $TIMEOUT -i $XCODEBUILD_CMD"
else
    echo "  $XCODEBUILD_CMD"
fi
echo ""

# Check battery status if using caffeinate
if [ "$USE_CAFFEINATE" = true ]; then
    BATTERY_STATUS=$(pmset -g batt | grep -o "[0-9]*%" | head -1 | sed 's/%//')
    if [ -n "$BATTERY_STATUS" ] && [ "$BATTERY_STATUS" -lt 20 ]; then
        echo -e "${YELLOW}⚠️  Warning: Battery is low ($BATTERY_STATUS%)${NC}"
        echo -e "${YELLOW}   Consider plugging in your Mac or using --no-caffeinate${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Execute command
echo -e "${BLUE}Starting execution...${NC}"
echo ""

START_TIME=$(date +%s)

if [ "$USE_CAFFEINATE" = true ]; then
    # Use caffeinate with timeout
    # -i: Prevent idle sleep (system sleep)
    # -d: Allow display sleep (saves some battery)
    # -t: Timeout in seconds
    if caffeinate -t "$TIMEOUT" -i -d bash -c "$XCODEBUILD_CMD"; then
        EXIT_CODE=0
    else
        EXIT_CODE=$?
    fi
else
    # Run without caffeinate
    if bash -c "$XCODEBUILD_CMD"; then
        EXIT_CODE=0
    else
        EXIT_CODE=$?
    fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Success!${NC}"
else
    echo -e "${RED}❌ Failed with exit code: $EXIT_CODE${NC}"
fi
echo "  Duration: ${MINUTES}m ${SECONDS}s"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

exit $EXIT_CODE
