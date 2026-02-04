#!/bin/bash
# build-and-push.sh - 構建並推送 Docker 鏡像到 ECR
# 支援多標籤策略，用於 DevOps Agent Demo

set -e

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 輸出函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_tag() {
    echo -e "${CYAN}[TAG]${NC} $1"
}

# 顯示標籤策略說明
show_tag_strategy() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🏷️  資源標籤策略 (AWS DevOps Agent)                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}專案標籤規範：${NC}"
    echo -e "  ${YELLOW}Project${NC}          - fish-machine-workshop"
    echo -e "  ${YELLOW}Workshop${NC}         - fish-machine-workshop"
    echo -e "  ${YELLOW}ManagedBy${NC}        - 1.service-verification-containerization/build-and-push.sh"
    echo ""
    echo -e "${GREEN}Docker 映像標籤類型：${NC}"
    echo -e "  ${YELLOW}latest${NC}           - 最新開發版本（預設）"
    echo -e "  ${YELLOW}v1.0.0, v1.1.0${NC}   - 語義化版本號（生產環境）"
    echo -e "  ${YELLOW}dev${NC}              - 開發環境標籤"
    echo -e "  ${YELLOW}staging${NC}          - 測試環境標籤"
    echo -e "  ${YELLOW}production${NC}       - 生產環境標籤"
    echo ""
    echo -e "${GREEN}AWS DevOps Agent 監控：${NC}"
    echo -e "  ${CYAN}✓ 自動發現${NC}       - 通過標籤自動發現資源"
    echo -e "  ${CYAN}✓ ECR 監控${NC}        - 監控映像推送和掃描"
    echo -e "  ${CYAN}✓ 事件響應${NC}       - 自動調查和根因分析"
    echo ""
    echo -e "${GREEN}使用範例：${NC}"
    echo -e "  ${CYAN}./build-and-push.sh${NC}              # 使用 latest 標籤"
    echo -e "  ${CYAN}./build-and-push.sh v1.0.0${NC}       # 使用版本號標籤"
    echo -e "  ${CYAN}./build-and-push.sh staging${NC}      # 使用環境標籤"
    echo ""
}

# 檢查必要工具
check_requirements() {
    log_info "檢查必要工具..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI 未安裝，請先安裝 AWS CLI"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安裝，請先安裝 Docker"
        exit 1
    fi
    
    log_success "所有必要工具已安裝"
}

# 設定變數
setup_variables() {
    log_info "設定環境變數..."
    
    export AWS_REGION=${AWS_REGION:-us-east-1}
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    export IMAGE_TAG=${1:-latest}
    
    log_info "AWS Account ID: ${AWS_ACCOUNT_ID}"
    log_info "ECR Registry: ${ECR_REGISTRY}"
    log_tag "Image Tag: ${IMAGE_TAG}"
    log_info "AWS Region: ${AWS_REGION}"
    
    # 顯示標籤用途
    case ${IMAGE_TAG} in
        latest)
            log_tag "用途: 開發環境 - 最新版本"
            ;;
        v*)
            log_tag "用途: 生產環境 - 版本發布 (${IMAGE_TAG})"
            ;;
        dev)
            log_tag "用途: 開發環境 - 開發分支"
            ;;
        staging)
            log_tag "用途: 測試環境 - 預發布測試"
            ;;
        production)
            log_tag "用途: 生產環境 - 正式部署"
            ;;
        *)
            log_tag "用途: 自訂標籤 - ${IMAGE_TAG}"
            ;;
    esac
}

# 創建 ECR 倉庫
create_ecr_repositories() {
    log_info "創建 ECR 倉庫..."
    
    repositories=("fish-game-client" "fish-game-session" "fish-game-server")
    
    for repo in "${repositories[@]}"; do
        if aws ecr describe-repositories --repository-names ${repo} --region ${AWS_REGION} &> /dev/null; then
            log_warning "ECR 倉庫 ${repo} 已存在"
        else
            log_info "創建 ECR 倉庫: ${repo}"
            aws ecr create-repository \
                --repository-name ${repo} \
                --region ${AWS_REGION} \
                --tags \
                    Key=Project,Value=fish-machine-workshop \
                    Key=Workshop,Value=fish-machine-workshop \
                    Key=ManagedBy,Value=1.service-verification-containerization/build-and-push.sh
            log_success "ECR 倉庫 ${repo} 創建成功"
        fi
    done
}

# ECR 登入
ecr_login() {
    log_info "登入 ECR..."
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
    log_success "ECR 登入成功"
}

# 構建並推送鏡像
build_and_push() {
    local service_name=$1
    local service_dir=$2
    local image_name=$3
    
    log_info "構建並推送 ${service_name}..."
    
    # 檢查服務目錄是否存在
    if [ ! -d "${service_dir}" ]; then
        log_error "服務目錄不存在: ${service_dir}"
        return 1
    fi
    
    # 檢查 Dockerfile 是否存在
    if [ ! -f "${service_dir}/Dockerfile" ]; then
        log_error "Dockerfile 不存在: ${service_dir}/Dockerfile"
        return 1
    fi
    
    # 構建鏡像
    log_info "構建 ${service_name} 鏡像..."
    cd ${service_dir}
    docker build -t ${image_name}:${IMAGE_TAG} .
    
    # 標記鏡像
    docker tag ${image_name}:${IMAGE_TAG} ${ECR_REGISTRY}/${image_name}:${IMAGE_TAG}
    
    # 推送鏡像
    log_info "推送 ${service_name} 鏡像到 ECR..."
    docker push ${ECR_REGISTRY}/${image_name}:${IMAGE_TAG}
    
    log_success "${service_name} 鏡像推送成功"
    cd - > /dev/null
}

# 驗證鏡像
verify_images() {
    log_info "驗證鏡像推送..."
    
    repositories=("fish-game-client" "fish-game-session" "fish-game-server")
    
    for repo in "${repositories[@]}"; do
        log_info "檢查 ${repo} 鏡像..."
        if aws ecr list-images --repository-name ${repo} --region ${AWS_REGION} --query 'imageIds[?imageTag==`'${IMAGE_TAG}'`]' --output text | grep -q ${IMAGE_TAG}; then
            log_success "${repo}:${IMAGE_TAG} 鏡像存在於 ECR"
        else
            log_error "${repo}:${IMAGE_TAG} 鏡像不存在於 ECR"
            return 1
        fi
    done
}

# 主函數
main() {
    # 顯示標籤策略
    show_tag_strategy
    
    log_info "開始構建並推送 Docker 鏡像到 ECR..."
    
    # 檢查參數
    IMAGE_TAG=${1:-latest}
    
    # 執行步驟
    check_requirements
    setup_variables ${IMAGE_TAG}
    create_ecr_repositories
    ecr_login
    
    # 構建並推送各個服務
    build_and_push "Client Service" "services/client-service" "fish-game-client"
    build_and_push "Game Session Service" "services/game-session-service" "fish-game-session"
    build_and_push "Game Server Service" "services/game-server-service" "fish-game-server"
    
    # 驗證
    verify_images
    
    log_success "所有鏡像構建並推送完成！"
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  🎉 映像推送成功！                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "你現在可以使用以下鏡像部署到 EKS："
    echo ""
    echo -e "  ${GREEN}Client Service:${NC}"
    echo "    ${ECR_REGISTRY}/fish-game-client:${IMAGE_TAG}"
    echo ""
    echo -e "  ${GREEN}Game Session Service:${NC}"
    echo "    ${ECR_REGISTRY}/fish-game-session:${IMAGE_TAG}"
    echo ""
    echo -e "  ${GREEN}Game Server Service:${NC}"
    echo "    ${ECR_REGISTRY}/fish-game-server:${IMAGE_TAG}"
    echo ""
    echo -e "${YELLOW}💡 提示：${NC}"
    echo "  - 在 Kubernetes 部署文件中使用上述映像 URI"
    echo "  - DevOps Agent 可以根據標籤自動選擇部署環境"
    echo "  - 使用不同標籤管理多環境部署（dev, staging, production）"
    echo ""
}

# 使用說明
usage() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Docker 映像構建與推送工具 (AWS DevOps Agent)       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}使用方式:${NC}"
    echo "  $0 [IMAGE_TAG]"
    echo ""
    echo -e "${GREEN}參數:${NC}"
    echo "  IMAGE_TAG    Docker 鏡像標籤 (預設: latest)"
    echo ""
    echo -e "${GREEN}專案標籤規範:${NC}"
    echo "  ${YELLOW}Project${NC}          - fish-machine-workshop"
    echo "  ${YELLOW}Workshop${NC}         - fish-machine-workshop"
    echo "  ${YELLOW}ManagedBy${NC}        - 1.service-verification-containerization/build-and-push.sh"
    echo ""
    echo -e "${GREEN}Docker 映像標籤策略:${NC}"
    echo "  ${YELLOW}latest${NC}           - 最新開發版本（預設）"
    echo "  ${YELLOW}v1.0.0, v1.1.0${NC}   - 語義化版本號（生產環境）"
    echo "  ${YELLOW}dev${NC}              - 開發環境標籤"
    echo "  ${YELLOW}staging${NC}          - 測試環境標籤"
    echo "  ${YELLOW}production${NC}       - 生產環境標籤"
    echo ""
    echo -e "${GREEN}範例:${NC}"
    echo "  $0                    # 使用 latest 標籤（開發環境）"
    echo "  $0 v1.0.0             # 使用 v1.0.0 標籤（生產發布）"
    echo "  $0 staging            # 使用 staging 標籤（測試環境）"
    echo "  $0 dev                # 使用 dev 標籤（開發環境）"
    echo ""
    echo -e "${GREEN}環境變數:${NC}"
    echo "  AWS_REGION   AWS 區域 (預設: us-east-1)"
    echo ""
    echo -e "${YELLOW}💡 AWS DevOps Agent 整合:${NC}"
    echo "  - AWS DevOps Agent 會自動發現標記的 ECR 倉庫"
    echo "  - 監控映像推送事件和掃描結果"
    echo "  - 自動調查部署問題並提供根因分析"
    echo "  - 所有 ECR 倉庫自動標記腳本路徑"
    echo ""
    echo -e "${CYAN}ManagedBy 標籤說明:${NC}"
    echo "  - 指向創建該資源的腳本檔案路徑"
    echo "  - 方便除錯和追蹤資源來源"
    echo "  - AWS DevOps Agent 可讀取腳本了解配置"
    echo ""
}

# 檢查幫助參數
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# 執行主函數
main $1
