const winston = require('winston');

// 自定義格式：JSON 格式，方便 CloudWatch Logs Insights 查詢
const jsonFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

// 創建 logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: jsonFormat,
  defaultMeta: { 
    service: 'game-server-service',
    version: '1.0.0'
  },
  transports: [
    // Console 輸出（會被 Fluent Bit 收集到 CloudWatch）
    new winston.transports.Console({
      format: jsonFormat  // 使用 JSON 格式輸出
    })
  ]
});

// 輔助函數：記錄遊戲事件
logger.gameEvent = (event, data = {}) => {
  logger.info('game_event', {
    eventType: 'game_event',
    event: event,
    ...data
  });
};

// 輔助函數：記錄記憶體事件
logger.memoryEvent = (event, data = {}) => {
  const level = data.status === 'critical' ? 'error' : 
                data.status === 'warning' ? 'warn' : 'info';
  
  logger.log(level, 'memory_event', {
    eventType: 'memory_event',
    event: event,
    ...data
  });
};

// 輔助函數：記錄性能事件
logger.performanceEvent = (event, data = {}) => {
  const level = data.elapsed > 1000 ? 'warn' : 'info';
  
  logger.log(level, 'performance_event', {
    eventType: 'performance_event',
    event: event,
    ...data
  });
};

module.exports = logger;
