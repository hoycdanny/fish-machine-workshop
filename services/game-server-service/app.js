const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const path = require('path');
const axios = require('axios');
const redis = require('redis');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.SERVICE_PORT || 8083;

// Redis 客戶端設置 - 修復連接配置
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'redis',
    port: process.env.REDIS_PORT || 6379
  }
});

redisClient.on('error', (err) => {
  console.error(`[${new Date().toISOString()}] Redis Client Error:`, err);
});

redisClient.on('connect', () => {
  console.log(`[${new Date().toISOString()}] Redis Client Connected`);
});

redisClient.on('ready', () => {
  console.log(`[${new Date().toISOString()}] Redis Client Ready`);
});

// 基本中間件
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 設置 EJS 模板引擎
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// 遊戲狀態
let gameState = {
  rooms: {},
  connections: 0
};

// 遊戲統計收集器
class GameStatsCollector {
  constructor(redisClient) {
    this.redis = redisClient;
    this.stats = {
      activeRooms: 0,
      fishCount: 0,
      bulletCount: 0,
      todayCollisions: 0,
      hitRate: 0,
      totalPayout: 0
    };
  }

  // 即時統計數據收集
  async collectStats() {
    try {
      // 活躍房間數量
      const activeRooms = Object.keys(gameState.rooms).filter(roomId =>
        gameState.rooms[roomId].isActive
      ).length;
      this.stats.activeRooms = activeRooms;

      // 魚群總數量
      let totalFish = 0;
      for (const roomId in gameState.rooms) {
        if (gameState.rooms[roomId].fishes) {
          totalFish += Object.keys(gameState.rooms[roomId].fishes).length;
        }
      }
      this.stats.fishCount = totalFish;

      // 子彈總數量
      let totalBullets = 0;
      for (const roomId in gameState.rooms) {
        if (gameState.rooms[roomId].bullets) {
          totalBullets += Object.keys(gameState.rooms[roomId].bullets).length;
        }
      }
      this.stats.bulletCount = totalBullets;

      // 今日碰撞次數
      const today = new Date().toISOString().split('T')[0];
      const todayCollisions = await this.redis.get(`stats:collisions:${today}`) || 0;
      this.stats.todayCollisions = parseInt(todayCollisions);

      // 命中率計算
      const totalShots = await this.redis.get(`stats:shots:${today}`) || 0;
      const totalHits = await this.redis.get(`stats:hits:${today}`) || 0;
      this.stats.hitRate = totalShots > 0 ? ((totalHits / totalShots) * 100).toFixed(1) : 0;

      // 總派彩
      const totalPayout = await this.redis.get(`stats:payout:${today}`) || 0;
      this.stats.totalPayout = parseFloat(totalPayout).toFixed(2);

      return this.stats;
    } catch (error) {
      console.error(`[${new Date().toISOString()}] Error collecting stats:`, error);
      // 如果 Redis 出錯，返回基本統計
      return {
        activeRooms: Object.keys(gameState.rooms).filter(roomId =>
          gameState.rooms[roomId].isActive
        ).length,
        fishCount: Object.values(gameState.rooms).reduce((total, room) =>
          total + (room.fishes ? Object.keys(room.fishes).length : 0), 0),
        bulletCount: Object.values(gameState.rooms).reduce((total, room) =>
          total + (room.bullets ? Object.keys(room.bullets).length : 0), 0),
        todayCollisions: 0,
        hitRate: 0,
        totalPayout: 0
      };
    }
  }

  // 更新統計數據（當遊戲事件發生時調用）
  async updateStats(eventType, data = {}) {
    try {
      const today = new Date().toISOString().split('T')[0];

      switch (eventType) {
        case 'collision':
          await this.redis.incr(`stats:collisions:${today}`);
          break;
        case 'shot':
          await this.redis.incr(`stats:shots:${today}`);
          break;
        case 'hit':
          await this.redis.incr(`stats:hits:${today}`);
          break;
        case 'payout':
          await this.redis.incrByFloat(`stats:payout:${today}`, data.amount || 0);
          break;
      }
    } catch (error) {
      console.error(`[${new Date().toISOString()}] Error updating stats:`, error);
    }
  }
}

// 遊戲配置管理器
class GameConfigManager {
  constructor(redisClient, io) {
    this.redis = redisClient;
    this.io = io;
    this.config = {
      fishSpawnInterval: 2000,
      bulletSpeed: 500,  // 更新默認值到新範圍內
      hitRate: 0.6
    };
  }

  // 獲取當前配置
  async getConfig() {
    try {
      const config = await this.redis.hGetAll('game:config');
      if (Object.keys(config).length === 0) {
        // 如果 Redis 中沒有配置，返回默認配置
        return this.config;
      }
      return {
        fishSpawnInterval: parseInt(config.fishSpawnInterval) || 2000,
        bulletSpeed: parseInt(config.bulletSpeed) || 500,  // 更新默認值
        hitRate: parseFloat(config.hitRate) || 0.6
      };
    } catch (error) {
      console.error(`[${new Date().toISOString()}] Error getting config:`, error);
      return this.config;
    }
  }

  // 更新配置
  async updateConfig(configKey, value) {
    try {
      // 驗證配置值
      if (!this.validateConfig(configKey, value)) {
        throw new Error(`Invalid config value: ${configKey} = ${value}`);
      }

      // 更新 Redis 中的配置
      await this.redis.hSet('game:config', configKey, value);

      // 更新本地配置
      this.config[configKey] = value;

      // 廣播配置變更到所有遊戲房間
      this.io.emit('config-update', {
        key: configKey,
        value: value,
        timestamp: new Date().toISOString()
      });

      // 記錄配置變更日誌
      console.log(`[${new Date().toISOString()}] Config updated: ${configKey} = ${value}`);

      return true;
    } catch (error) {
      console.error(`[${new Date().toISOString()}] Error updating config:`, error);
      throw error;
    }
  }

  // 配置驗證
  validateConfig(key, value) {
    const validations = {
      fishSpawnInterval: (v) => v >= 100 && v <= 5000, // 0.1-5秒 (100-5000毫秒)
      bulletSpeed: (v) => v >= 300 && v <= 800,        // 300-800px/s
      hitRate: (v) => v >= 0.1 && v <= 1.0             // 10%-100%
    };

    return validations[key] ? validations[key](value) : false;
  }
}

// 初始化統計收集器和配置管理器
let statsCollector;
let configManager;

// 同步餘額到用戶管理系統
async function syncBalanceToUserSystem(userId, newBalance) {
  try {
    const response = await axios.post('http://game-session-service:8082/api/v1/wallet/update-balance', {
      userId: userId,
      balance: newBalance
    });
    console.log(`[${new Date().toISOString()}] Balance synced for user ${userId}: ${newBalance}`);
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Failed to sync balance for user ${userId}:`, error.message);
  }
}

// 同步房間狀態到遊戲會話服務
async function syncRoomStatusToSessionService(roomId, status) {
  try {
    const response = await axios.post('http://game-session-service:8082/api/v1/lobby/rooms/update-status', {
      roomId: roomId,
      status: status
    });
    console.log(`[${new Date().toISOString()}] Room status synced for room ${roomId}: ${status}`);
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Failed to sync room status for room ${roomId}:`, error.message);
  }
}

// 統一的房間初始化函數
function initializeRoom(roomId) {
  if (!gameState.rooms[roomId]) {
    gameState.rooms[roomId] = {
      id: roomId,
      players: {},
      fishes: {},
      bullets: {},
      isActive: false,
      startTime: null,
      gameAreaWidth: 1400,  // 固定遊戲區域寬度
      gameAreaHeight: 700   // 固定遊戲區域高度
    };
    console.log(`[${new Date().toISOString()}] Room ${roomId} initialized with fixed game area: 1400x700`);
  }
  return gameState.rooms[roomId];
}

// 健康檢查端點
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'game-server-service',
    version: '1.0.0',
    connections: gameState.connections
  });
});

// 遊戲邏輯 API
app.post('/api/v1/game/start', (req, res) => {
  const { roomId, userId } = req.body;

  const room = initializeRoom(roomId);

  // 只有在房間未激活時才開始遊戲
  if (!room.isActive) {
    room.isActive = true;
    room.startTime = Date.now();

    // 開始生成魚群
    startFishSpawning(roomId);
  }

  res.json({
    success: true,
    message: '遊戲開始',
    data: {
      gameId: 'game_' + Date.now(),
      roomId: roomId,
      gameState: gameState.rooms[roomId]
    }
  });
});

app.post('/api/v1/game/shoot', (req, res) => {
  const { roomId, userId, x, y, targetX, targetY } = req.body;

  const bulletId = 'bullet_' + Date.now();
  const bullet = {
    id: bulletId,
    playerId: userId,
    startX: x,
    startY: y,
    targetX: targetX,
    targetY: targetY,
    speed: 300,
    createdAt: Date.now(),
    isActive: true
  };

  initializeRoom(roomId);

  gameState.rooms[roomId].bullets[bulletId] = bullet;

  res.json({
    success: true,
    message: '射擊成功',
    data: { bulletId, bullet }
  });
});

// 碰撞檢測 API
app.post('/api/v1/collision/detect', (req, res) => {
  const { bulletId, fishId, roomId } = req.body;

  const room = gameState.rooms[roomId];
  if (!room || !room.bullets[bulletId] || !room.fishes[fishId]) {
    return res.json({
      success: false,
      message: '子彈或魚不存在',
      data: { hit: false, reward: 0 }
    });
  }

  const bullet = room.bullets[bulletId];
  const fish = room.fishes[fishId];

  // 簡單的碰撞檢測邏輯
  const distance = Math.sqrt(
    Math.pow(bullet.targetX - fish.x, 2) +
    Math.pow(bullet.targetY - fish.y, 2)
  );

  const hit = distance < 50; // 50px 碰撞範圍
  let reward = 0;

  if (hit) {
    reward = fish.value || 10;
    // 移除被擊中的魚
    delete room.fishes[fishId];
  }

  // 移除子彈
  delete room.bullets[bulletId];

  res.json({
    success: true,
    message: '碰撞檢測完成',
    data: { hit, reward, fishId, bulletId }
  });
});

// 獲取房間遊戲狀態
app.get('/api/v1/game/room/:roomId/state', (req, res) => {
  const { roomId } = req.params;
  const room = gameState.rooms[roomId];

  if (!room) {
    return res.status(404).json({
      success: false,
      message: '房間不存在'
    });
  }

  res.json({
    success: true,
    data: {
      roomId,
      players: room.players,
      fishes: room.fishes,
      bullets: room.bullets,
      isActive: room.isActive
    }
  });
});

// 魚群生成函數
function startFishSpawning(roomId) {
  const spawnFish = () => {
    const room = gameState.rooms[roomId];
    if (!room || !room.isActive) return;

    const fishId = 'fish_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    const fishTypes = [
      { type: 'small', value: 2, size: 40, speed: 100 },
      { type: 'medium', value: 5, size: 60, speed: 80 },
      { type: 'large', value: 10, size: 80, speed: 60 },
      { type: 'boss', value: 20, size: 120, speed: 40 }
    ];

    const fishType = fishTypes[Math.floor(Math.random() * fishTypes.length)];

    // 使用動態遊戲區域尺寸，如果沒有則使用默認值
    const gameAreaWidth = room.gameAreaWidth || 1400;
    const gameAreaHeight = room.gameAreaHeight || 700;

    const fish = {
      id: fishId,
      roomId: roomId,
      type: fishType.type,
      value: fishType.value,
      size: fishType.size,
      x: Math.random() * gameAreaWidth,
      y: Math.random() * gameAreaHeight,
      directionX: (Math.random() - 0.5) * 2,
      directionY: (Math.random() - 0.5) * 2,
      speed: fishType.speed,
      createdAt: Date.now(),
      isAlive: true
    };

    room.fishes[fishId] = fish;

    console.log(`[${new Date().toISOString()}] Fish ${fishId} spawned in room ${roomId}. Room now has ${Object.keys(room.fishes).length} fishes.`);

    // 廣播新魚給房間內所有玩家
    io.to(roomId).emit('fish-spawned', fish);

    // 魚的移動
    moveFish(roomId, fishId);
  };

  // 每2秒生成一條魚
  const spawnInterval = setInterval(() => {
    const room = gameState.rooms[roomId];
    if (!room || !room.isActive) {
      clearInterval(spawnInterval);
      return;
    }

    // 限制房間內魚的數量
    const fishCount = Object.keys(room.fishes).length;
    if (fishCount < 10) {
      spawnFish();
    }
  }, 2000);
}

// 魚的移動邏輯
function moveFish(roomId, fishId) {
  const moveInterval = setInterval(() => {
    const room = gameState.rooms[roomId];
    if (!room || !room.fishes[fishId]) {
      clearInterval(moveInterval);
      return;
    }

    const fish = room.fishes[fishId];

    // 更新魚的位置
    fish.x += fish.directionX * (fish.speed / 60); // 60 FPS
    fish.y += fish.directionY * (fish.speed / 60);

    // 使用動態遊戲區域尺寸，如果沒有則使用默認值
    const gameAreaWidth = room.gameAreaWidth || 1400;  // 增加默認寬度
    const gameAreaHeight = room.gameAreaHeight || 700; // 增加默認高度

    // 邊界檢測和反彈
    if (fish.x <= 0 || fish.x >= gameAreaWidth) {
      fish.directionX = -fish.directionX;
    }
    if (fish.y <= 0 || fish.y >= gameAreaHeight) {
      fish.directionY = -fish.directionY;
    }

    // 確保魚在邊界內
    fish.x = Math.max(0, Math.min(gameAreaWidth, fish.x));
    fish.y = Math.max(0, Math.min(gameAreaHeight, fish.y));

    // 廣播魚的位置更新
    io.to(roomId).emit('fish-moved', {
      fishId: fishId,
      x: fish.x,
      y: fish.y
    });
  }, 1000 / 60); // 60 FPS
}

// WebSocket 連接處理
io.on('connection', (socket) => {
  gameState.connections++;
  console.log(`[${new Date().toISOString()}] Client connected: ${socket.id}, total: ${gameState.connections}`);

  // 加入房間
  socket.on('join-room', (data) => {
    const { roomId, userId, username, balance } = data;
    console.log(`[${new Date().toISOString()}] Join room data:`, { roomId, userId, username, balance });

    // 先離開之前的房間（如果有的話）
    if (socket.roomId && socket.roomId !== roomId) {
      console.log(`[${new Date().toISOString()}] Player ${userId} leaving previous room ${socket.roomId}`);
      socket.leave(socket.roomId);

      // 從之前的房間中移除玩家
      if (gameState.rooms[socket.roomId] && gameState.rooms[socket.roomId].players[userId]) {
        delete gameState.rooms[socket.roomId].players[userId];
        socket.to(socket.roomId).emit('player-left', { playerId: userId });
      }
    }

    socket.join(roomId);
    socket.userId = userId;
    socket.roomId = roomId;

    // 初始化房間（如果不存在）
    initializeRoom(roomId);

    // 檢查玩家是否已經在房間中
    const isAlreadyInRoom = gameState.rooms[roomId].players[userId];

    if (!isAlreadyInRoom) {
      // 添加玩家到房間
      gameState.rooms[roomId].players[userId] = {
        id: userId,
        username: username || `Player_${userId}`,
        socketId: socket.id,
        roomId: roomId, // 添加房間ID
        x: 500, // 玩家位置
        y: 550,
        score: 0,
        balance: balance || 1000, // 使用前端傳送的餘額
        joinedAt: Date.now()
      };

      // 通知房間內其他玩家有新玩家加入
      socket.to(roomId).emit('player-joined', {
        playerId: userId,
        username: username || `Player_${userId}`,
        player: gameState.rooms[roomId].players[userId]
      });

      console.log(`[${new Date().toISOString()}] User ${userId} joined room ${roomId} (new player)`);
    } else {
      // 更新現有玩家的 socket ID 和房間ID
      gameState.rooms[roomId].players[userId].socketId = socket.id;
      gameState.rooms[roomId].players[userId].roomId = roomId; // 確保房間ID正確
      console.log(`[${new Date().toISOString()}] User ${userId} reconnected to room ${roomId}`);
    }

    // 發送當前遊戲狀態給玩家
    socket.emit('joined-room', {
      roomId,
      userId,
      gameState: gameState.rooms[roomId]
    });
  });

  // 離開房間
  socket.on('leave-room', (data) => {
    const { roomId, userId } = data;

    if (gameState.rooms[roomId] && gameState.rooms[roomId].players[userId]) {
      // 從房間中移除玩家
      delete gameState.rooms[roomId].players[userId];

      // 通知房間內其他玩家有玩家離開
      socket.to(roomId).emit('player-left', {
        playerId: userId
      });

      // 離開 Socket.IO 房間
      socket.leave(roomId);

      // 清理 socket 上的房間信息
      socket.userId = null;
      socket.roomId = null;

      // 如果房間沒有玩家了，清理房間
      if (Object.keys(gameState.rooms[roomId].players).length === 0) {
        gameState.rooms[roomId].isActive = false;
        // 同步房間狀態為等待中
        syncRoomStatusToSessionService(roomId, 'waiting');
      }

      console.log(`[${new Date().toISOString()}] User ${userId} left room ${roomId}`);
    }
  });

  // 發射子彈
  socket.on('fire-bullet', async (data) => {
    const { roomId, x, y, targetX, targetY, userId, gameAreaWidth, gameAreaHeight } = data;

    if (!gameState.rooms[roomId]) return;

    // 檢查玩家餘額
    const player = gameState.rooms[roomId].players[userId];
    if (!player || player.balance <= 0) {
      socket.emit('insufficient-balance', { message: '餘額不足，無法發射子彈' });
      return;
    }

    const bulletId = 'bullet_' + Date.now() + '_' + socket.id;

    // 使用固定的遊戲區域尺寸
    const room = gameState.rooms[roomId];
    const actualGameAreaWidth = 1400;  // 固定寬度
    const actualGameAreaHeight = 700;  // 固定高度

    // 確保房間使用固定尺寸
    room.gameAreaWidth = actualGameAreaWidth;
    room.gameAreaHeight = actualGameAreaHeight;

    // 調試信息：顯示遊戲區域尺寸
    console.log(`[DEBUG] Room ${roomId} game area updated: ${actualGameAreaWidth}x${actualGameAreaHeight}`);

    const unifiedStartX = actualGameAreaWidth / 2;  // 橫向正中間
    const unifiedStartY = actualGameAreaHeight - 1; // 最下面邊緣

    const bullet = {
      id: bulletId,
      playerId: userId,
      startX: unifiedStartX,
      startY: unifiedStartY,
      targetX: targetX,
      targetY: targetY,
      speed: 300,
      createdAt: Date.now(),
      isActive: true
    };

    gameState.rooms[roomId].bullets[bulletId] = bullet;

    // 扣除玩家餘額（每發子彈消耗 1 點餘額）
    console.log(`[${new Date().toISOString()}] Player ${userId} balance before: ${player.balance}`);
    player.balance -= 1;
    console.log(`[${new Date().toISOString()}] Player ${userId} balance after: ${player.balance}`);

    // 更新統計數據 - 發射次數
    if (statsCollector) {
      await statsCollector.updateStats('shot');
    }

    // 廣播子彈給房間內所有玩家（包括發射者）
    io.to(roomId).emit('bullet-fired', bullet);

    // 通知玩家餘額更新
    socket.emit('balance-updated', {
      balance: player.balance,
      change: -1,
      reason: 'bullet_fired'
    });

    // 同步餘額到用戶管理系統
    syncBalanceToUserSystem(userId, player.balance);

    // 調試信息：子彈發射詳情
    console.log(`[${new Date().toISOString()}] Bullet ${bulletId} fired: start(${unifiedStartX}, ${unifiedStartY}) -> target(${targetX}, ${targetY}), gameArea: ${actualGameAreaWidth}x${actualGameAreaHeight}`);

    // 模擬子彈移動和碰撞檢測
    simulateBullet(roomId, bulletId);

    console.log(`[${new Date().toISOString()}] Bullet fired in room ${roomId} by ${userId}`);
    console.log(`[DEBUG] Bullet ${bulletId} created: start(${unifiedStartX}, ${unifiedStartY}) -> target(${targetX}, ${targetY}), gameArea: ${actualGameAreaWidth}x${actualGameAreaHeight}`);
  });

  // 玩家移動
  socket.on('player-move', (data) => {
    const { roomId, userId, x, y } = data;

    if (gameState.rooms[roomId] && gameState.rooms[roomId].players[userId]) {
      gameState.rooms[roomId].players[userId].x = x;
      gameState.rooms[roomId].players[userId].y = y;

      // 廣播玩家位置給房間內其他玩家
      socket.to(roomId).emit('player-moved', {
        playerId: userId,
        x: x,
        y: y
      });
    }
  });

  // 開始遊戲
  socket.on('start-game', (data) => {
    const { roomId } = data;
    console.log(`[${new Date().toISOString()}] Received start-game event for room ${roomId}`);
    console.log(`[${new Date().toISOString()}] Room exists: ${!!gameState.rooms[roomId]}`);

    if (gameState.rooms[roomId]) {
      console.log(`[${new Date().toISOString()}] Room ${roomId} isActive: ${gameState.rooms[roomId].isActive}`);
    }

    if (gameState.rooms[roomId] && !gameState.rooms[roomId].isActive) {
      gameState.rooms[roomId].isActive = true;
      gameState.rooms[roomId].startTime = Date.now();

      // 開始生成魚群
      startFishSpawning(roomId);

      // 通知房間內所有玩家遊戲開始
      io.to(roomId).emit('game-started', {
        roomId: roomId,
        startTime: gameState.rooms[roomId].startTime
      });

      // 同步房間狀態到遊戲會話服務
      syncRoomStatusToSessionService(roomId, 'playing');

      console.log(`[${new Date().toISOString()}] Game started in room ${roomId}`);
    } else {
      console.log(`[${new Date().toISOString()}] Cannot start game in room ${roomId} - room not found or already active`);
    }
  });

  // 斷開連接
  socket.on('disconnect', () => {
    gameState.connections--;

    if (socket.userId && socket.roomId) {
      const roomId = socket.roomId;
      const userId = socket.userId;

      // 從房間中移除玩家
      if (gameState.rooms[roomId] && gameState.rooms[roomId].players[userId]) {
        delete gameState.rooms[roomId].players[userId];

        // 通知房間內其他玩家有玩家離開
        socket.to(roomId).emit('player-left', {
          playerId: userId
        });

        // 如果房間沒有玩家了，清理房間
        if (Object.keys(gameState.rooms[roomId].players).length === 0) {
          gameState.rooms[roomId].isActive = false;
          // 同步房間狀態為等待中
          syncRoomStatusToSessionService(roomId, 'waiting');
        }
      }
    }

    console.log(`[${new Date().toISOString()}] Client disconnected: ${socket.id}, total: ${gameState.connections}`);
  });
});

// 子彈移動和碰撞檢測模擬
function simulateBullet(roomId, bulletId) {
  const room = gameState.rooms[roomId];
  if (!room || !room.bullets[bulletId]) return;

  const bullet = room.bullets[bulletId];
  const startTime = Date.now();

  // 計算子彈移動方向和距離
  const deltaX = bullet.targetX - bullet.startX;
  const deltaY = bullet.targetY - bullet.startY;
  const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

  // 正規化方向向量
  const directionX = deltaX / distance;
  const directionY = deltaY / distance;

  // 子彈速度 (像素/秒)
  const bulletSpeed = bullet.speed || 300;

  const bulletInterval = setInterval(async () => {
    if (!room.bullets[bulletId]) {
      clearInterval(bulletInterval);
      return;
    }

    const elapsed = Date.now() - startTime;
    const travelDistance = (bulletSpeed * elapsed) / 1000; // 已移動的距離

    // 如果子彈已經到達目標位置或超出遊戲區域，移除子彈
    if (travelDistance >= distance) {
      console.log(`[${new Date().toISOString()}] Bullet ${bulletId} reached target, distance: ${travelDistance.toFixed(1)}/${distance.toFixed(1)}`);
      delete room.bullets[bulletId];
      io.to(roomId).emit('bullet-expired', { bulletId });
      clearInterval(bulletInterval);
      return;
    }

    // 計算子彈當前位置
    const currentX = bullet.startX + directionX * travelDistance;
    const currentY = bullet.startY + directionY * travelDistance;

    // 使用動態遊戲區域尺寸進行邊界檢測
    const gameAreaWidth = room.gameAreaWidth || 1400;
    const gameAreaHeight = room.gameAreaHeight || 700;

    // 讓子彈可以飛到螢幕邊緣，使用更寬鬆的邊界檢測
    // 只有當子彈飛得太遠時才移除（給足夠的空間讓子彈飛到螢幕邊緣）
    if (currentX < -200 || currentX > (gameAreaWidth + 200) || currentY < -200) {
      console.log(`[${new Date().toISOString()}] Bullet ${bulletId} out of bounds: (${currentX.toFixed(1)}, ${currentY.toFixed(1)}), bounds: ${gameAreaWidth + 200}x${gameAreaHeight}`);
      delete room.bullets[bulletId];
      io.to(roomId).emit('bullet-expired', { bulletId });
      clearInterval(bulletInterval);
      return;
    }

    // 檢查與魚的碰撞
    for (const fishId in room.fishes) {
      const fish = room.fishes[fishId];
      const collisionDistance = Math.sqrt(
        Math.pow(currentX - fish.x, 2) +
        Math.pow(currentY - fish.y, 2)
      );

      // 使用魚的大小作為碰撞半徑
      const collisionRadius = fish.size / 2;

      if (collisionDistance < collisionRadius) {
        // 碰撞！
        const reward = fish.value;

        // 更新統計數據
        if (statsCollector) {
          await statsCollector.updateStats('collision');
          await statsCollector.updateStats('hit');
          await statsCollector.updateStats('payout', { amount: reward });
        }

        // 更新玩家分數和餘額
        if (room.players[bullet.playerId]) {
          room.players[bullet.playerId].score += reward;
          room.players[bullet.playerId].balance += reward; // 餘額增加魚的價值
        }

        // 移除魚和子彈
        delete room.fishes[fishId];
        delete room.bullets[bulletId];

        // 廣播碰撞結果
        io.to(roomId).emit('collision-hit', {
          bulletId: bulletId,
          fishId: fishId,
          playerId: bullet.playerId,
          reward: reward,
          newScore: room.players[bullet.playerId]?.score || 0,
          newBalance: room.players[bullet.playerId]?.balance || 0
        });

        // 單獨通知射擊玩家餘額更新
        const playerSocket = io.sockets.sockets.get(room.players[bullet.playerId]?.socketId);
        if (playerSocket) {
          playerSocket.emit('balance-updated', {
            balance: room.players[bullet.playerId].balance,
            change: reward,
            reason: 'fish_caught'
          });

          // 同步餘額到用戶管理系統
          syncBalanceToUserSystem(bullet.playerId, room.players[bullet.playerId].balance);
        }

        clearInterval(bulletInterval);
        return;
      }
    }

    // 廣播子彈位置更新
    io.to(roomId).emit('bullet-moved', {
      bulletId: bulletId,
      x: currentX,
      y: currentY
    });

    // 調試日誌：追蹤子彈位置（每秒記錄一次）
    if (elapsed % 1000 < 50) { // 每秒記錄一次
      console.log(`[DEBUG] Bullet ${bulletId} at (${currentX.toFixed(1)}, ${currentY.toFixed(1)}), target: (${bullet.targetX}, ${bullet.targetY}), gameArea: ${gameAreaWidth}x${gameAreaHeight}, elapsed: ${elapsed}ms`);
    }
  }, 1000 / 60); // 60 FPS
}

// 管理面板 API 端點

// 即時統計數據 API
app.get('/admin/api/stats', async (req, res) => {
  try {
    if (!statsCollector) {
      return res.status(503).json({
        success: false,
        message: 'Redis 未連接，統計功能不可用'
      });
    }

    const stats = await statsCollector.collectStats();
    res.json({
      success: true,
      data: stats,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error getting stats:`, error);
    res.status(500).json({
      success: false,
      message: '獲取統計數據失敗',
      error: error.message
    });
  }
});

// 獲取當前配置 API
app.get('/admin/api/config', async (req, res) => {
  try {
    if (!configManager) {
      return res.status(503).json({
        success: false,
        message: 'Redis 未連接，配置功能不可用'
      });
    }

    const config = await configManager.getConfig();
    res.json({
      success: true,
      data: config,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error getting config:`, error);
    res.status(500).json({
      success: false,
      message: '獲取配置失敗',
      error: error.message
    });
  }
});

// 即時配置更新 API
app.post('/admin/api/config/update', async (req, res) => {
  try {
    if (!configManager) {
      return res.status(503).json({
        success: false,
        message: 'Redis 未連接，無法更新配置'
      });
    }

    const updates = req.body;
    const results = {};

    for (const [key, value] of Object.entries(updates)) {
      try {
        await configManager.updateConfig(key, value);
        results[key] = { success: true, value: value };
      } catch (error) {
        results[key] = { success: false, error: error.message };
      }
    }

    res.json({
      success: true,
      message: '配置更新完成',
      results: results,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error updating config:`, error);
    res.status(500).json({
      success: false,
      message: '配置更新失敗',
      error: error.message
    });
  }
});

// 管理後台
app.get('/admin', async (req, res) => {
  try {
    let stats, config;

    if (statsCollector && configManager) {
      stats = await statsCollector.collectStats();
      config = await configManager.getConfig();
    } else {
      // Redis 未連接時的默認值
      stats = {
        activeRooms: 0,
        fishCount: 0,
        bulletCount: 0,
        todayCollisions: 0,
        hitRate: 0,
        totalPayout: 0
      };

      config = {
        fishSpawnInterval: 2000,
        bulletSpeed: 200,
        hitRate: 0.6
      };
    }

    res.render('admin', {
      title: '遊戲伺服器服務 - 管理後台',
      service: 'game-server-service',
      connections: gameState.connections,
      stats: stats,
      config: config
    });
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error rendering admin page:`, error);
    res.render('admin', {
      title: '遊戲伺服器服務 - 管理後台',
      service: 'game-server-service',
      connections: gameState.connections,
      stats: {
        activeRooms: 0,
        fishCount: 0,
        bulletCount: 0,
        todayCollisions: 0,
        hitRate: 0,
        totalPayout: 0
      },
      config: {
        fishSpawnInterval: 2000,
        bulletSpeed: 200,
        hitRate: 0.6
      }
    });
  }
});

// 根路徑重定向到管理後台
app.get('/', (req, res) => {
  res.redirect('/admin');
});

// 404 處理
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: '找不到請求的資源'
  });
});

// 啟動服務器
server.listen(PORT, async () => {
  console.log(`[${new Date().toISOString()}] Game Server Service started on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] Admin panel: http://localhost:${PORT}/admin`);
  console.log(`[${new Date().toISOString()}] WebSocket server: ws://localhost:${PORT}`);
  console.log(`[${new Date().toISOString()}] Health check: http://localhost:${PORT}/health`);

  // 連接 Redis
  try {
    console.log(`[${new Date().toISOString()}] Connecting to Redis at ${process.env.REDIS_HOST || 'redis'}:${process.env.REDIS_PORT || 6379}`);
    await redisClient.connect();
    console.log(`[${new Date().toISOString()}] Redis connected successfully`);

    // 初始化 Redis 組件
    statsCollector = new GameStatsCollector(redisClient);
    configManager = new GameConfigManager(redisClient, io);
    console.log(`[${new Date().toISOString()}] Redis components initialized`);

  } catch (error) {
    console.error(`[${new Date().toISOString()}] Redis connection failed:`, error);
    console.error(`[${new Date().toISOString()}] Service will continue without Redis functionality`);
  }
});

module.exports = { app, server, io };