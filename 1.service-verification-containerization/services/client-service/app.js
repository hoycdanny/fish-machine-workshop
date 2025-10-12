// ===== 服務配置 (EKS 部署時只需修改這部分) =====
const CONFIG = {
  // 當前服務配置
  SERVICE_PORT: process.env.SERVICE_PORT || 8081,
  
  // 後端服務內部通信 (容器間/Pod間使用服務名稱)
  GAME_SESSION_SERVICE: {
    HOST: process.env.GAME_SESSION_SERVICE_HOST || 'game-session-service',
    PORT: process.env.GAME_SESSION_SERVICE_PORT || 8082
  },
  
  GAME_SERVER_SERVICE: {
    HOST: process.env.GAME_SERVER_SERVICE_HOST || 'game-server-service', 
    PORT: process.env.GAME_SERVER_SERVICE_PORT || 8083
  },
  
  // 前端瀏覽器訪問配置 (EKS 上改為 Ingress/ALB URL)
  FRONTEND_API: {
    SESSION_URL: process.env.FRONTEND_SESSION_URL || null, // EKS: https://your-domain.com/api/session
    GAME_URL: process.env.FRONTEND_GAME_URL || null       // EKS: https://your-domain.com/api/game
  }
};
// ===== 配置結束 =====

const express = require('express');
const path = require('path');

const app = express();
const PORT = CONFIG.SERVICE_PORT;

// 基本中間件
app.use(express.json());

// 健康檢查端點
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'client-service',
    version: '1.0.0'
  });
});

// 根路徑提供遊戲客戶端
app.get('/', (req, res) => {
  console.log('GET / request received');
  const fs = require('fs');
  
  try {
    let html = fs.readFileSync(path.join(__dirname, 'public', 'index.html'), 'utf8');
    
    // 動態生成前端 API URL
    let API_BASE, GAME_SERVER;
    
    if (CONFIG.FRONTEND_API.SESSION_URL && CONFIG.FRONTEND_API.GAME_URL) {
      // EKS 模式：使用配置的外部 URL
      API_BASE = CONFIG.FRONTEND_API.SESSION_URL;
      GAME_SERVER = CONFIG.FRONTEND_API.GAME_URL;
    } else {
      // 開發模式：使用當前 host + 服務端口
      const currentHost = req.get('host').split(':')[0];
      API_BASE = `http://${currentHost}:${CONFIG.GAME_SESSION_SERVICE.PORT}`;
      GAME_SERVER = `http://${currentHost}:${CONFIG.GAME_SERVER_SERVICE.PORT}`;
    }
    
    console.log('Replacing templates with:', { API_BASE, GAME_SERVER });
    
    html = html.replace(/\{\{API_BASE\}\}/g, API_BASE);
    html = html.replace(/\{\{GAME_SERVER\}\}/g, GAME_SERVER);
    
    console.log('Template replacement completed');
    res.send(html);
  } catch (error) {
    console.error('Error serving index.html:', error);
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
  }
});

// 提供靜態文件服務
app.use(express.static(path.join(__dirname, 'public')));

// 404 處理
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: '找不到請求的資源'
  });
});

// 啟動服務器
app.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] Client Service started on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] Game client: http://localhost:${PORT}`);
  console.log(`[${new Date().toISOString()}] Health check: http://localhost:${PORT}/health`);
  console.log(`[${new Date().toISOString()}] Backend services: ${CONFIG.GAME_SESSION_SERVICE.HOST}:${CONFIG.GAME_SESSION_SERVICE.PORT}, ${CONFIG.GAME_SERVER_SERVICE.HOST}:${CONFIG.GAME_SERVER_SERVICE.PORT}`);
});

module.exports = app;