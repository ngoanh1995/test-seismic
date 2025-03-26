#!/bin/bash
echo "Script deploy Counter Seismic contract on devnet in Gitpod"

# Bật debug để in từng lệnh
set -x
# Dừng script nếu có lỗi
set -e
set -o pipefail
set -u

# Xử lý lỗi
handle_error() {
    echo "Error: Script failed at line $1"
    exit 1
}
trap 'handle_error $LINENO' ERR

# Chuyển đến thư mục home
cd ~

echo "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y curl git build-essential jq

# Cài Rust nếu chưa có
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    export PATH="$HOME/.cargo/bin:$PATH"
else
    echo "Rust is already installed."
fi
rustc --version

# Cài sfoundryup
echo "Installing sfoundryup..."
curl -L -H "Accept: application/vnd.github.v3.raw" \
     "https://api.github.com/repos/SeismicSystems/seismic-foundry/contents/sfoundryup/install?ref=seismic" | bash
export PATH="$HOME/.seismic/bin:$PATH"
sfoundryup

# Clone hoặc cập nhật repository try-devnet
if [ ! -d "try-devnet" ]; then
    echo "Cloning try-devnet repository..."
    git clone --recurse-submodules https://github.com/SeismicSystems/try-devnet.git
else
    echo "try-devnet repository exists. Updating..."
    cd try-devnet
    git pull
    git submodule update --init --recursive
    cd ..
fi

# Triển khai hợp đồng
echo "Deploying contract..."
cd try-devnet/packages/contract/ || { echo "Contract directory not found!"; exit 1; }
bash script/deploy.sh

# Cài CLI với Bun
echo "Setting up CLI with Bun..."
cd ~/try-devnet/packages/cli/ || { echo "CLI directory not found!"; exit 1; }
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"
bun install

# Chạy giao dịch
echo "Running transaction script..."
bash script/transact.sh

echo "Deployment and transaction completed successfully!"
