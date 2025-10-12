# Client Service - 遊戲客戶端服務

## 📋 服務概述

Client Service 是魚機遊戲的前端服務，負責提供遊戲客戶端界面和靜態資源服務。

### 🎯 主要功能
- 提供遊戲客戶端 HTML/JS/CSS 靜態資源
- 支援環境變數配置注入
- 健康檢查端點
- 404 錯誤處理

### 🔧 技術規格
- **框架**: Express.js
- **端口**: 8080
- **Node.js 版本**: 18+
- **容器化**: Docker 支援

## 📁 檔案結構

```
client-service/
├── app.js              # 主要應用程式
├── package.json        # 依賴項配置
├── Dockerfile         # Docker 容器配置
├── public/            # 靜態資源目錄
│   └── index.html     # 遊戲客戶端頁面
└── README.md          # 本文檔
```

## 🚀 本地開發

### 前置需求
- Node.js 18+
- npm 或 yarn

### 安裝依賴
```bash
cd services/client-service
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
SERVICE_PORT=8080                    # 服務端口
GAME_SESSION_SERVICE_HOST=localhost  # 會話服務主機
GAME_SESSION_SERVICE_PORT=8082      # 會話服務端口
GAME_SERVER_SERVICE_HOST=localhost  # 遊戲服務主機
GAME_SERVER_SERVICE_PORT=8083       # 遊戲服務端口
```

## 🐳 Docker 使用

### 構建容器
```bash
docker build -t client-service .
```

### 運行容器
```bash
docker run -p 8080:8080 \
  -e GAME_SESSION_SERVICE_HOST=game-session-service \
  -e GAME_SESSION_SERVICE_PORT=8082 \
  -e GAME_SERVER_SERVICE_HOST=game-server-service \
  -e GAME_SERVER_SERVICE_PORT=8083 \
  client-service
```

## 🔍 API 端點

### 健康檢查
```http
GET /health
```

**回應範例:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "service": "client-service",
  "version": "1.0.0"
}
```

### 遊戲客戶端
```http
GET /
```
提供遊戲客戶端 HTML 頁面，支援配置注入。

### 靜態資源
```http
GET /static/*
```
提供靜態資源文件（CSS、JS、圖片等）。

## ✅ 服務驗證

### 1. 健康檢查測試
```bash
curl http://localhost:8080/health
```

### 2. 客戶端頁面測試
```bash
curl http://localhost:8080/
```

### 3. 靜態資源測試
在瀏覽器中訪問 `http://localhost:8080` 檢查頁面是否正常載入。

## 🔧 故障排除

### 常見問題

#### 1. 端口被占用
```bash
# 檢查端口使用情況
netstat -tulpn | grep :8080

# 或使用 lsof (macOS/Linux)
lsof -i :8080
```

#### 2. 靜態資源載入失敗
- 檢查 `public/` 目錄是否存在
- 確認 `index.html` 文件存在
- 檢查文件權限

#### 3. 環境變數配置問題
```bash
# 檢查環境變數
echo $GAME_SESSION_SERVICE_HOST
echo $GAME_SESSION_SERVICE_PORT
```

## 📊 監控和日誌

### 日誌格式
```
[2024-01-01T00:00:00.000Z] Client Service started on port 8080
[2024-01-01T00:00:00.000Z] Game client: http://localhost:8080
[2024-01-01T00:00:00.000Z] Health check: http://localhost:8080/health
```

### 監控指標
- 服務啟動時間
- HTTP 請求響應時間
- 靜態資源載入成功率
- 健康檢查狀態

## 🔗 相關服務

- **Game Session Service** (8082): 遊戲會話管理
- **Game Server Service** (8083): 遊戲邏輯和 WebSocket 通信

## 📝 開發注意事項

1. **配置注入**: 服務支援動態配置注入，可在運行時替換 API 端點
2. **靜態資源**: 所有靜態資源應放在 `public/` 目錄下
3. **錯誤處理**: 404 錯誤會返回 JSON 格式的錯誤訊息
4. **健康檢查**: 容器健康檢查依賴 `/health` 端點