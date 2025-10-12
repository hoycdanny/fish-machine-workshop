# Game Server Service - 遊戲伺服器服務

## 📋 服務概述

Game Server Service 是魚機遊戲的核心遊戲邏輯服務，負責處理遊戲邏輯、碰撞檢測、WebSocket 即時通訊和遊戲統計。

### 🎯 主要功能
- 遊戲邏輯處理和狀態管理
- WebSocket 即時通訊
- 碰撞檢測和物理模擬
- 遊戲統計和配置管理
- 魚群生成和移動
- 子彈軌跡和碰撞計算
- 管理後台和監控

### 🔧 技術規格
- **框架**: Express.js + Socket.IO + EJS
- **端口**: 8083
- **Node.js 版本**: 18+
- **WebSocket**: Socket.IO 4.7.2
- **數據庫**: Redis 4.6.0
- **容器化**: Docker 支援

## 📁 檔案結構

```
game-server-service/
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
- Redis 服務器
- npm 或 yarn

### 安裝依賴
```bash
cd services/game-server-service
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
SERVICE_PORT=8083                    # 服務端口
REDIS_HOST=redis                     # Redis 主機
REDIS_PORT=6379                      # Redis 端口
GAME_SESSION_SERVICE_HOST=game-session-service  # 會話服務主機
GAME_SESSION_SERVICE_PORT=8082       # 會話服務端口
GAME_ROOM_MAX_PLAYERS=4             # 房間最大玩家數
GAME_FISH_SPAWN_INTERVAL=2000       # 魚群生成間隔 (毫秒)
NODE_ENV=development                 # 環境模式
```

## 🐳 Docker 使用

### 構建容器
```bash
docker build -t game-server-service .
```

### 運行容器
```bash
docker run -p 8083:8083 \
  -e REDIS_HOST=redis \
  -e REDIS_PORT=6379 \
  -e GAME_SESSION_SERVICE_HOST=game-session-service \
  -e GAME_SESSION_SERVICE_PORT=8082 \
  game-server-service
```

## 🔍 HTTP API 端點

### 健康檢查
```http
GET /health
```

### 遊戲邏輯 API

#### 開始遊戲
```http
POST /api/v1/game/start
Content-Type: application/json

{
  "roomId": "room_123456789",
  "userId": "user_123456789"
}
```

#### 射擊
```http
POST /api/v1/game/shoot
Content-Type: application/json

{
  "roomId": "room_123456789",
  "userId": "user_123456789",
  "x": 700,
  "y": 600,
  "targetX": 400,
  "targetY": 300
}
```

#### 碰撞檢測
```http
POST /api/v1/collision/detect
Content-Type: application/json

{
  "bulletId": "bullet_123456789",
  "fishId": "fish_123456789",
  "roomId": "room_123456789"
}
```

#### 獲取房間遊戲狀態
```http
GET /api/v1/game/room/:roomId/state
```

### 管理 API

#### 獲取即時統計
```http
GET /admin/api/stats
```

#### 獲取遊戲配置
```http
GET /admin/api/config
```

#### 更新遊戲配置
```http
POST /admin/api/config/update
Content-Type: application/json

{
  "fishSpawnInterval": 1500,
  "bulletSpeed": 400,
  "hitRate": 0.7
}
```

## 🌐 WebSocket 事件

### 客戶端 → 服務器

#### 加入房間
```javascript
socket.emit('join-room', {
  roomId: 'room_123456789',
  userId: 'user_123456789',
  username: 'player1',
  balance: 1000.00
});
```

#### 離開房間
```javascript
socket.emit('leave-room', {
  roomId: 'room_123456789',
  userId: 'user_123456789'
});
```

#### 發射子彈
```javascript
socket.emit('fire-bullet', {
  roomId: 'room_123456789',
  userId: 'user_123456789',
  x: 700,
  y: 600,
  targetX: 400,
  targetY: 300,
  gameAreaWidth: 1400,
  gameAreaHeight: 700
});
```

#### 玩家移動
```javascript
socket.emit('player-move', {
  roomId: 'room_123456789',
  userId: 'user_123456789',
  x: 500,
  y: 550
});
```

#### 開始遊戲
```javascript
socket.emit('start-game', {
  roomId: 'room_123456789'
});
```

### 服務器 → 客戶端

#### 加入房間成功
```javascript
socket.on('joined-room', (data) => {
  // data: { roomId, userId, gameState }
});
```

#### 玩家加入通知
```javascript
socket.on('player-joined', (data) => {
  // data: { playerId, username, player }
});
```

#### 玩家離開通知
```javascript
socket.on('player-left', (data) => {
  // data: { playerId }
});
```

#### 子彈發射
```javascript
socket.on('bullet-fired', (bullet) => {
  // bullet: { id, playerId, startX, startY, targetX, targetY, speed }
});
```

#### 子彈移動
```javascript
socket.on('bullet-moved', (data) => {
  // data: { bulletId, x, y }
});
```

#### 魚群生成
```javascript
socket.on('fish-spawned', (fish) => {
  // fish: { id, type, value, size, x, y, speed }
});
```

#### 魚群移動
```javascript
socket.on('fish-moved', (data) => {
  // data: { fishId, x, y }
});
```

#### 碰撞命中
```javascript
socket.on('collision-hit', (data) => {
  // data: { bulletId, fishId, playerId, reward, newScore, newBalance }
});
```

#### 餘額更新
```javascript
socket.on('balance-updated', (data) => {
  // data: { balance, change, reason }
});
```

#### 遊戲開始
```javascript
socket.on('game-started', (data) => {
  // data: { roomId, startTime }
});
```

## 🎛️ 管理後台

### 訪問管理後台
```
http://localhost:8083/admin
```

### 監控功能
- 即時連接數統計
- 活躍房間數量
- 魚群和子彈數量
- 今日碰撞統計
- 命中率分析
- 總派彩金額

### 配置管理
- 魚群生成間隔調整 (100-5000ms)
- 子彈速度調整 (300-800px/s)
- 命中率調整 (10%-100%)

## ✅ 服務驗證

### 1. 健康檢查測試
```bash
curl http://localhost:8083/health
```

### 2. 遊戲開始測試
```bash
curl -X POST http://localhost:8083/api/v1/game/start \
  -H "Content-Type: application/json" \
  -d '{"roomId":"test_room","userId":"test_user"}'
```

### 3. WebSocket 連接測試
```javascript
// 使用瀏覽器控制台或 Node.js
const io = require('socket.io-client');
const socket = io('http://localhost:8083');

socket.on('connect', () => {
  console.log('Connected to game server');
  
  socket.emit('join-room', {
    roomId: 'test_room',
    userId: 'test_user',
    username: 'tester',
    balance: 1000
  });
});
```

### 4. 管理後台測試
在瀏覽器中訪問 `http://localhost:8083/admin`

## 🎮 遊戲機制

### 魚群系統
- **魚類型**: 小魚 (2分)、中魚 (5分)、大魚 (10分)、Boss魚 (20分)
- **生成機制**: 每2秒隨機生成，房間最多10條魚
- **移動邏輯**: 60FPS 更新，邊界反彈
- **碰撞檢測**: 基於魚的大小計算碰撞半徑

### 子彈系統
- **發射機制**: 從螢幕底部中央發射
- **軌跡計算**: 直線軌跡，300px/s 速度
- **碰撞檢測**: 實時檢測與魚群的碰撞
- **消耗機制**: 每發子彈消耗1點餘額

### 積分系統
- **命中獎勵**: 根據魚類型給予不同積分
- **餘額同步**: 自動同步到會話服務
- **統計記錄**: Redis 記錄遊戲統計數據

## 🔧 故障排除

### 常見問題

#### 1. Redis 連接失敗
```bash
# 檢查 Redis 服務狀態
redis-cli ping

# 檢查 Redis 連接配置
echo $REDIS_HOST
echo $REDIS_PORT
```

#### 2. WebSocket 連接問題
- 檢查防火牆設置
- 確認端口 8083 可訪問
- 檢查 CORS 配置

#### 3. 遊戲邏輯異常
- 檢查房間初始化
- 確認玩家餘額充足
- 檢查魚群生成邏輯

#### 4. 統計數據異常
- 檢查 Redis 連接
- 確認統計收集器初始化
- 檢查日期格式

## 📊 效能監控

### 關鍵指標
- WebSocket 連接數
- 房間活躍度
- 魚群密度
- 子彈軌跡計算效能
- Redis 操作延遲

### 效能優化
- 60FPS 遊戲循環優化
- 記憶體使用監控
- 垃圾回收優化
- Redis 連接池管理

## 🔗 相關服務

- **Client Service** (8080): 遊戲客戶端界面
- **Game Session Service** (8082): 用戶和房間管理
- **Redis**: 數據存儲和統計

## 📝 開發注意事項

1. **WebSocket 管理**: 正確處理連接、斷線和重連
2. **遊戲狀態**: 確保房間狀態的一致性
3. **效能優化**: 60FPS 更新需要高效的計算
4. **錯誤處理**: WebSocket 和 HTTP 的錯誤處理
5. **資源清理**: 及時清理無效的房間和連接