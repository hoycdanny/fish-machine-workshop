#!/bin/bash

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日誌函數
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo -e "\n${BLUE}📊 $1${NC}"
    echo "=================================="
}

# 環境變數
export RESOURCE_REGION=ap-northeast-2
export PROJECT_TAG="fish-machine-workshop"
export CLUSTER_NAME="fish-game-cluster"

echo "🔍 AWS DevOps Agent 前置條件檢查"
echo "=================================="
echo ""

# 檢查 AWS CLI
log_section "檢查 AWS CLI"
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version)
    log_success "AWS CLI 已安裝: $AWS_VERSION"
    
    # 檢查身份
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [ -n "$AWS_ACCOUNT_ID" ]; then
        log_success "AWS 身份驗證成功: Account $AWS_ACCOUNT_ID"
    else
        log_error "AWS 身份驗證失敗，請配置 AWS CLI"
        exit 1
    fi
else
    log_error "AWS CLI 未安裝"
    exit 1
fi

# 檢查 kubectl
log_section "檢查 kubectl"
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)
    log_success "kubectl 已安裝: $KUBECTL_VERSION"
else
    log_error "kubectl 未安裝"
    exit 1
fi

# 第0章：檢查 AWS 配置
log_section "第0章：開發環境設置"
log_info "檢查 AWS 配置..."
if aws sts get-caller-identity &>/dev/null; then
    log_success "AWS CLI 配置正確"
else
    log_error "AWS CLI 配置失敗，請返回第0章"
    exit 1
fi

# 第1章：檢查 ECR 倉庫
log_section "第1章：服務驗證與容器化"
log_info "檢查 ECR 倉庫..."

ECR_REPOS=$(aws ecr describe-repositories --region $RESOURCE_REGION --query 'repositories[?contains(repositoryName, `fish-game`)].repositoryName' --output text 2>/dev/null)

if echo "$ECR_REPOS" | grep -q "fish-game"; then
    log_success "ECR 倉庫已創建"
    echo "   找到的倉庫: $ECR_REPOS"
    
    # 檢查映像
    for repo in fish-game-client fish-game-session fish-game-server; do
        IMAGE_COUNT=$(aws ecr list-images --repository-name $repo --region $RESOURCE_REGION --query 'length(imageIds)' --output text 2>/dev/null || echo "0")
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            log_success "  $repo: $IMAGE_COUNT 個映像"
        else
            log_warning "  $repo: 沒有映像"
        fi
    done
    
    # 檢查標籤
    log_info "檢查 ECR 標籤..."
    for repo in fish-game-client fish-game-session fish-game-server; do
        REPO_ARN="arn:aws:ecr:$RESOURCE_REGION:$AWS_ACCOUNT_ID:repository/$repo"
        TAGS=$(aws ecr list-tags-for-resource --resource-arn $REPO_ARN --query 'tags[?key==`Project`].value' --output text 2>/dev/null)
        if [ "$TAGS" = "$PROJECT_TAG" ]; then
            log_success "  $repo: 標籤正確"
        else
            log_warning "  $repo: 標籤缺失或不正確"
        fi
    done
else
    log_error "ECR 倉庫不存在，請返回第1章執行 ./build-and-push.sh"
    exit 1
fi

# 第2章：檢查 EKS 集群
log_section "第2章：EKS 集群設置"
log_info "檢查 EKS 集群..."

CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $RESOURCE_REGION --query 'cluster.status' --output text 2>/dev/null)

if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
    log_success "EKS 集群狀態: ACTIVE"
    
    # 檢查節點
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        log_success "  節點數量: $NODE_COUNT"
    else
        log_warning "  無法獲取節點資訊"
    fi
    
    # 檢查 EKS 標籤
    log_info "檢查 EKS 標籤..."
    CLUSTER_TAGS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $RESOURCE_REGION --query 'cluster.tags.Project' --output text 2>/dev/null)
    if [ "$CLUSTER_TAGS" = "$PROJECT_TAG" ]; then
        log_success "  EKS 集群標籤正確"
    else
        log_warning "  EKS 集群標籤缺失或不正確"
    fi
else
    log_error "EKS 集群不存在或狀態異常，請返回第2章執行 ./one-click-cmd.sh"
    exit 1
fi

# 第3章：檢查 Kubernetes 部署
log_section "第3章：EKS 服務部署"
log_info "檢查 Kubernetes 部署..."

if kubectl get namespace fish-game-system &>/dev/null; then
    log_success "命名空間 fish-game-system 存在"
    
    # 檢查 Pod
    POD_COUNT=$(kubectl get pods -n fish-game-system --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -n fish-game-system --no-headers 2>/dev/null | grep Running | wc -l)
    
    if [ "$POD_COUNT" -gt 0 ]; then
        log_success "  Pod 總數: $POD_COUNT"
        log_success "  運行中的 Pod: $RUNNING_PODS"
        
        if [ "$POD_COUNT" -ne "$RUNNING_PODS" ]; then
            log_warning "  部分 Pod 未運行"
        fi
    else
        log_warning "  沒有 Pod"
    fi
    
    # 檢查負載均衡器
    log_info "檢查負載均衡器..."
    CLIENT_ALB=$(kubectl get ingress client-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    NLB=$(kubectl get service game-server-nlb -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$CLIENT_ALB" ]; then
        log_success "  ALB 已創建: $CLIENT_ALB"
    else
        log_warning "  ALB 未創建或未就緒"
    fi
    
    if [ -n "$NLB" ]; then
        log_success "  NLB 已創建: $NLB"
    else
        log_warning "  NLB 未創建或未就緒"
    fi
    
    # 檢查 Kubernetes 資源標籤
    log_info "檢查 Kubernetes 資源標籤..."
    NS_LABELS=$(kubectl get namespace fish-game-system -o jsonpath='{.metadata.labels.project}' 2>/dev/null)
    if [ "$NS_LABELS" = "fish-machine-workshop" ]; then
        log_success "  Namespace 標籤正確"
    else
        log_warning "  Namespace 標籤缺失或不正確"
    fi
    
    # 檢查 AWS 負載均衡器標籤
    log_info "檢查 AWS 負載均衡器標籤..."
    ALB_ARN=$(aws elbv2 describe-load-balancers \
      --region $RESOURCE_REGION \
      --query "LoadBalancers[?contains(LoadBalancerName, 'fish-game')].LoadBalancerArn" \
      --output text 2>/dev/null | head -1)
    
    if [ -n "$ALB_ARN" ]; then
        ALB_TAGS=$(aws elbv2 describe-tags \
          --resource-arns $ALB_ARN \
          --query 'TagDescriptions[0].Tags[?Key==`Project`].Value' \
          --output text 2>/dev/null)
        
        if [ "$ALB_TAGS" = "$PROJECT_TAG" ]; then
            log_success "  負載均衡器標籤正確"
        else
            log_warning "  負載均衡器標籤缺失或不正確"
        fi
    fi
else
    log_error "命名空間 fish-game-system 不存在，請返回第3章執行 ./deploy.sh"
    exit 1
fi

# 總結
log_section "前置條件檢查總結"
echo ""
log_success "🎉 所有前置條件檢查通過！"
echo ""
echo "你已經準備好開始第四章：AWS DevOps Agent 整合"
echo ""
echo "📋 下一步："
echo "   1. 訪問 AWS DevOps Agent Console"
echo "      https://console.aws.amazon.com/devops-agent/"
echo ""
echo "   2. 啟用 DevOps Agent 服務"
echo ""
echo "   3. 配置資源監控："
echo "      - EKS 集群: $CLUSTER_NAME"
echo "      - ECR 倉庫: fish-game-*"
echo "      - CloudWatch 日誌: /aws/eks/$CLUSTER_NAME/*"
echo ""
echo "   4. 使用標籤過濾: Project=$PROJECT_TAG"
echo ""
echo "📚 詳細步驟請參考 README.md 的「快速開始指南」"
echo ""
