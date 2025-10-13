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

# 檢查命名空間
check_namespace() {
    log_section "命名空間狀態"
    
    if kubectl get namespace fish-game-system &> /dev/null; then
        log_success "fish-game-system 命名空間存在"
    else
        log_error "fish-game-system 命名空間不存在"
        echo "請先執行 ./deploy.sh 進行部署"
        exit 1
    fi
}

# 檢查 Pod 狀態
check_pods() {
    log_section "Pod 狀態"
    
    kubectl get pods -n fish-game-system -o wide
    
    echo ""
    # 檢查每個服務的 Pod
    services=("redis" "client-service" "game-session-service" "game-server-service")
    
    for service in "${services[@]}"; do
        pod_status=$(kubectl get pods -n fish-game-system -l app=$service -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        if [ "$pod_status" = "Running" ]; then
            log_success "$service Pod 運行正常"
        elif [ "$pod_status" = "Pending" ]; then
            log_warning "$service Pod 正在啟動中"
        elif [ -z "$pod_status" ]; then
            log_error "$service Pod 不存在"
        else
            log_error "$service Pod 狀態異常: $pod_status"
        fi
    done
}

# 檢查服務狀態
check_services() {
    log_section "Service 狀態"
    
    kubectl get services -n fish-game-system
    
    echo ""
    # 檢查 NLB 狀態
    nlb_status=$(kubectl get service game-server-nlb -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$nlb_status" ]; then
        log_success "NLB 已創建: $nlb_status"
    else
        log_warning "NLB 還在創建中或創建失敗"
    fi
}

# 檢查 Ingress 狀態
check_ingress() {
    log_section "Ingress 狀態"
    
    kubectl get ingress -n fish-game-system
    
    echo ""
    # 檢查 ALB 狀態
    client_alb=$(kubectl get ingress client-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    api_alb=$(kubectl get ingress api-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$client_alb" ]; then
        log_success "Client ALB 已創建: $client_alb"
    else
        log_warning "Client ALB 還在創建中或創建失敗"
    fi
    
    if [ -n "$api_alb" ]; then
        log_success "API ALB 已創建: $api_alb"
    else
        log_warning "API ALB 還在創建中或創建失敗"
    fi
}

# 檢查 ConfigMap
check_configmap() {
    log_section "ConfigMap 配置"
    
    echo "前端配置："
    kubectl get configmap fish-game-config -n fish-game-system -o yaml | grep FRONTEND || log_warning "未找到前端配置"
    
    echo ""
    # 檢查配置是否已更新
    frontend_session_url=$(kubectl get configmap fish-game-config -n fish-game-system -o jsonpath='{.data.FRONTEND_SESSION_URL}' 2>/dev/null)
    frontend_game_url=$(kubectl get configmap fish-game-config -n fish-game-system -o jsonpath='{.data.FRONTEND_GAME_URL}' 2>/dev/null)
    
    if [ -n "$frontend_session_url" ] && [ "$frontend_session_url" != "" ]; then
        log_success "前端 Session URL 已配置: $frontend_session_url"
    else
        log_warning "前端 Session URL 未配置"
    fi
    
    if [ -n "$frontend_game_url" ] && [ "$frontend_game_url" != "" ]; then
        log_success "前端 Game URL 已配置: $frontend_game_url"
    else
        log_warning "前端 Game URL 未配置"
    fi
}

# 測試健康檢查
test_health_checks() {
    log_section "健康檢查測試"
    
    # 獲取地址
    api_alb=$(kubectl get ingress api-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    nlb_address=$(kubectl get service game-server-nlb -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$api_alb" ]; then
        echo "測試 API 健康檢查..."
        if curl -f -s http://${api_alb}/api/health > /dev/null 2>&1; then
            log_success "API 健康檢查通過"
        else
            log_warning "API 健康檢查失敗（可能還在啟動中）"
        fi
    fi
    
    if [ -n "$nlb_address" ]; then
        echo "測試遊戲服務健康檢查..."
        if curl -f -s http://${nlb_address}:8083/health > /dev/null 2>&1; then
            log_success "遊戲服務健康檢查通過"
        else
            log_warning "遊戲服務健康檢查失敗（可能還在啟動中）"
        fi
    fi
}

# 顯示訪問地址
show_access_urls() {
    log_section "訪問地址"
    
    client_alb=$(kubectl get ingress client-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    api_alb=$(kubectl get ingress api-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    nlb_address=$(kubectl get service game-server-nlb -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$client_alb" ] && [ -n "$api_alb" ] && [ -n "$nlb_address" ]; then
        echo "🎮 遊戲主頁面: http://${client_alb}"
        echo "🔧 API 服務:   http://${api_alb}"
        echo "🎯 WebSocket:  http://${nlb_address}:8083"
        echo ""
        echo "📋 快速測試命令："
        echo "curl -I http://${client_alb}/"
        echo "curl -I http://${api_alb}/api/health"
        echo "curl -I http://${nlb_address}:8083/health"
    else
        log_warning "部分負載均衡器還未就緒，請稍後再試"
    fi
}

# 顯示最近事件
show_recent_events() {
    log_section "最近事件"
    
    kubectl get events -n fish-game-system --sort-by='.lastTimestamp' | tail -10
}

# 主函數
main() {
    echo "🔍 EKS 服務狀態檢查"
    echo "===================="
    
    # 檢查 kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安裝"
        exit 1
    fi
    
    # 檢查 EKS 連接
    if ! kubectl get nodes &> /dev/null; then
        log_error "無法連接到 EKS 集群"
        exit 1
    fi
    
    check_namespace
    check_pods
    check_services
    check_ingress
    check_configmap
    test_health_checks
    show_access_urls
    show_recent_events
    
    echo ""
    log_info "狀態檢查完成！"
    echo ""
    log_info "如果發現問題："
    log_info "  - 查看 README.md 故障排除指南"
    log_info "  - 執行 './cleanup.sh' 後重新 './deploy.sh'"
    log_info "  - 檢查 AWS 控制台中的負載均衡器狀態"
}

# 執行主函數
main "$@"