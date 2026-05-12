#!/bin/bash
# alka-run — Compile and execute an Alka Recipe
#
# Usage:
#   ./alka-run <recipe.alka> <vial.alkavl> [--safe] [--dry-run]
#
# This script:
#   1. Compiles the Recipe with the Alka compiler
#   2. Loads the Athanor kernel module (if not loaded)
#   3. Executes the binary via /dev/vitriol
#   4. Reports results

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALKAC="${SCRIPT_DIR}/zig-out/bin/alka"
MODULE="${SCRIPT_DIR}/src/athanor/vitriol_alka.ko"
DEVICE="/dev/vitriol"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <recipe.alka> <vial.alkavl> [--safe] [--mock] [--dry-run]"
    echo ""
    echo "Options:"
    echo "  --safe      Execute with Azoth rollback on failure"
    echo "  --mock      Simulate execution in userspace (no kernel/hardware)"
    echo "  --dry-run   Compile only, do not execute"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

RECIPE="$1"
VIAL="$2"
shift 2

SAFE_MODE=false
DRY_RUN=false
MOCK_MODE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --safe) SAFE_MODE=true ;;
        --mock) MOCK_MODE=true ;;
        --dry-run) DRY_RUN=true ;;
        *) usage ;;
    esac
    shift
done

# Check compiler exists
if [ ! -x "$ALKAC" ]; then
    echo -e "${YELLOW}Building Alka compiler...${NC}"
    make -C "$SCRIPT_DIR" build
fi

# Step 1: Compile
echo -e "${GREEN}=== Step 1: Compile ===${NC}"
echo "Compiling: $RECIPE + $VIAL"

$ALKAC "$RECIPE" "$VIAL"

ALKAS="${RECIPE}.alkas"
AZOTH="${RECIPE}.azoth"

if [ ! -f "$ALKAS" ]; then
    echo -e "${RED}Error: Compilation failed — no .alkas output${NC}"
    exit 1
fi

echo -e "${GREEN}Compiled: $ALKAS ($(stat -c%s "$ALKAS") bytes)${NC}"
if [ -f "$AZOTH" ]; then
    echo -e "${GREEN}Rollback: $AZOTH ($(stat -c%s "$AZOTH") bytes)${NC}"
fi

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry run — skipping execution${NC}"
    exit 0
fi

if [ "$MOCK_MODE" = true ]; then
    echo -e "${GREEN}=== Step 2: Mock Execution ===${NC}"
    echo "Simulating execution in userspace (no kernel/hardware needed)..."
    $ALKAC --mock "$ALKAS"
    echo -e "${GREEN}=== Complete ===${NC}"
    exit 0
fi

# Step 2: Load kernel module
echo -e "${GREEN}=== Step 2: Kernel Module ===${NC}"

if [ ! -e "$DEVICE" ]; then
    echo "Loading Athanor kernel module..."
    if [ ! -f "$MODULE" ]; then
        echo -e "${YELLOW}Building kernel module...${NC}"
        make -C "${SCRIPT_DIR}/src/athanor" all
    fi
    sudo insmod "$MODULE"
    sleep 1
    dmesg | tail -5
fi

echo -e "${GREEN}/dev/vitriol ready${NC}"

# Step 3: Execute
echo -e "${GREEN}=== Step 3: Execute ===${NC}"

if [ "$SAFE_MODE" = true ] && [ -f "$AZOTH" ]; then
    echo "Safe execution with Azoth rollback..."
    $ALKAC --safe "$ALKAS" "$AZOTH"
else
    echo "Executing..."
    $ALKAC --execute "$ALKAS"
fi

echo -e "${GREEN}=== Complete ===${NC}"
