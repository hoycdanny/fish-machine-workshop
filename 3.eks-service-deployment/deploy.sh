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

# 檢查前置條件
check_prerequisites() {
    log_step "檢查前置條件"
    
    # 檢查 kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安裝，請先安裝 kubectl"
        exit 1
    fi
    
    # 檢查 EKS 集群連接
    if ! kubectl get nodes &> /dev/null; then
        log_error "無法連接到 EKS 集群，請檢查 kubeconfig 配置"
        exit 1
    fi
    
    # 檢查 AWS Load Balancer Controller
    if ! kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
        log_error "AWS Load Balancer Controller 未安裝，請先完成第二章的集群設置"
        exit 1
    fi
    
    log_success "前置條件檢查通過"
}

# 部署 Kubernetes 資源
deploy_resources() {
    log_step "開始部署 Kubernetes 資源"
    
    # Step 1: 創建命名空間
    log_info "Step 1: 創建命名空間"
    kubectl apply -f k8s-manifests/1.namespace.yaml
    
    # Step 2: 創建 ConfigMap
    log_info "Step 2: 創建 ConfigMap"
    kubectl apply -f k8s-manifests/2.configmap.yaml
    
    # Step 3: 部署 Redis
    log_info "Step 3: 部署 Redis 數據庫"
    kubectl apply -f k8s-manifests/3.redis-deployment.yaml
    log_info "等待 Redis Pod 就緒..."
    kubectl wait --for=condition=ready pod -l app=redis -n fish-game-system --timeout=120s
    
    # Step 4: 部署前端服務
    log_info "Step 4: 部署前端服務"
    kubectl apply -f k8s-manifests/4.client-deployment.yaml
    
    # Step 5: 部署會話管理服務
    log_info "Step 5: 部署會話管理服務"
    kubectl apply -f k8s-manifests/5.session-deployment.yaml
    
    # Step 6: 部署遊戲邏輯服務
    log_info "Step 6: 部署遊戲邏輯服務"
    kubectl apply -f k8s-manifests/6.server-deployment.yaml
    
    # 等待所有應用 Pod 就緒
    log_info "等待所有應用 Pod 就緒..."
    kubectl wait --for=condition=ready pod -l app=client-service -n fish-game-system --timeout=180s
    kubectl wait --for=condition=ready pod -l app=game-session-service -n fish-game-system --timeout=180s
    kubectl wait --for=condition=ready pod -l app=game-server-service -n fish-game-system --timeout=180s
    
    # Step 7: 創建服務
    log_info "Step 7: 創建 Kubernetes Services"
    kubectl apply -f k8s-manifests/7.services.yaml
    
    # Step 8: 創建 NLB
    log_info "Step 8: 創建網絡負載均衡器 (NLB)"
    kubectl apply -f k8s-manifests/8.nlb.yaml
    
    # Step 9: 創建 Ingress (ALB)
    log_info "Step 9: 創建應用負載均衡器 (ALB)"
    kubectl apply -f k8s-manifests/9.ingress.yaml
    
    log_success "所有 Kubernetes 資源部署完成"
}

# 等待負載均衡器就緒
wait_for_load_balancers() {
    log_step "等待負載均衡器創建完成"
    
    log_info "等待 ALB 創建（預計需要 2-3 分鐘）..."
    kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' ingress/client-ingress -n fish-game-system --timeout=300s
    kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' ingress/api-ingress -n fish-game-system --timeout=300s
    
    log_info "等待 NLB 創建（預計需要 2-3 分鐘）..."
    kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/game-server-nlb -n fish-game-system --timeout=300s
    
    log_success "負載均衡器創建完成"
}

# 更新 ConfigMap 配置
update_configmap() {
    log_step "更新 ConfigMap 前端配置"
    
    # 獲取負載均衡器地址
    CLIENT_ALB=$(kubectl get ingress client-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    API_ALB=$(kubectl get ingress api-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    NLB_ADDRESS=$(kubectl get service game-server-nlb -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    log_info "獲取到的負載均衡器地址："
    echo "  Client ALB: ${CLIENT_ALB}"
    echo "  API ALB: ${API_ALB}"
    echo "  NLB: ${NLB_ADDRESS}"
    
    # 更新 ConfigMap（注意：不要在 FRONTEND_SESSION_URL 後面加 /api）
    kubectl patch configmap fish-game-config -n fish-game-system --patch "
data:
  FRONTEND_SESSION_URL: \"http://${API_ALB}\"
  FRONTEND_GAME_URL: \"http://${NLB_ADDRESS}:8083\"
"
    
    log_info "重啟服務以載入新配置..."
    kubectl rollout restart deployment/client-service -n fish-game-system
    kubectl rollout restart deployment/game-session-service -n fish-game-system
    kubectl rollout restart deployment/game-server-service -n fish-game-system
    
    # 等待重啟完成
    kubectl rollout status deployment/client-service -n fish-game-system
    kubectl rollout status deployment/game-session-service -n fish-game-system
    kubectl rollout status deployment/game-server-service -n fish-game-system
    
    log_success "ConfigMap 配置更新完成"
}

# 驗證部署
verify_deployment() {
    log_step "驗證部署狀態"
    
    # 獲取地址
    CLIENT_ALB=$(kubectl get ingress client-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    API_ALB=$(kubectl get ingress api-ingress -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    NLB_ADDRESS=$(kubectl get service game-server-nlb -n fish-game-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    # 檢查 Pod 狀態
    log_info "檢查 Pod 狀態："
    kubectl get pods -n fish-game-system
    
    # 測試健康檢查
    log_info "測試服務健康檢查..."
    
    # 測試 API 健康檢查
    if curl -f -s http://${API_ALB}/api/health > /dev/null; then
        log_success "API 服務健康檢查通過"
    else
        log_warning "API 服務健康檢查失敗，可能需要等待更長時間"
    fi
    
    # 測試 NLB 健康檢查
    if curl -f -s http://${NLB_ADDRESS}:8083/health > /dev/null; then
        log_success "遊戲服務健康檢查通過"
    else
        log_warning "遊戲服務健康檢查失敗，可能需要等待更長時間"
    fi
    
    # 顯示訪問地址
    echo ""
    log_success "🎉 部署完成！你的遊戲已經可以訪問："
    echo ""
    echo "🎮 遊戲主頁面: http://${CLIENT_ALB}"
    echo "🔧 API 服務:   http://${API_ALB}"
    echo "🎯 WebSocket:  http://${NLB_ADDRESS}:8083"
    echo ""
    echo "📋 快速測試命令："
    echo "curl -I http://${CLIENT_ALB}/"
    echo "curl -I http://${API_ALB}/api/health"
    echo "curl -I http://${NLB_ADDRESS}:8083/health"
}

# 主函數
main() {
    echo "🚀 開始執行 EKS 服務一鍵部署"
    echo "=================================="
    
    check_prerequisites
    deploy_resources
    wait_for_load_balancers
    update_configmap
    verify_deployment
    
    echo ""
    log_success "🎉 一鍵部署完成！"
    echo ""
    log_info "如果遇到問題，請查看 README.md 中的故障排除指南"
    log_info "或執行 './cleanup.sh' 清除所有資源後重新部署"
}

# 執行主函數
main "$@"