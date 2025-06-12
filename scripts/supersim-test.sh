#!/bin/bash
# filepath: /home/envin/Work/substance_labs/op-intents-framework/scripts/supersim-test.sh

set -e # Exit on error

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   Optimism7683 E2E Test with SuperSim   ${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check if required tools are installed
if ! command -v supersim &> /dev/null; then
    echo -e "${RED}Error: supersim is not installed.${NC}"
    echo "Please install it from: https://github.com/ethereum-optimism/superchain-registry/tree/main/superchain-sim"
    exit 1
fi

# Check if jq is installed (needed for JSON parsing later)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    echo "Please install it with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
    exit 1
fi

echo -e "\n${YELLOW}1. Checking for SuperSim...${NC}"
# Check if SuperSim is already running
SUPERSIM_RUNNING=$(ps aux | grep "supersim --interop.autorelay" | grep -v grep | wc -l)
if [ "$SUPERSIM_RUNNING" -gt 0 ]; then
    echo -e "${BLUE}SuperSim is already running.${NC}"
    SUPERSIM_PID=$(ps aux | grep "supersim --interop.autorelay" | grep -v grep | awk '{print $2}')
    echo -e "Using existing SuperSim with PID: ${GREEN}$SUPERSIM_PID${NC}"
else
    echo -e "${BLUE}Starting SuperSim...${NC}"
    supersim --interop.autorelay &
    SUPERSIM_PID=$!
    echo -e "SuperSim started with PID: ${GREEN}$SUPERSIM_PID${NC}"
    echo -e "${YELLOW}Waiting for chains to start...${NC}"
    sleep 5  # Wait for chains to start properly
fi

echo -e "Checking if SuperSim is running..."
# Check if services are running by testing RPC endpoints
if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:9545 > /dev/null; then
  echo -e "${GREEN}SuperSim L2 chains are running!${NC}"
else
  echo -e "${RED}Error: SuperSim L2 chains are not responding. Make sure supersim is running properly.${NC}"
  echo -e "Try running 'supersim --interop.autorelay' manually to see any errors."
  exit 1
fi

# Define chain variables
OPCHAINA_RPC="http://127.0.0.1:9545"
OPCHAINB_RPC="http://127.0.0.1:9546"
OPCHAINA_CHAINID=901
OPCHAINB_CHAINID=902

echo -e "\n${YELLOW}2. Preparing environment variables...${NC}"
# Default hardhat accounts with 10000 ETH
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
USER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
PERMIT2_ADDRESS="0x000000000022D473030F116dDEE9F6B43aC78BA3" # Standard canonical address
CREATEX_ADDRESS="0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed"

# Create .env file for deployment
cat > .env <<EOL
DEPLOYER_PK=$PRIVATE_KEY
ROUTER_OWNER=$USER_ADDRESS
PERMIT2=$PERMIT2_ADDRESS
OPTIMISM7683_SALT=0x1234567890123456789012345678901234567890123456789012345678901234
CREATEX_ADDRESS=$CREATEX_ADDRESS
EOL

echo -e "\n${YELLOW}3. Deploying Optimism7683 contracts on both chains...${NC}"
cd solidity

# Deploy to opchaina
echo -e "${BLUE}Deploying to opchaina...${NC}"
LOCAL_CHAIN_ID=$OPCHAINA_CHAINID forge script script/DeployOptimism7683.s.sol:DeployOptimism7683 --broadcast --rpc-url $OPCHAINA_RPC --private-key $PRIVATE_KEY -vvv > cast-run-latest.txt 2>&1 || echo -e "${RED}Deployment to opchaina failed${NC}"

# Deploy to opchainb
echo -e "${BLUE}Deploying to opchainb...${NC}"
LOCAL_CHAIN_ID=$OPCHAINB_CHAINID forge script script/DeployOptimism7683.s.sol:DeployOptimism7683 --broadcast --rpc-url $OPCHAINB_RPC --private-key $PRIVATE_KEY -vvv > cast-run-latest2.txt 2>&1 || echo -e "${RED}Deployment to opchainb failed${NC}"

# Extract deployed contract addresses
echo -e "${BLUE}Extracting contract addresses...${NC}"
# Capture output of the first deployment
DEPLOY_OUTPUT_A=$(grep -A 2 "Router Proxy" cast-run-latest.txt 2>/dev/null || echo "")
CONTRACT_A=$(echo "$DEPLOY_OUTPUT_A" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1 || echo "")

# Capture output of the second deployment 
DEPLOY_OUTPUT_B=$(grep -A 2 "Router Proxy" cast-run-latest2.txt 2>/dev/null || echo "")
CONTRACT_B=$(echo "$DEPLOY_OUTPUT_B" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1 || echo "")

if [ -z "$CONTRACT_A" ] || [ -z "$CONTRACT_B" ]; then
    echo -e "${YELLOW}Trying alternative extraction method...${NC}"
    # Alternative extraction from broadcast outputs
    CONTRACT_A=$(find broadcast -type f -name run-latest.json -exec grep -l "Router Proxy" {} \; | xargs cat 2>/dev/null | grep -A 2 "Router Proxy" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1 || echo "")
    CONTRACT_B=$(find broadcast -type f -name run-latest.json -exec grep -l "Router Proxy" {} \; | xargs cat 2>/dev/null | grep -A 2 "Router Proxy" | grep -o '0x[a-fA-F0-9]\{40\}' | head -2 | tail -1 || echo "")
fi

if [ -z "$CONTRACT_A" ] || [ -z "$CONTRACT_B" ]; then
    echo -e "${RED}Failed to extract contract addresses from deployment logs${NC}"
    echo -e "${YELLOW}Falling back to manual address extraction...${NC}"
    echo "Please enter the address of Optimism7683 deployed on opchaina:"
    read CONTRACT_A
    echo "Please enter the address of Optimism7683 deployed on opchainb:"
    read CONTRACT_B
fi

echo -e "Optimism7683 deployed on opchaina: ${GREEN}$CONTRACT_A${NC}"
echo -e "Optimism7683 deployed on opchainb: ${GREEN}$CONTRACT_B${NC}"

echo -e "\n${YELLOW}4. Configuring cross-chain destinations...${NC}"
# Set each contract as the destination of the other chain
echo -e "${BLUE}Setting destination contracts...${NC}"

# Set CONTRACT_B as destination for opchainb on the opchaina contract
cast send $CONTRACT_A "setDestinationContract(uint256,address)" $OPCHAINB_CHAINID $CONTRACT_B --rpc-url $OPCHAINA_RPC --private-key $PRIVATE_KEY

# Set CONTRACT_A as destination for opchaina on the opchainb contract
cast send $CONTRACT_B "setDestinationContract(uint256,address)" $OPCHAINA_CHAINID $CONTRACT_A --rpc-url $OPCHAINB_RPC --private-key $PRIVATE_KEY

echo -e "\n${YELLOW}5. Deploying test ERC20 token on both chains...${NC}"
# Create a simple ERC20 token contract

echo -e "${BLUE}Deploying token to opchaina...${NC}"
forge script script/DeployToken.s.sol:DeployToken --broadcast --rpc-url $OPCHAINA_RPC --private-key $PRIVATE_KEY -vvv > token-deploy-a.txt 2>&1 || echo -e "${RED}Deployment to opchaina failed${NC}"

echo -e "${BLUE}Deploying token to opchainb...${NC}"
forge script script/DeployToken.s.sol:DeployToken --broadcast --rpc-url $OPCHAINB_RPC --private-key $PRIVATE_KEY -vvv > token-deploy-b.txt 2>&1 || echo -e "${RED}Deployment to opchaina failed${NC}"

TOKEN_DEPLOY_OUTPUT_A=$(grep -A 2 "ITT" token-deploy-a.txt 2>/dev/null || echo "")
TOKEN_A=$(echo "$TOKEN_DEPLOY_OUTPUT_A" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1 || echo "")

# Capture output of the second deployment 
TOKEN_DEPLOY_OUTPUT_B=$(grep -A 2 "ITT" token-deploy-b.txt 2>/dev/null || echo "")
TOKEN_B=$(echo "$TOKEN_DEPLOY_OUTPUT_B" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1 || echo "")

echo -e "TestToken deployed on opchaina: ${GREEN}$TOKEN_A${NC}"
echo -e "TestToken deployed on opchainb: ${GREEN}$TOKEN_B${NC}"

cd ..

echo -e "\n${YELLOW}6. Updating solver configuration...${NC}"
# Create environment file for the solver
cat > typescript/solver/.env <<EOL
PRIVATE_KEY=$PRIVATE_KEY
OPTIMISM7683_CONTRACT_ADDRESS=$CONTRACT_A,$CONTRACT_B
EOL


echo -e "\n${YELLOW}7. Building and starting the solver...${NC}"
cd typescript/solver
yarn build

echo -e "${BLUE}Starting solver in background...${NC}"
LOG_LEVEL=info nohup yarn solver > solver.log 2>&1 &
SOLVER_PID=$!
echo -e "Solver started with PID: ${GREEN}$SOLVER_PID${NC}"
cd ../..

echo -e "\n${GREEN}============== SETUP COMPLETE ==============${NC}"
echo -e "Optimism7683 deployed on:"
echo -e "  opchaina: ${GREEN}$CONTRACT_A${NC}"
echo -e "  opchainb: ${GREEN}$CONTRACT_B${NC}"
echo -e "\nTest tokens deployed on:"
echo -e "  opchaina: ${GREEN}$TOKEN_A${NC}"
echo -e "  opchainb: ${GREEN}$TOKEN_B${NC}"
echo -e "\nSolver running with PID: ${GREEN}$SOLVER_PID${NC}"

echo -e "\n${BLUE}What's next?${NC}"
echo -e "1. Open orders using the solidity scripts:"
echo -e "   ${GREEN}forge script script/OpenOrder.s.sol:OpenOrder --rpc-url $OPCHAINA_RPC${NC} - Open order from opchaina to opchainb"
echo -e "   ${GREEN}forge script script/OpenOrder.s.sol:OpenOrder --rpc-url $OPCHAINB_RPC${NC} - Open order from opchainb to opchaina"
echo -e "\n2. Check solver status and logs on:"
echo -e "   ${GREEN}typescript/solver/solver.log${NC}"
echo -e "\n3. When done testing, clean up with:"
echo -e "   ${GREEN}kill $SOLVER_PID && kill $SUPERSIM_PID${NC}"