set -e  # 遇到錯誤立即退出

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

log_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
}

# 確認清除操作
confirm_cleanup() {
    echo "🚨 警告：此操作將刪除所有 fish-game-system 命名空間中的資源"
    echo "包括："
    echo "  - 所有 Pod 和 Deployment"
    echo "  - 所有 Service 和 Ingress"
    echo "  - ALB 和 NLB 負載均衡器"
    echo "  - ConfigMap 和其他配置"
    echo ""
    
    read -p "確定要繼續嗎？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
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
    
    # 檢查 EKS 集群連接
    if ! kubectl get nodes &> /dev/null; then
        log_error "無法連接到 EKS 集群，請檢查 kubeconfig 配置"
        exit 1
    fi
    
    # 檢查命名空間是否存在
    if ! kubectl get namespace fish-game-system &> /dev/null; then
        log_warning "fish-game-system 命名空間不存在，可能已經被清除"
        exit 0
    fi
    
    log_success "前置條件檢查通過"
}

# 顯示當前資源狀態
show_current_resources() {
    log_step "當前資源狀態"
    
    echo "📊 Pods:"
    kubectl get pods -n fish-game-system 2>/dev/null || echo "  無 Pod"
    
    echo ""
    echo "🌐 Services:"
    kubectl get services -n fish-game-system 2>/dev/null || echo "  無 Service"
    
    echo ""
    echo "🔗 Ingress:"
    kubectl get ingress -n fish-game-system 2>/dev/null || echo "  無 Ingress"
    
    echo ""
}

# 刪除 Ingress（ALB）
delete_ingress() {
    log_step "刪除 Ingress 和 ALB"
    
    # 檢查是否真的有 Ingress 資源
    local ingress_count=$(kubectl get ingress -n fish-game-system --no-headers 2>/dev/null | wc -l)
    
    if [ "$ingress_count" -gt 0 ]; then
        log_info "刪除 Ingress 資源..."
        kubectl delete -f k8s-manifests/9.ingress.yaml --ignore-not-found=true
        
        log_info "等待 ALB 刪除完成（最多等待 3 分鐘）..."
        # 等待 Ingress 完全刪除，但設置超時
        local timeout=180  # 3 分鐘
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
    log_step "刪除 NLB"
    
    # 檢查是否真的有 NLB Service
    if kubectl get service game-server-nlb -n fish-game-system --no-headers 2>/dev/null | grep -q game-server-nlb; then
        log_info "刪除 NLB 資源..."
        kubectl delete -f k8s-manifests/8.nlb.yaml --ignore-not-found=true
        
        log_info "等待 NLB 刪除完成（最多等待 3 分鐘）..."
        # 等待 NLB Service 完全刪除，但設置超時
        local timeout=180  # 3 分鐘
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
    log_step "刪除應用資源"
    
    # 按相反順序刪除資源
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
    log_step "等待 Pod 終止"
    
    log_info "等待所有 Pod 完全終止（最多等待 2 分鐘）..."
    local timeout=120  # 2 分鐘
    local elapsed=0
    
    while kubectl get pods -n fish-game-system --no-headers 2>/dev/null | grep -v "Terminating" | wc -l | grep -v "^0$" > /dev/null && [ $elapsed -lt $timeout ]; do
        echo -n "."
        sleep 3
        elapsed=$((elapsed + 3))
    done
    echo ""
    
    # 等待 Terminating 狀態的 Pod 也完全消失
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

# 驗證清除結果
verify_cleanup() {
    log_step "驗證清除結果"
    
    # 檢查命名空間
    if kubectl get namespace fish-game-system &> /dev/null; then
        log_error "命名空間仍然存在"
        return 1
    fi
    
    # 檢查是否還有相關的 AWS 資源（可選）
    log_info "檢查 AWS 負載均衡器..."
    
    # 檢查 ALB
    ALB_COUNT=$(aws elbv2 describe-load-balancers --region ap-northeast-2 --query 'LoadBalancers[?contains(LoadBalancerName, `fish-game`)].LoadBalancerName' --output text 2>/dev/null | wc -w || echo "0")
    if [ "$ALB_COUNT" -gt 0 ]; then
        log_warning "仍有 ${ALB_COUNT} 個相關的負載均衡器，可能需要手動清理"
    else
        log_success "未發現殘留的負載均衡器"
    fi
    
    log_success "✅ 清除驗證完成"
}

# 顯示清除摘要
show_cleanup_summary() {
    echo ""
    log_success "🎉 清除完成！"
    echo ""
    echo "已刪除的資源："
    echo "  ✅ fish-game-system 命名空間"
    echo "  ✅ 所有 Pod 和 Deployment"
    echo "  ✅ 所有 Service 和 ConfigMap"
    echo "  ✅ ALB 和 NLB 負載均衡器"
    echo ""
    log_info "如需重新部署，請執行: ./deploy.sh"
}

# 主函數
main() {
    echo "🧹 開始執行 EKS 服務一鍵清除"
    echo "=================================="
    
    confirm_cleanup
    check_prerequisites
    show_current_resources
    
    # 按順序刪除資源（先刪除負載均衡器，再刪除應用）
    delete_ingress
    delete_nlb
    delete_application_resources
    wait_for_pods_termination
    delete_namespace
    
    verify_cleanup
    show_cleanup_summary
}

# 執行主函數
main "$@"