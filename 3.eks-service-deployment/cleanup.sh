set -e  # 遇到錯誤立即退出

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
CLUSTER_NAME="fish-game-cluster"
REGION="ap-northeast-2"
ECR_REPOS=("fish-game-client" "fish-game-session" "fish-game-server")

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

log_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
}

# 確認清除操作
confirm_cleanup() {
    echo "🚨🚨🚨 警告：完整 AWS 環境清除 🚨🚨🚨"
    echo ""
    echo "此操作將刪除以下所有資源："
    echo ""
    echo "📦 應用層 (fish-game-system 命名空間)："
    echo "  - 所有 Pod 和 Deployment"
    echo "  - 所有 Service 和 Ingress"
    echo "  - ALB 和 NLB 負載均衡器"
    echo "  - ConfigMap 和其他配置"
    echo ""
    echo "☸️  EKS 集群："
    echo "  - EKS Cluster: ${CLUSTER_NAME}"
    echo "  - Node Group 和所有 EC2 節點"
    echo "  - VPC、子網路、安全組"
    echo "  - IAM Roles 和政策"
    echo ""
    echo "🐳 ECR 映像倉庫："
    echo "  - fish-game-client"
    echo "  - fish-game-session"
    echo "  - fish-game-server"
    echo "  - 所有映像版本"
    echo ""
    echo "📊 CloudWatch 資源："
    echo "  - 所有 Container Insights 日誌群組"
    echo "  - 歷史日誌數據"
    echo ""
    echo "💰 這將停止所有相關的 AWS 費用"
    echo ""
    
    read -p "❗ 確定要刪除所有資源嗎？此操作無法復原！(yes/NO): " -r
    echo
    if [[ ! $REPLY == "yes" ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    echo ""
    read -p "❗❗ 再次確認：輸入集群名稱 '${CLUSTER_NAME}' 以繼續: " -r
    echo
    if [[ ! $REPLY == "${CLUSTER_NAME}" ]]; then
        log_info "集群名稱不匹配，操作已取消"
        exit 0
    fi
}

# 檢查前置條件
check_prerequisites() {
    log_step "檢查前置條件"
    
    # 檢查 kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安裝"
        exit 1
    fi
    
    # 檢查 eksctl
    if ! command -v eksctl &> /dev/null; then
        log_error "eksctl 未安裝，無法刪除 EKS 集群"
        exit 1
    fi
    
    # 檢查 AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI 未安裝"
        exit 1
    fi
    
    # 檢查 AWS 認證
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 認證失敗，請檢查 AWS CLI 配置"
        exit 1
    fi
    
    # 檢查 EKS 集群是否存在
    if ! aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} &> /dev/null; then
        log_warning "EKS 集群 ${CLUSTER_NAME} 不存在"
        CLUSTER_EXISTS=false
    else
        CLUSTER_EXISTS=true
        log_info "找到 EKS 集群: ${CLUSTER_NAME}"
    fi
    
    log_success "前置條件檢查通過"
}

# 顯示當前資源狀態
show_current_resources() {
    log_step "當前資源狀態"
    
    if [ "$CLUSTER_EXISTS" = true ]; then
        echo "📊 Pods:"
        kubectl get pods -n fish-game-system 2>/dev/null || echo "  無 Pod"
        
        echo ""
        echo "🌐 Services:"
        kubectl get services -n fish-game-system 2>/dev/null || echo "  無 Service"
        
        echo ""
        echo "🔗 Ingress:"
        kubectl get ingress -n fish-game-system 2>/dev/null || echo "  無 Ingress"
        
        echo ""
        echo "☸️  EKS Nodes:"
        kubectl get nodes 2>/dev/null || echo "  無法連接到集群"
    else
        log_info "集群不存在，跳過 Kubernetes 資源檢查"
    fi
    
    echo ""
    echo "🐳 ECR Repositories:"
    for repo in "${ECR_REPOS[@]}"; do
        if aws ecr describe-repositories --repository-names ${repo} --region ${REGION} &> /dev/null; then
            IMAGE_COUNT=$(aws ecr list-images --repository-name ${repo} --region ${REGION} --query 'imageIds' --output json | jq '. | length')
            echo "  ✓ ${repo} (${IMAGE_COUNT} 個映像)"
        else
            echo "  ✗ ${repo} (不存在)"
        fi
    done
    
    echo ""
    echo "📊 CloudWatch Log Groups:"
    aws logs describe-log-groups --log-group-name-prefix /aws/containerinsights/${CLUSTER_NAME} --region ${REGION} --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "  無日誌群組"
    
    echo ""
}

# 刪除 Ingress（ALB）
delete_ingress() {
    if [ "$CLUSTER_EXISTS" = false ]; then
        log_info "集群不存在，跳過 Ingress 刪除"
        return 0
    fi
    
    log_step "刪除 Ingress 和 ALB"
    
    # 檢查是否真的有 Ingress 資源
    local ingress_count=$(kubectl get ingress -n fish-game-system --no-headers 2>/dev/null | wc -l)
    
    if [ "$ingress_count" -gt 0 ]; then
        log_info "刪除 Ingress 資源..."
        kubectl delete -f k8s-manifests/9.ingress.yaml --ignore-not-found=true
        
        log_info "等待 ALB 刪除完成（最多等待 3 分鐘）..."
        local timeout=180
        local elapsed=0
        while [ $(kubectl get ingress -n fish-game-system --no-headers 2>/dev/null | wc -l) -gt 0 ] && [ $elapsed -lt $timeout ]; do
            echo -n "."
            sleep 5
            elapsed=$((elapsed + 5))
        done
        echo ""
        
        if [ $(kubectl get ingress -n fish-game-system --no-headers 2>/dev/null | wc -l) -gt 0 ]; then
            log_warning "ALB 刪除超時，但會在後台繼續刪除"
        else
            log_success "ALB 刪除完成"
        fi
    else
        log_info "未發現 Ingress 資源"
    fi
}

# 刪除 NLB
delete_nlb() {
    if [ "$CLUSTER_EXISTS" = false ]; then
        log_info "集群不存在，跳過 NLB 刪除"
        return 0
    fi
    
    log_step "刪除 NLB"
    
    if kubectl get service game-server-nlb -n fish-game-system --no-headers 2>/dev/null | grep -q game-server-nlb; then
        log_info "刪除 NLB 資源..."
        kubectl delete -f k8s-manifests/8.nlb.yaml --ignore-not-found=true
        
        log_info "等待 NLB 刪除完成（最多等待 3 分鐘）..."
        local timeout=180
        local elapsed=0
        while kubectl get service game-server-nlb -n fish-game-system --no-headers 2>/dev/null | grep -q game-server-nlb && [ $elapsed -lt $timeout ]; do
            echo -n "."
            sleep 5
            elapsed=$((elapsed + 5))
        done
        echo ""
        
        if kubectl get service game-server-nlb -n fish-game-system --no-headers 2>/dev/null | grep -q game-server-nlb; then
            log_warning "NLB 刪除超時，但會在後台繼續刪除"
        else
            log_success "NLB 刪除完成"
        fi
    else
        log_info "未發現 NLB 資源"
    fi
}

# 刪除應用資源
delete_application_resources() {
    if [ "$CLUSTER_EXISTS" = false ]; then
        log_info "集群不存在，跳過應用資源刪除"
        return 0
    fi
    
    log_step "刪除應用資源"
    
    log_info "刪除 Services..."
    kubectl delete -f k8s-manifests/7.services.yaml --ignore-not-found=true
    
    log_info "刪除應用 Deployments..."
    kubectl delete -f k8s-manifests/6.server-deployment.yaml --ignore-not-found=true
    kubectl delete -f k8s-manifests/5.session-deployment.yaml --ignore-not-found=true
    kubectl delete -f k8s-manifests/4.client-deployment.yaml --ignore-not-found=true
    
    log_info "刪除 Redis..."
    kubectl delete -f k8s-manifests/3.redis-deployment.yaml --ignore-not-found=true
    
    log_info "刪除 ConfigMap..."
    kubectl delete -f k8s-manifests/2.configmap.yaml --ignore-not-found=true
    
    log_success "應用資源刪除完成"
}

# 等待 Pod 終止
wait_for_pods_termination() {
    if [ "$CLUSTER_EXISTS" = false ]; then
        return 0
    fi
    
    log_step "等待 Pod 終止"
    
    log_info "等待所有 Pod 完全終止（最多等待 2 分鐘）..."
    local timeout=120
    local elapsed=0
    
    while kubectl get pods -n fish-game-system --no-headers 2>/dev/null | grep -v "Terminating" | wc -l | grep -v "^0$" > /dev/null && [ $elapsed -lt $timeout ]; do
        echo -n "."
        sleep 3
        elapsed=$((elapsed + 3))
    done
    echo ""
    
    elapsed=0
    while kubectl get pods -n fish-game-system --no-headers 2>/dev/null | wc -l | grep -v "^0$" > /dev/null && [ $elapsed -lt $timeout ]; do
        echo -n "."
        sleep 3
        elapsed=$((elapsed + 3))
    done
    echo ""
    
    if kubectl get pods -n fish-game-system --no-headers 2>/dev/null | wc -l | grep -v "^0$" > /dev/null; then
        log_warning "部分 Pod 終止超時，但會繼續清理"
    else
        log_success "所有 Pod 已終止"
    fi
}

# 刪除命名空間
delete_namespace() {
    if [ "$CLUSTER_EXISTS" = false ]; then
        log_info "集群不存在，跳過命名空間刪除"
        return 0
    fi
    
    log_step "刪除命名空間"
    
    log_info "刪除 fish-game-system 命名空間..."
    kubectl delete -f k8s-manifests/1.namespace.yaml --ignore-not-found=true
    
    log_info "等待命名空間完全刪除..."
    while kubectl get namespace fish-game-system &> /dev/null; do
        echo -n "."
        sleep 3
    done
    echo ""
    
    log_success "命名空間刪除完成"
}

# 刪除 EKS 集群
delete_eks_cluster() {
    if [ "$CLUSTER_EXISTS" = false ]; then
        log_info "EKS 集群不存在，跳過刪除"
        return 0
    fi
    
    log_step "刪除 EKS 集群（包含所有節點和 VPC）"
    
    log_warning "這將刪除整個 EKS 集群，包括："
    log_warning "  - 所有 EC2 節點"
    log_warning "  - Node Groups"
    log_warning "  - VPC 和網路資源"
    log_warning "  - 相關的 IAM Roles"
    
    log_info "開始刪除 EKS 集群: ${CLUSTER_NAME}..."
    log_info "預計需要 10-15 分鐘，請耐心等待..."
    
    if eksctl delete cluster --name ${CLUSTER_NAME} --region ${REGION} --wait; then
        log_success "EKS 集群刪除完成"
    else
        log_error "EKS 集群刪除失敗，請檢查錯誤訊息"
        log_info "你可以手動執行: eksctl delete cluster --name ${CLUSTER_NAME} --region ${REGION}"
        return 1
    fi
}

# 刪除 ECR 映像倉庫
delete_ecr_repositories() {
    log_step "刪除 ECR 映像倉庫"
    
    for repo in "${ECR_REPOS[@]}"; do
        log_info "檢查 ECR repository: ${repo}..."
        
        if aws ecr describe-repositories --repository-names ${repo} --region ${REGION} &> /dev/null; then
            log_info "刪除 ${repo} 及所有映像..."
            
            if aws ecr delete-repository --repository-name ${repo} --region ${REGION} --force &> /dev/null; then
                log_success "${repo} 刪除完成"
            else
                log_warning "${repo} 刪除失敗，可能需要手動清理"
            fi
        else
            log_info "${repo} 不存在，跳過"
        fi
    done
    
    log_success "ECR 倉庫清理完成"
}

# 刪除 CloudWatch 日誌群組
delete_cloudwatch_logs() {
    log_step "刪除 CloudWatch 日誌群組"
    
    # 獲取所有相關的日誌群組
    log_info "查找 CloudWatch 日誌群組..."
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix /aws/containerinsights/${CLUSTER_NAME} \
        --region ${REGION} \
        --query 'logGroups[].logGroupName' \
        --output text 2>/dev/null)
    
    if [ -z "$LOG_GROUPS" ]; then
        log_info "未找到相關的 CloudWatch 日誌群組"
        return 0
    fi
    
    for log_group in $LOG_GROUPS; do
        log_info "刪除日誌群組: ${log_group}..."
        
        if aws logs delete-log-group --log-group-name ${log_group} --region ${REGION} &> /dev/null; then
            log_success "${log_group} 刪除完成"
        else
            log_warning "${log_group} 刪除失敗"
        fi
    done
    
    log_success "CloudWatch 日誌清理完成"
}

# 清理殘留的 IAM 政策（可選）
cleanup_iam_policies() {
    log_step "清理 IAM 政策（可選）"
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
    
    log_info "檢查 Load Balancer Controller IAM Policy..."
    
    if aws iam get-policy --policy-arn ${POLICY_ARN} &> /dev/null; then
        log_info "找到政策: ${POLICY_ARN}"
        
        # 檢查是否有附加到任何角色
        ATTACHED_COUNT=$(aws iam list-entities-for-policy --policy-arn ${POLICY_ARN} --query 'PolicyRoles' --output json | jq '. | length')
        
        if [ "$ATTACHED_COUNT" -eq 0 ]; then
            log_info "政策未附加到任何角色，可以安全刪除"
            
            if aws iam delete-policy --policy-arn ${POLICY_ARN} &> /dev/null; then
                log_success "IAM Policy 刪除完成"
            else
                log_warning "IAM Policy 刪除失敗"
            fi
        else
            log_warning "政策仍附加到 ${ATTACHED_COUNT} 個角色，跳過刪除"
            log_info "eksctl 會自動清理相關的 IAM 角色"
        fi
    else
        log_info "未找到 Load Balancer Controller IAM Policy"
    fi
}

# 驗證清除結果
verify_cleanup() {
    log_step "驗證清除結果"
    
    local all_clean=true
    
    # 檢查 EKS 集群
    log_info "檢查 EKS 集群..."
    if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} &> /dev/null; then
        log_error "EKS 集群仍然存在"
        all_clean=false
    else
        log_success "EKS 集群已刪除"
    fi
    
    # 檢查 ECR 倉庫
    log_info "檢查 ECR 倉庫..."
    local remaining_repos=0
    for repo in "${ECR_REPOS[@]}"; do
        if aws ecr describe-repositories --repository-names ${repo} --region ${REGION} &> /dev/null; then
            log_warning "ECR 倉庫仍存在: ${repo}"
            remaining_repos=$((remaining_repos + 1))
            all_clean=false
        fi
    done
    
    if [ $remaining_repos -eq 0 ]; then
        log_success "所有 ECR 倉庫已刪除"
    fi
    
    # 檢查 CloudWatch 日誌
    log_info "檢查 CloudWatch 日誌群組..."
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix /aws/containerinsights/${CLUSTER_NAME} \
        --region ${REGION} \
        --query 'logGroups[].logGroupName' \
        --output text 2>/dev/null)
    
    if [ -z "$LOG_GROUPS" ]; then
        log_success "CloudWatch 日誌群組已清理"
    else
        log_warning "仍有 CloudWatch 日誌群組存在"
        all_clean=false
    fi
    
    # 檢查負載均衡器
    log_info "檢查 AWS 負載均衡器..."
    ALB_COUNT=$(aws elbv2 describe-load-balancers --region ${REGION} --query 'LoadBalancers[?contains(LoadBalancerName, `fish-game`)].LoadBalancerName' --output text 2>/dev/null | wc -w || echo "0")
    
    if [ "$ALB_COUNT" -gt 0 ]; then
        log_warning "仍有 ${ALB_COUNT} 個相關的負載均衡器"
        all_clean=false
    else
        log_success "未發現殘留的負載均衡器"
    fi
    
    if [ "$all_clean" = true ]; then
        log_success "✅ 所有資源清除驗證通過"
    else
        log_warning "⚠️  部分資源可能需要手動清理"
    fi
}

# 顯示清除摘要
show_cleanup_summary() {
    echo ""
    log_success "🎉 完整清除完成！"
    echo ""
    echo "已刪除的資源："
    echo "  ✅ fish-game-system 命名空間和所有應用"
    echo "  ✅ ALB 和 NLB 負載均衡器"
    echo "  ✅ EKS 集群 (${CLUSTER_NAME})"
    echo "  ✅ 所有 EC2 節點和 Node Groups"
    echo "  ✅ VPC 和網路資源"
    echo "  ✅ ECR 映像倉庫和所有映像"
    echo "  ✅ CloudWatch 日誌群組和歷史數據"
    echo ""
    echo "💰 所有相關的 AWS 費用已停止"
    echo ""
    log_info "如需重新部署："
    echo "  1. 執行: cd ../2.eks-cluster-setup && ./one-click-cmd.sh"
    echo "  2. 推送映像: cd ../1.service-verification-containerization && ./build-and-push.sh"
    echo "  3. 部署應用: cd ../3.eks-service-deployment && ./deploy.sh"
}

# 主函數
main() {
    echo "🧹 開始執行完整 AWS 環境清除"
    echo "=================================="
    
    confirm_cleanup
    check_prerequisites
    show_current_resources
    
    echo ""
    log_warning "開始清除流程，請勿中斷..."
    echo ""
    
    # 第一階段：清除 Kubernetes 應用資源
    if [ "$CLUSTER_EXISTS" = true ]; then
        log_info "📦 第一階段：清除應用資源"
        delete_ingress
        delete_nlb
        delete_application_resources
        wait_for_pods_termination
        delete_namespace
    fi
    
    # 第二階段：刪除 EKS 集群
    log_info "☸️  第二階段：刪除 EKS 集群"
    delete_eks_cluster
    
    # 第三階段：清除 ECR 和 CloudWatch
    log_info "🐳 第三階段：清除 ECR 和 CloudWatch"
    delete_ecr_repositories
    delete_cloudwatch_logs
    
    # 第四階段：清理 IAM 政策（可選）
    log_info "🔐 第四階段：清理 IAM 政策"
    cleanup_iam_policies
    
    # 驗證和總結
    verify_cleanup
    show_cleanup_summary
}

# 執行主函數
main "$@"