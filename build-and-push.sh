#!/bin/bash
# build-and-push.sh - 構建並推送 Docker 鏡像到 ECR

set -e

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    
    export AWS_REGION=${AWS_REGION:-ap-northeast-2}
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    export IMAGE_TAG=${1:-latest}
    
    log_info "AWS Account ID: ${AWS_ACCOUNT_ID}"
    log_info "ECR Registry: ${ECR_REGISTRY}"
    log_info "Image Tag: ${IMAGE_TAG}"
    log_info "AWS Region: ${AWS_REGION}"
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
            aws ecr create-repository --repository-name ${repo} --region ${AWS_REGION}
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
    log_info "你現在可以使用以下鏡像部署到 EKS："
    echo "  - ${ECR_REGISTRY}/fish-game-client:${IMAGE_TAG}"
    echo "  - ${ECR_REGISTRY}/fish-game-session:${IMAGE_TAG}"
    echo "  - ${ECR_REGISTRY}/fish-game-server:${IMAGE_TAG}"
}

# 使用說明
usage() {
    echo "使用方式: $0 [IMAGE_TAG]"
    echo ""
    echo "參數:"
    echo "  IMAGE_TAG    Docker 鏡像標籤 (預設: latest)"
    echo ""
    echo "範例:"
    echo "  $0           # 使用 latest 標籤"
    echo "  $0 v1.0.0    # 使用 v1.0.0 標籤"
    echo ""
    echo "環境變數:"
    echo "  AWS_REGION   AWS 區域 (預設: ap-northeast-2)"
}

# 檢查幫助參數
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# 執行主函數
main $1