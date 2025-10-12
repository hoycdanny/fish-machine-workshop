#!/bin/bash

# 電子捕魚機微服務系統 - 停止腳本

echo "🛑 停止電子捕魚機微服務系統..."

# 停止並移除容器
docker-compose down

# 清理未使用的映像（可選）
read -p "是否清理未使用的 Docker 映像？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧹 清理未使用的映像..."
    docker image prune -f
fi

echo "✅ 系統已停止"