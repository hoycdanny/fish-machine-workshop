#!/bin/bash

# 魚機遊戲 EKS Workshop - EC2 User Data 自動設定腳本
# 此腳本可直接複製到 EC2 User Data 中，實例啟動時會自動執行所有設定
# 注意：此腳本需要 root 權限執行

set -e

# 檢查是否為 root 用戶
if [[ $EUID -ne 0 ]]; then
    echo "此腳本需要 root 權限執行"
    echo "請使用以下方式之一執行："
    echo "1. sudo bash $0"
    echo "2. 作為 EC2 User Data 執行（自動具有 root 權限）"
    exit 1
fi

# 設定日誌
exec > >(tee /var/log/workshop-setup.log)
exec 2>&1

echo "=========================================="
echo "魚機遊戲 EKS Workshop - 開始自動設定"
echo "時間: $(date)"
echo "=========================================="

# 顏色定義（在日誌中不會顯示顏色，但保留以便手動執行時使用）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日誌函數
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
}

# 配置變數
WORKSHOP_USER="ubuntu"
WORKSHOP_DIR="/home/$WORKSHOP_USER/workshop"
PROJECT_NAME="fish-game-eks-workshop"
VSCODE_PORT=8080
VSCODE_PASSWORD="password"

# 檢測作業系統
detect_os() {
    log_info "檢測作業系統..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
        log_info "檢測到作業系統: $OS_NAME $OS_VERSION"
        
        if [[ $OS_NAME == *"Ubuntu"* ]]; then
            PACKAGE_MANAGER="apt"
            INSTALL_CMD="apt-get install -y"
            UPDATE_CMD="apt-get update && apt-get upgrade -y"
        elif [[ $OS_NAME == *"Amazon Linux"* ]]; then
            PACKAGE_MANAGER="yum"
            INSTALL_CMD="yum install -y"
            UPDATE_CMD="yum update -y"
            WORKSHOP_USER="ec2-user"
            WORKSHOP_DIR="/home/$WORKSHOP_USER/workshop"
        else
            log_error "不支援的作業系統: $OS_NAME"
            exit 1
        fi
    else
        log_error "無法檢測作業系統"
        exit 1
    fi
}

# 更新系統
update_system() {
    log_info "更新系統套件..."
    
    if [[ $PACKAGE_MANAGER == "apt" ]]; then
        apt-get update
        apt-get upgrade -y
        $INSTALL_CMD curl wget unzip git vim htop tree jq net-tools telnet netcat-openbsd bash-completion
    else
        yum update -y
        $INSTALL_CMD curl wget unzip git vim htop tree jq net-tools telnet nc bash-completion
    fi
    
    log_info "系統套件更新完成"
}

# 建立工作用戶和目錄
setup_user_and_directories() {
    log_info "設定用戶和目錄..."
    
    # 確保工作用戶存在
    if ! id "$WORKSHOP_USER" &>/dev/null; then
        if [[ $PACKAGE_MANAGER == "apt" ]]; then
            useradd -m -s /bin/bash $WORKSHOP_USER
            usermod -aG sudo $WORKSHOP_USER
        else
            useradd -m -s /bin/bash $WORKSHOP_USER
            usermod -aG wheel $WORKSHOP_USER
        fi
        log_info "建立用戶: $WORKSHOP_USER"
    fi
    
    # 建立工作目錄
    mkdir -p $WORKSHOP_DIR
    mkdir -p $WORKSHOP_DIR/logs
    mkdir -p $WORKSHOP_DIR/scripts
    mkdir -p $WORKSHOP_DIR/configs
    
    # 設定目錄權限
    chown -R $WORKSHOP_USER:$WORKSHOP_USER $WORKSHOP_DIR
    
    log_info "工作目錄建立完成: $WORKSHOP_DIR"
}

# 安裝 Docker
install_docker() {
    log_info "安裝 Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker 已安裝，版本: $(docker --version)"
        return 0
    fi
    
    # 下載並執行 Docker 安裝腳本
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # 將用戶加入 docker 群組
    usermod -aG docker $WORKSHOP_USER
    
    # 啟動 Docker 服務
    systemctl enable docker
    systemctl start docker
    
    # 安裝 Docker Compose
    local latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_info "Docker 和 Docker Compose 安裝完成"
}

# 安裝 AWS CLI v2
install_aws_cli() {
    log_info "安裝 AWS CLI v2..."
    
    if command -v aws &> /dev/null; then
        local current_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
        if [[ $current_version == 2.* ]]; then
            log_info "AWS CLI v2 已安裝，版本: $current_version"
            return 0
        fi
    fi
    
    # 下載並安裝 AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install --update
    rm -rf awscliv2.zip aws/
    
    log_info "AWS CLI v2 安裝完成，版本: $(aws --version)"
}

# 安裝 kubectl
install_kubectl() {
    log_info "安裝 kubectl..."
    
    if command -v kubectl &> /dev/null; then
        log_info "kubectl 已安裝"
        return 0
    fi
    
    # 獲取最新穩定版本並安裝
    local latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${latest_version}/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_info "kubectl 安裝完成"
}

# 安裝 eksctl
install_eksctl() {
    log_info "安裝 eksctl..."
    
    if command -v eksctl &> /dev/null; then
        log_info "eksctl 已安裝"
        return 0
    fi
    
    # 下載並安裝 eksctl
    curl --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin
    
    log_info "eksctl 安裝完成"
}

# 安裝 Helm
install_helm() {
    log_info "安裝 Helm..."
    
    if command -v helm &> /dev/null; then
        log_info "Helm 已安裝"
        return 0
    fi
    
    # 下載並安裝 Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_info "Helm 安裝完成"
}

# 安裝 VS Code Server
install_vscode_server() {
    log_info "安裝 VS Code Server..."
    
    # 切換到工作用戶執行
    sudo -u $WORKSHOP_USER bash << 'EOF'
# 下載並安裝 code-server
curl -fsSL https://code-server.dev/install.sh | sh

# 建立配置目錄
mkdir -p ~/.config/code-server

# 建立配置檔案
cat > ~/.config/code-server/config.yaml << VSCODE_CONFIG
bind-addr: 0.0.0.0:8080
auth: password
password: password
cert: false
disable-telemetry: true
disable-update-check: true
VSCODE_CONFIG

EOF
    
    # 啟用並啟動 code-server 服務
    systemctl enable --now code-server@$WORKSHOP_USER
    
    log_info "VS Code Server 安裝完成"
}

# 設定防火牆
setup_firewall() {
    log_info "設定防火牆..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu 使用 ufw
        ufw --force enable
        ufw allow ssh
        ufw allow $VSCODE_PORT/tcp
        ufw allow 8080:8083/tcp
        log_info "UFW 防火牆設定完成"
    elif command -v firewall-cmd &> /dev/null; then
        # Amazon Linux 使用 firewalld
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-port=$VSCODE_PORT/tcp
        firewall-cmd --permanent --add-port=8080-8083/tcp
        firewall-cmd --reload
        log_info "Firewalld 防火牆設定完成"
    else
        log_warn "未檢測到防火牆服務，請確保 EC2 安全群組已正確配置"
    fi
}

# 下載專案程式碼
setup_project() {
    log_info "設定專案環境..."
    
    # 切換到工作用戶執行
    sudo -u $WORKSHOP_USER bash << EOF
cd $WORKSHOP_DIR

# Clone 專案倉庫
echo "正在下載專案程式碼..."
git clone https://github.com/hoycdanny/fish-machine-workshop.git $PROJECT_NAME
cd $PROJECT_NAME

EOF
    
    log_info "專案環境設定完成"
}

# 設定 bash 環境
setup_bash_environment() {
    log_info "設定 bash 環境..."
    
    # 為工作用戶設定 bash 環境
    sudo -u $WORKSHOP_USER bash << EOF
# 設定 AWS 預設區域
aws configure set region ap-northeast-2

# 設定 bash 自動完成和別名
cat >> ~/.bashrc << 'BASHRC'

# Workshop 環境變數
export WORKSHOP_DIR="$WORKSHOP_DIR"
export PROJECT_DIR="$WORKSHOP_DIR/$PROJECT_NAME"
export AWS_DEFAULT_REGION=ap-northeast-2

# Kubernetes 自動完成
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
    alias k=kubectl
    complete -F __start_kubectl k
fi

# eksctl 自動完成
if command -v eksctl &> /dev/null; then
    source <(eksctl completion bash)
fi

# Helm 自動完成
if command -v helm &> /dev/null; then
    source <(helm completion bash)
fi

# 實用別名
alias ll='ls -alF'
alias la='ls -A'
alias ..='cd ..'
alias grep='grep --color=auto'

# Docker 別名
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'

# Kubernetes 別名
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgi='kubectl get ingress'

# Workshop 別名
alias workshop='cd \$PROJECT_DIR'
alias wservices='cd \$PROJECT_DIR/services'
alias winfra='cd \$PROJECT_DIR/infrastructure'
alias wscripts='cd \$PROJECT_DIR/scripts'

BASHRC

EOF
    
    log_info "bash 環境設定完成"
}

# 安裝 VS Code 擴展
install_vscode_extensions() {
    log_info "安裝 VS Code 擴展..."
    
    # 等待 code-server 完全啟動
    sleep 10
    
    # 切換到工作用戶安裝擴展
    sudo -u $WORKSHOP_USER bash << 'EOF'
# 安裝常用擴展
extensions=(
    "ms-vscode.vscode-json"
    "redhat.vscode-yaml"
    "ms-kubernetes-tools.vscode-kubernetes-tools"
    "ms-vscode.vscode-docker"
    "ms-python.python"
)

for extension in "${extensions[@]}"; do
    echo "安裝擴展: $extension"
    code-server --install-extension "$extension" || echo "擴展 $extension 安裝失敗"
done
EOF
    
    log_info "VS Code 擴展安裝完成"
}

# 驗證安裝
verify_installation() {
    log_info "驗證安裝..."
    
    local failed=0
    
    # 檢查服務
    local services=("docker" "code-server@$WORKSHOP_USER")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service; then
            log_info "✓ 服務 $service 運行正常"
        else
            log_error "✗ 服務 $service 未運行"
            failed=1
        fi
    done
    
    # 檢查工具
    local tools=("docker" "docker-compose" "aws" "kubectl" "eksctl" "helm")
    for tool in "${tools[@]}"; do
        if command -v $tool &> /dev/null; then
            log_info "✓ 工具 $tool 已安裝"
        else
            log_error "✗ 工具 $tool 未安裝"
            failed=1
        fi
    done
    
    # 檢查端口
    if netstat -tlnp 2>/dev/null | grep -q ":$VSCODE_PORT "; then
        log_info "✓ VS Code Server 正在監聽端口 $VSCODE_PORT"
    else
        log_error "✗ VS Code Server 未監聽端口 $VSCODE_PORT"
        failed=1
    fi
    
    if [[ $failed -eq 0 ]]; then
        log_info "所有驗證通過"
    else
        log_error "部分驗證失敗"
    fi
}

# 顯示完成資訊
show_completion_info() {
    local public_ip=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_IP")
    
    log_info "=========================================="
    log_info "魚機遊戲 EKS Workshop 環境設定完成！"
    log_info "=========================================="
    log_info "VS Code Server 訪問資訊:"
    log_info "  URL: http://$public_ip:$VSCODE_PORT"
    log_info "  密碼: $VSCODE_PASSWORD"
    log_info ""
    log_info "專案位置: $WORKSHOP_DIR/$PROJECT_NAME"
    log_info ""
    log_info "已安裝工具:"
    log_info "  - Docker & Docker Compose"
    log_info "  - AWS CLI v2"
    log_info "  - kubectl"
    log_info "  - eksctl"
    log_info "  - Helm"
    log_info "  - VS Code Server"
    log_info ""
    log_info "故障排除:"
    log_info "  - 設定日誌: /var/log/workshop-setup.log"
    log_info "  - VS Code 日誌: sudo journalctl -u code-server@$WORKSHOP_USER -f"
    log_info "  - 重啟 VS Code: sudo systemctl restart code-server@$WORKSHOP_USER"
    log_info "=========================================="
}

# 主函數
main() {
    log_info "開始魚機遊戲 EKS Workshop 環境自動設定..."
    
    detect_os
    update_system
    setup_user_and_directories
    install_docker
    install_aws_cli
    install_kubectl
    install_eksctl
    install_helm
    install_vscode_server
    setup_firewall
    setup_project
    setup_bash_environment
    install_vscode_extensions
    verify_installation
    show_completion_info
    
    log_info "環境設定完成！請使用瀏覽器訪問 VS Code Server 開始 Workshop。"
}

# 執行主函數
main "$@"