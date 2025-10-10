const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.SERVICE_PORT || 8080;

// 基本中間件
app.use(express.json());

// 提供靜態文件服務
app.use(express.static(path.join(__dirname, 'public')));

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
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

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
});

module.exports = app;