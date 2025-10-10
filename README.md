# 🐟 電子捕魚機微服務系統

基於 Docker Compose 的電子捕魚機遊戲微服務架構，支援即時多人遊戲、智能配桌和完整的管理後台。

## 🏗️ 系統架構

```
┌─────────────────┐    ┌─────────────────┐
│  遊戲會話服務    │    │  遊戲伺服器服務  │
│   :8082        │    │   :8083        │
│                │    │                │
│ • 用戶管理      │    │ • 遊戲邏輯      │
│ • 錢包管理      │    │ • 碰撞檢測      │
│ • 大廳管理      │    │ • WebSocket    │
│ • 智能配桌      │    │ • Web 管理後台  │
│ • Web 管理後台  │    │                │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
        ┌─────────────────┐
        │  Redis 數據庫   │
        │   :6379        │
        │                │
        │ • 內存存儲      │
        │ • 不持久化      │
        └─────────────────┘
```

## 🚀 快速開始

### 前置需求

- Docker 20.10+
- Docker Compose 2.0+

### 啟動系統

```bash
# 克隆項目
git clone <repository-url>
cd fish-game-microservices

# 啟動開發環境
./scripts/start-dev.sh
```

### 停止系統

```bash
./scripts/stop-dev.sh
```

## 📱 服務訪問

| 服務 | 地址 | 管理後台 | 說明 |
|------|------|----------|------|
| 🎮 遊戲客戶端服務 | http://localhost:8080 | - | 玩家遊戲界面 |
| 🎯 遊戲會話服務 | http://localhost:8082 | http://localhost:8082/admin | 用戶管理、錢包管理、大廳管理、智能配桌 |
| 🎮 遊戲伺服器服務 | http://localhost:8083 | http://localhost:8083/admin | 遊戲邏輯、碰撞檢測、即時通訊 |
| 💾 Redis 數據庫 | localhost:6379 | - | 內存數據存儲 |

## 🔧 開發指南

### 項目結構

```
fish-game-microservices/
├── services/                    # 微服務目錄
│   ├── client-service/          # 遊戲客戶端服務
│   │   ├── app.js              # 單一應用程式文件
│   │   ├── package.json        # 依賴配置
│   │   ├── Dockerfile          # 容器配置
│   │   └── public/             # 靜態文件
│   │       └── index.html      # 遊戲界面
│   ├── game-session-service/    # 遊戲會話服務 (主要服務)
│   │   ├── app.js              # 單一應用程式文件
│   │   ├── package.json        # 依賴配置
│   │   ├── Dockerfile          # 容器配置
│   │   └── views/              # EJS 模板
│   ├── game-server-service/     # 遊戲伺服器服務 (遊戲引擎)
│   │   ├── app.js              # 單一應用程式文件
│   │   ├── package.json        # 依賴配置
│   │   ├── Dockerfile          # 容器配置
│   │   └── views/              # EJS 模板
│   └── shared/                  # 共用代碼 (如需要)
├── scripts/                     # 腳本文件
├── index.html                   # 系統入口頁面
├── docker-compose.yml           # Docker Compose 配置
├── test-services.sh            # 服務測試腳本
├── .env                        # 環境變數
└── README.md                   # 項目說明
```

### 環境變數配置

主要環境變數在 `.env` 文件中配置：

- `JWT_SECRET`: JWT 密鑰
- `REDIS_HOST`: Redis 主機地址
- `GAME_*`: 遊戲相關配置
- `FISH_*`: 魚類和機率配置

### 日誌查看

```bash
# 查看所有服務日誌
docker-compose logs -f

# 查看特定服務日誌
docker-compose logs -f game-session-service
docker-compose logs -f game-server-service
```

## 🎮 遊戲功能

### 核心功能

- ✅ 用戶註冊和登入
- ✅ 錢包餘額管理
- ✅ 智能配桌系統
- ✅ 即時多人遊戲
- ✅ 魚群生成和移動
- ✅ 碰撞檢測和派彩
- ✅ WebSocket 即時通訊

### 管理功能

- ✅ 用戶管理和監控
- ✅ 錢包餘額調整
- ✅ 房間狀態監控
- ✅ 配桌規則調整
- ✅ 遊戲參數配置
- ✅ 即時數據分析

## 🚢 部署到 EKS

詳細的 EKS 部署指南請參考：[EKS 部署文檔](docs/eks-deployment.md)

### 主要步驟

1. 創建 EKS 集群
2. 配置 kubectl
3. 部署 Redis
4. 部署微服務
5. 配置 Ingress
6. 設置監控

## 🤝 貢獻指南

1. Fork 項目
2. 創建功能分支
3. 提交更改
4. 推送到分支
5. 創建 Pull Request

## 📄 許可證

MIT License

## 🆘 支援

如有問題，請創建 Issue 或聯繫開發團隊。