const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.SERVICE_PORT || 8082;

// 基本中間件
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 設置 EJS 模板引擎
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// 健康檢查端點
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'game-session-service',
    version: '1.0.0'
  });
});

// 簡單的內存用戶存儲（開發用）
const users = new Map();

// 用戶管理 API
app.post('/api/v1/users/register', (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({
      success: false,
      message: '用戶名和密碼不能為空'
    });
  }
  
  if (users.has(username)) {
    return res.status(400).json({
      success: false,
      message: '用戶名已存在'
    });
  }
  
  const userId = 'user_' + Date.now();
  users.set(username, {
    userId,
    username,
    password, // 實際應用中應該加密
    balance: 1000.00,
    createdAt: new Date()
  });
  
  res.json({
    success: true,
    message: '用戶註冊成功',
    data: { userId, username }
  });
});

app.post('/api/v1/users/login', (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({
      success: false,
      message: '用戶名和密碼不能為空'
    });
  }
  
  const user = users.get(username);
  console.log(`[${new Date().toISOString()}] Login attempt for user:`, username, 'User data:', user);
  
  if (!user || user.password !== password) {
    return res.status(401).json({
      success: false,
      message: '用戶名或密碼錯誤'
    });
  }
  
  console.log(`[${new Date().toISOString()}] Login successful, user balance:`, user.balance);
  
  res.json({
    success: true,
    message: '登入成功',
    data: { 
      token: 'jwt_token_' + Date.now(),
      userId: user.userId,
      username: user.username,
      balance: user.balance
    }
  });
});

// 錢包管理 API
app.get('/api/v1/wallet/balance/:userId', (req, res) => {
  const { userId } = req.params;
  
  // 從用戶數據中查找餘額
  let userBalance = 1000.00; // 預設餘額
  for (const user of users.values()) {
    if (user.userId === userId) {
      userBalance = user.balance;
      break;
    }
  }
  
  res.json({
    success: true,
    data: { balance: userBalance }
  });
});

// 更新用戶餘額 API (供遊戲伺服器調用)
app.post('/api/v1/wallet/update-balance', (req, res) => {
  const { userId, balance } = req.body;
  
  if (!userId || balance === undefined) {
    return res.status(400).json({
      success: false,
      message: '缺少必要參數'
    });
  }
  
  // 查找並更新用戶餘額
  let userFound = false;
  for (const user of users.values()) {
    if (user.userId === userId) {
      user.balance = parseFloat(balance);
      user.updatedAt = new Date();
      userFound = true;
      console.log(`[${new Date().toISOString()}] Updated balance for user ${userId}: ${balance}`);
      break;
    }
  }
  
  if (userFound) {
    res.json({
      success: true,
      message: '餘額更新成功',
      data: { userId, balance: parseFloat(balance) }
    });
  } else {
    res.status(404).json({
      success: false,
      message: '用戶不存在'
    });
  }
});

// 更新房間狀態 API (供遊戲伺服器調用)
app.post('/api/v1/lobby/rooms/update-status', (req, res) => {
  const { roomId, status } = req.body;
  
  if (!roomId || !status) {
    return res.status(400).json({
      success: false,
      message: '缺少必要參數'
    });
  }
  
  // 查找並更新房間狀態
  if (rooms.has(roomId)) {
    const room = rooms.get(roomId);
    room.status = status;
    room.updatedAt = new Date();
    rooms.set(roomId, room);
    
    console.log(`[${new Date().toISOString()}] Updated room status for room ${roomId}: ${status}`);
    
    res.json({
      success: true,
      message: '房間狀態更新成功',
      data: { roomId, status }
    });
  } else {
    res.status(404).json({
      success: false,
      message: '房間不存在'
    });
  }
});

// 簡單的內存房間存儲（開發用）
const rooms = new Map();

// 大廳管理 API
app.get('/api/v1/lobby/rooms', (req, res) => {
  const roomList = Array.from(rooms.values()).map(room => ({
    id: room.id,
    name: room.name,
    currentPlayers: room.players.length,
    maxPlayers: room.maxPlayers,
    status: room.status,
    createdAt: room.createdAt
  }));
  
  res.json({
    success: true,
    data: { rooms: roomList }
  });
});

app.post('/api/v1/lobby/rooms/create', (req, res) => {
  const { name, maxPlayers = 4 } = req.body;
  const roomId = 'room_' + Date.now();
  
  const room = {
    id: roomId,
    name: name || `房間 ${roomId}`,
    maxPlayers,
    players: [],
    status: 'waiting',
    createdAt: new Date()
  };
  
  rooms.set(roomId, room);
  
  res.json({
    success: true,
    message: '房間創建成功',
    data: { 
      roomId,
      room: {
        id: room.id,
        name: room.name,
        currentPlayers: room.players.length,
        maxPlayers: room.maxPlayers,
        status: room.status
      }
    }
  });
});

// 加入房間 API
app.post('/api/v1/lobby/rooms/:roomId/join', (req, res) => {
  const { roomId } = req.params;
  const { userId, username } = req.body;
  
  const room = rooms.get(roomId);
  if (!room) {
    return res.status(404).json({
      success: false,
      message: '房間不存在'
    });
  }
  
  // 檢查玩家是否已經在房間中
  const existingPlayer = room.players.find(p => p.userId === userId);
  if (existingPlayer) {
    return res.json({
      success: true,
      message: '玩家已在房間中',
      data: { roomId, alreadyInRoom: true }
    });
  }
  
  // 檢查房間是否已滿
  if (room.players.length >= room.maxPlayers) {
    return res.status(400).json({
      success: false,
      message: '房間已滿'
    });
  }
  
  // 添加玩家到房間
  room.players.push({
    userId,
    username: username || `Player_${userId}`,
    joinedAt: new Date()
  });
  
  console.log(`[${new Date().toISOString()}] 玩家 ${userId} 加入房間 ${roomId}`);
  
  res.json({
    success: true,
    message: '成功加入房間',
    data: {
      roomId,
      currentPlayers: room.players.length,
      maxPlayers: room.maxPlayers
    }
  });
});

// 離開房間 API
app.post('/api/v1/lobby/rooms/:roomId/leave', (req, res) => {
  const { roomId } = req.params;
  const { userId } = req.body;
  
  const room = rooms.get(roomId);
  if (!room) {
    return res.status(404).json({
      success: false,
      message: '房間不存在'
    });
  }
  
  // 從房間中移除玩家
  const playerIndex = room.players.findIndex(p => p.userId === userId);
  if (playerIndex !== -1) {
    room.players.splice(playerIndex, 1);
    console.log(`[${new Date().toISOString()}] 玩家 ${userId} 離開房間 ${roomId}`);
  }
  
  res.json({
    success: true,
    message: '成功離開房間',
    data: {
      roomId,
      currentPlayers: room.players.length,
      maxPlayers: room.maxPlayers
    }
  });
});

// 測試路由
app.get('/api/v1/test', (req, res) => {
  res.json({ success: true, message: '測試路由正常' });
});

// 房間刪除 API (DELETE 方法) - 必須在通用路由之前
app.delete('/api/v1/lobby/rooms/:roomId', (req, res) => {
  const { roomId } = req.params;
  console.log(`[${new Date().toISOString()}] DELETE 嘗試刪除房間: ${roomId}`);
  console.log(`[${new Date().toISOString()}] 當前房間列表:`, Array.from(rooms.keys()));
  
  if (rooms.has(roomId)) {
    rooms.delete(roomId);
    console.log(`[${new Date().toISOString()}] 房間 ${roomId} 已刪除`);
    res.json({
      success: true,
      message: '房間刪除成功',
      data: { roomId }
    });
  } else {
    console.log(`[${new Date().toISOString()}] 房間 ${roomId} 不存在`);
    res.status(404).json({
      success: false,
      message: '房間不存在'
    });
  }
});

// 房間刪除 API (POST 方法)
app.post('/api/v1/lobby/rooms/:roomId/delete', (req, res) => {
  const { roomId } = req.params;
  console.log(`[${new Date().toISOString()}] POST 嘗試刪除房間: ${roomId}`);
  console.log(`[${new Date().toISOString()}] 當前房間列表:`, Array.from(rooms.keys()));
  
  if (rooms.has(roomId)) {
    rooms.delete(roomId);
    console.log(`[${new Date().toISOString()}] 房間 ${roomId} 已刪除`);
    res.json({
      success: true,
      message: '房間刪除成功',
      data: { roomId }
    });
  } else {
    console.log(`[${new Date().toISOString()}] 房間 ${roomId} 不存在`);
    res.status(404).json({
      success: false,
      message: '房間不存在'
    });
  }
});

// 清空所有房間 API
app.delete('/api/v1/lobby/rooms/all', (req, res) => {
  const deletedCount = rooms.size;
  rooms.clear();
  console.log(`[${new Date().toISOString()}] 已清空所有房間，共刪除 ${deletedCount} 個房間`);
  
  res.json({
    success: true,
    message: `已清空所有房間，共刪除 ${deletedCount} 個房間`,
    data: { deletedCount }
  });
});

// 配桌管理 API
app.post('/api/v1/matching/find-room', (req, res) => {
  const { userId, nickname, balance } = req.body;
  
  // 尋找有空位的房間
  let availableRoom = null;
  for (const room of rooms.values()) {
    if (room.players.length < room.maxPlayers && room.status === 'waiting') {
      availableRoom = room;
      break;
    }
  }
  
  if (availableRoom) {
    // 加入現有房間
    availableRoom.players.push({ userId, nickname, balance });
    
    res.json({
      success: true,
      message: '找到合適房間',
      data: { 
        roomId: availableRoom.id,
        action: 'join_existing_room',
        room: {
          id: availableRoom.id,
          name: availableRoom.name,
          currentPlayers: availableRoom.players.length,
          maxPlayers: availableRoom.maxPlayers
        }
      }
    });
  } else {
    // 建議創建新房間
    res.json({
      success: true,
      message: '沒有合適的房間，建議創建新房間',
      data: { 
        action: 'create_new_room',
        suggestedRoomConfig: {
          maxPlayers: 4,
          name: `${nickname}的房間`
        }
      }
    });
  }
});

// 管理後台 - 清空房間操作
app.post('/admin/clear-rooms', (req, res) => {
  const deletedCount = rooms.size;
  rooms.clear();
  res.json({
    success: true,
    message: `已清空所有房間，共刪除 ${deletedCount} 個房間`,
    data: { deletedCount }
  });
});

// 管理後台 - 刪除單個房間
app.post('/admin/delete-room', (req, res) => {
  const { roomId } = req.body;
  
  if (rooms.has(roomId)) {
    rooms.delete(roomId);
    res.json({
      success: true,
      message: '房間刪除成功',
      data: { roomId }
    });
  } else {
    res.status(404).json({
      success: false,
      message: '房間不存在'
    });
  }
});

// 管理後台 - 獲取用戶列表
app.get('/admin/users', (req, res) => {
  const userList = Array.from(users.values()).map(user => ({
    userId: user.userId,
    username: user.username,
    balance: user.balance,
    createdAt: user.createdAt
  }));
  
  res.json({
    success: true,
    data: { users: userList }
  });
});

// 管理後台 - 刪除用戶
app.post('/admin/delete-user', (req, res) => {
  const { username } = req.body;
  
  if (users.has(username)) {
    users.delete(username);
    res.json({
      success: true,
      message: '用戶刪除成功',
      data: { username }
    });
  } else {
    res.status(404).json({
      success: false,
      message: '用戶不存在'
    });
  }
});

// 管理後台 - 變更用戶密碼
app.post('/admin/change-password', (req, res) => {
  const { username, newPassword } = req.body;
  
  if (!username || !newPassword) {
    return res.status(400).json({
      success: false,
      message: '用戶名和新密碼不能為空'
    });
  }
  
  if (users.has(username)) {
    const user = users.get(username);
    user.password = newPassword;
    user.updatedAt = new Date();
    users.set(username, user);
    
    res.json({
      success: true,
      message: '密碼變更成功',
      data: { username }
    });
  } else {
    res.status(404).json({
      success: false,
      message: '用戶不存在'
    });
  }
});

// 管理後台 - 調整用戶餘額
app.post('/admin/adjust-balance', (req, res) => {
  const { username, newBalance } = req.body;
  
  if (!username || newBalance === undefined) {
    return res.status(400).json({
      success: false,
      message: '用戶名和新餘額不能為空'
    });
  }
  
  if (users.has(username)) {
    const user = users.get(username);
    user.balance = parseFloat(newBalance);
    user.updatedAt = new Date();
    users.set(username, user);
    
    res.json({
      success: true,
      message: '餘額調整成功',
      data: { username, newBalance: user.balance }
    });
  } else {
    res.status(404).json({
      success: false,
      message: '用戶不存在'
    });
  }
});

// 管理後台 - 清空所有用戶
app.post('/admin/clear-users', (req, res) => {
  const deletedCount = users.size;
  users.clear();
  
  res.json({
    success: true,
    message: `已清空所有用戶，共刪除 ${deletedCount} 個用戶`,
    data: { deletedCount }
  });
});

// 管理後台
app.get('/admin', (req, res) => {
  res.render('admin', {
    title: '遊戲會話服務 - 管理後台',
    service: 'game-session-service'
  });
});

// 根路徑重定向到管理後台
app.get('/', (req, res) => {
  res.redirect('/admin');
});

// 404 處理 - 只處理未匹配的路由
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: '找不到請求的資源'
  });
});

// 啟動服務器
app.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] Game Session Service started on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] Admin panel: http://localhost:${PORT}/admin`);
  console.log(`[${new Date().toISOString()}] Health check: http://localhost:${PORT}/health`);
});

module.exports = app;