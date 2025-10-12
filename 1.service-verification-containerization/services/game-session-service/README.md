# Game Session Service - 遊戲會話服務

## 📋 服務概述

Game Session Service 是魚機遊戲的會話管理服務，整合用戶管理、錢包系統、大廳管理和配桌功能。

### 🎯 主要功能
- 用戶註冊和登入管理
- 錢包餘額管理和交易
- 遊戲房間創建和管理
- 玩家配桌和房間分配
- 管理後台界面

### 🔧 技術規格
- **框架**: Express.js + EJS 模板引擎
- **端口**: 8082
- **Node.js 版本**: 18+
- **數據存儲**: 內存存儲 (開發用)
- **容器化**: Docker 支援

## 📁 檔案結構

```
game-session-service/
├── app.js              # 主要應用程式
├── package.json        # 依賴項配置
├── Dockerfile         # Docker 容器配置
├── views/             # EJS 模板目錄
│   └── admin.ejs      # 管理後台模板
└── README.md          # 本文檔
```

## 🚀 本地開發

### 前置需求
- Node.js 18+
- npm 或 yarn

### 安裝依賴
```bash
cd services/game-session-service
npm install
```

### 啟動服務
```bash
# 開發模式
npm run dev

# 生產模式
npm start
```

### 環境變數
```bash
SERVICE_PORT=8082        # 服務端口
JWT_SECRET=your-secret   # JWT 密鑰
REDIS_HOST=redis         # Redis 主機
REDIS_PORT=6379          # Redis 端口
NODE_ENV=development     # 環境模式
```

## 🐳 Docker 使用

### 構建容器
```bash
docker build -t game-session-service .
```

### 運行容器
```bash
docker run -p 8082:8082 \
  -e JWT_SECRET=your-secret \
  -e REDIS_HOST=redis \
  -e REDIS_PORT=6379 \
  game-session-service
```

## 🔍 API 端點

### 健康檢查
```http
GET /health
```

### 用戶管理 API

#### 用戶註冊
```http
POST /api/v1/users/register
Content-Type: application/json

{
  "username": "player1",
  "password": "password123"
}
```

#### 用戶登入
```http
POST /api/v1/users/login
Content-Type: application/json

{
  "username": "player1",
  "password": "password123"
}
```

### 錢包管理 API

#### 查詢餘額
```http
GET /api/v1/wallet/balance/:userId
```

#### 更新餘額 (內部 API)
```http
POST /api/v1/wallet/update-balance
Content-Type: application/json

{
  "userId": "user_123456789",
  "balance": 1500.00
}
```

### 大廳管理 API

#### 獲取房間列表
```http
GET /api/v1/lobby/rooms
```

#### 創建房間
```http
POST /api/v1/lobby/rooms/create
Content-Type: application/json

{
  "name": "我的房間",
  "maxPlayers": 4
}
```

#### 加入房間
```http
POST /api/v1/lobby/rooms/:roomId/join
Content-Type: application/json

{
  "userId": "user_123456789",
  "username": "player1"
}
```

#### 離開房間
```http
POST /api/v1/lobby/rooms/:roomId/leave
Content-Type: application/json

{
  "userId": "user_123456789"
}
```

### 配桌管理 API

#### 尋找合適房間
```http
POST /api/v1/matching/find-room
Content-Type: application/json

{
  "userId": "user_123456789",
  "nickname": "player1",
  "balance": 1000.00
}
```

## 🎛️ 管理後台

### 訪問管理後台
```
http://localhost:8082/admin
```

### 管理功能
- 用戶管理 (查看、刪除、修改密碼、調整餘額)
- 房間管理 (查看、刪除、清空)
- 系統狀態監控

### 管理 API

#### 獲取用戶列表
```http
GET /admin/users
```

#### 刪除用戶
```http
POST /admin/delete-user
Content-Type: application/json

{
  "username": "player1"
}
```

#### 清空所有房間
```http
POST /admin/clear-rooms
```

## ✅ 服務驗證

### 1. 健康檢查測試
```bash
curl http://localhost:8082/health
```

### 2. 用戶註冊測試
```bash
curl -X POST http://localhost:8082/api/v1/users/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}'
```

### 3. 用戶登入測試
```bash
curl -X POST http://localhost:8082/api/v1/users/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}'
```

### 4. 房間管理測試
```bash
# 創建房間
curl -X POST http://localhost:8082/api/v1/lobby/rooms/create \
  -H "Content-Type: application/json" \
  -d '{"name":"測試房間","maxPlayers":4}'

# 獲取房間列表
curl http://localhost:8082/api/v1/lobby/rooms
```

### 5. 管理後台測試
在瀏覽器中訪問 `http://localhost:8082/admin`

## 🔧 故障排除

### 常見問題

#### 1. 端口被占用
```bash
netstat -tulpn | grep :8082
```

#### 2. EJS 模板錯誤
- 檢查 `views/admin.ejs` 文件是否存在
- 確認模板語法正確

#### 3. 內存數據丟失
- 服務重啟後內存數據會清空
- 生產環境建議使用 Redis 或數據庫

#### 4. CORS 問題
服務已配置 CORS 中間件，支援跨域請求。

## 📊 數據模型

### 用戶數據結構
```javascript
{
  userId: "user_1234567890",
  username: "player1",
  password: "hashed_password",
  balance: 1000.00,
  createdAt: Date,
  updatedAt: Date
}
```

### 房間數據結構
```javascript
{
  id: "room_1234567890",
  name: "房間名稱",
  maxPlayers: 4,
  players: [
    {
      userId: "user_123",
      username: "player1",
      joinedAt: Date
    }
  ],
  status: "waiting|playing|finished",
  createdAt: Date
}
```

## 🔗 相關服務

- **Client Service** (8080): 遊戲客戶端界面
- **Game Server Service** (8083): 遊戲邏輯和 WebSocket 通信

## 📝 開發注意事項

1. **內存存儲**: 當前使用 Map 進行內存存儲，重啟後數據會丟失
2. **密碼安全**: 生產環境應對密碼進行加密處理
3. **JWT 實現**: 當前為簡化實現，生產環境需要完整的 JWT 驗證
4. **錯誤處理**: 所有 API 都有適當的錯誤處理和狀態碼
5. **日誌記錄**: 重要操作都有詳細的日誌記錄