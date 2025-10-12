#!/bin/bash

# 電子捕魚機微服務系統 - 開發環境啟動腳本

echo "🐟 啟動電子捕魚機微服務系統..."

# 檢查 Docker 是否運行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未運行，請先啟動 Docker"
    exit 1
fi

# 檢查 .env 文件是否存在
if [ ! -f .env ]; then
    echo "❌ .env 文件不存在，請先創建環境變數配置"
    exit 1
fi

# 停止並移除現有容器
echo "🧹 清理現有容器..."
docker-compose down

# 構建並啟動服務
echo "🚀 構建並啟動服務..."
docker-compose up --build -d

# 等待服務啟動
echo "⏳ 等待服務啟動..."
sleep 10

# 檢查服務狀態
echo "📊 檢查服務狀態..."
docker-compose ps

echo ""
echo "🎉 電子捕魚機微服務系統啟動完成！"
echo ""
echo "🌐 系統入口："
echo "   📋 系統總覽: file://$(pwd)/index.html"
echo ""
echo "🎮 前端服務："
echo "   🐟 遊戲客戶端: http://localhost:8080"
echo "   ⚙️ 管理控制台: http://localhost:8081"
echo ""
echo "🔧 後端服務管理："
echo "   🎯 遊戲會話服務: http://localhost:8082/admin"
echo "   🎮 遊戲伺服器服務: http://localhost:8083/admin"
echo ""
echo "🧪 測試服務: ./test-services.sh"
echo "📝 查看日誌: docker-compose logs -f"
echo "🛑 停止服務: docker-compose down"