#!/bin/bash

# 開發環境設置腳本
# 用於初始化和配置開發環境

echo "🚀 魚機遊戲微服務開發環境設置"
echo "================================"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查必要工具
check_requirements() {
    echo -e "${BLUE}🔍 檢查系統需求...${NC}"
    
    # 檢查 Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker 已安裝: $(docker --version)${NC}"
    else
        echo -e "${RED}❌ Docker 未安裝，請先安裝 Docker${NC}"
        exit 1
    fi
    
    # 檢查 Docker Compose
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✅ Docker Compose 已安裝: $(docker-compose --version)${NC}"
    else
        echo -e "${RED}❌ Docker Compose 未安裝，請先安裝 Docker Compose${NC}"
        exit 1
    fi
    
    # 檢查 curl
    if command -v curl &> /dev/null; then
        echo -e "${GREEN}✅ curl 已安裝${NC}"
    else
        echo -e "${YELLOW}⚠️  curl 未安裝，部分測試功能可能無法使用${NC}"
    fi
    
    echo ""
}

# 檢查端口占用
check_ports() {
    echo -e "${BLUE}🔌 檢查端口占用...${NC}"
    
    ports=(6379 8080 8082 8083)
    port_names=("Redis" "Client Service" "Game Session Service" "Game Server Service")
    
    for i in "${!ports[@]}"; do
        port=${ports[$i]}
        name=${port_names[$i]}
        
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  端口 $port ($name) 已被占用${NC}"
            echo "   使用以下命令查看占用進程: lsof -i :$port"
        else
            echo -e "${GREEN}✅ 端口 $port ($name) 可用${NC}"
        fi
    done
    
    echo ""
}

# 創建必要目錄
create_directories() {
    echo -e "${BLUE}📁 創建必要目錄...${NC}"
    
    directories=(
        "logs"
        "data/redis"
        "tmp"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo -e "${GREEN}✅ 創建目錄: $dir${NC}"
        else
            echo -e "${YELLOW}📁 目錄已存在: $dir${NC}"
        fi
    done
    
    echo ""
}

# 設置環境變數
setup_environment() {
    echo -e "${BLUE}⚙️  檢查環境變數配置...${NC}"
    
    if [ -f ".env" ]; then
        echo -e "${GREEN}✅ .env 文件已存在${NC}"
        echo "當前配置:"
        cat .env | grep -E "^[A-Z_]+" | head -5
        echo "..."
    else
        echo -e "${YELLOW}⚠️  .env 文件不存在，請確認配置${NC}"
    fi
    
    echo ""
}

# 構建 Docker 映像
build_images() {
    echo -e "${BLUE}🐳 構建 Docker 映像...${NC}"
    
    echo "這可能需要幾分鐘時間..."
    
    if docker-compose build --no-cache; then
        echo -e "${GREEN}✅ Docker 映像構建成功${NC}"
    else
        echo -e "${RED}❌ Docker 映像構建失敗${NC}"
        exit 1
    fi
    
    echo ""
}

# 啟動服務
start_services() {
    echo -e "${BLUE}🚀 啟動微服務...${NC}"
    
    echo "啟動所有服務..."
    if docker-compose up -d; then
        echo -e "${GREEN}✅ 服務啟動成功${NC}"
        
        echo "等待服務初始化..."
        sleep 15
        
        echo "檢查服務狀態:"
        docker-compose ps
    else
        echo -e "${RED}❌ 服務啟動失敗${NC}"
        exit 1
    fi
    
    echo ""
}

# 驗證服務
verify_services() {
    echo -e "${BLUE}🔍 驗證服務狀態...${NC}"
    
    if [ -f "scripts/verify-services.sh" ]; then
        chmod +x scripts/verify-services.sh
        ./scripts/verify-services.sh
    else
        echo -e "${YELLOW}⚠️  驗證腳本不存在，手動檢查服務${NC}"
        
        services=("http://localhost:8080/health" "http://localhost:8082/health" "http://localhost:8083/health")
        service_names=("Client Service" "Game Session Service" "Game Server Service")
        
        for i in "${!services[@]}"; do
            url=${services[$i]}
            name=${service_names[$i]}
            
            echo -n "檢查 $name... "
            if curl -s "$url" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ 正常${NC}"
            else
                echo -e "${RED}❌ 異常${NC}"
            fi
        done
    fi
    
    echo ""
}

# 顯示開發信息
show_dev_info() {
    echo -e "${BLUE}📋 開發環境信息${NC}"
    echo "===================="
    echo ""
    echo -e "${GREEN}🌐 服務訪問地址:${NC}"
    echo "   🎮 遊戲客戶端:     http://localhost:8080"
    echo "   🎯 會話管理後台:   http://localhost:8082/admin"
    echo "   🎮 遊戲監控後台:   http://localhost:8083/admin"
    echo "   💾 Redis:         localhost:6379"
    echo ""
    echo -e "${GREEN}🛠️  常用開發命令:${NC}"
    echo "   查看服務狀態:     docker-compose ps"
    echo "   查看服務日誌:     docker-compose logs [service-name]"
    echo "   重啟服務:         docker-compose restart [service-name]"
    echo "   停止所有服務:     docker-compose down"
    echo "   重新構建:         docker-compose build --no-cache"
    echo ""
    echo -e "${GREEN}🧪 測試腳本:${NC}"
    echo "   服務驗證:         ./scripts/verify-services.sh"
    echo "   API 測試:         ./scripts/test-apis.sh"
    echo "   啟動開發環境:     ./scripts/start-dev.sh"
    echo "   停止開發環境:     ./scripts/stop-dev.sh"
    echo ""
    echo -e "${GREEN}📁 重要目錄:${NC}"
    echo "   服務代碼:         ./services/"
    echo "   Docker 配置:      ./docker-compose.yml"
    echo "   環境變數:         ./.env"
    echo "   基礎設施:         ./infrastructure/"
    echo "   開發腳本:         ./scripts/"
    echo ""
    echo -e "${YELLOW}💡 開發提示:${NC}"
    echo "   1. 修改代碼後使用 docker-compose restart [service] 重啟服務"
    echo "   2. 查看實時日誌: docker-compose logs -f [service]"
    echo "   3. 進入容器調試: docker-compose exec [service] sh"
    echo "   4. 清理數據: docker-compose down -v"
    echo ""
}

# 主執行流程
main() {
    echo "開始設置開發環境..."
    echo ""
    
    # 檢查是否在正確的目錄
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}❌ 請在專案根目錄執行此腳本${NC}"
        exit 1
    fi
    
    check_requirements
    check_ports
    create_directories
    setup_environment
    
    # 詢問是否構建映像
    echo -n "是否要構建 Docker 映像? (y/N): "
    read -r build_choice
    if [[ $build_choice =~ ^[Yy]$ ]]; then
        build_images
    fi
    
    # 詢問是否啟動服務
    echo -n "是否要啟動所有服務? (y/N): "
    read -r start_choice
    if [[ $start_choice =~ ^[Yy]$ ]]; then
        start_services
        verify_services
    fi
    
    show_dev_info
    
    echo -e "${GREEN}🎉 開發環境設置完成！${NC}"
}

# 執行主函數
main "$@"