const winston = require('winston');

// 定義日誌級別和顏色
const logLevels = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3
};

const logColors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  debug: 'blue'
};

// 創建自定義格式
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.colorize({ all: true }),
  winston.format.printf(({ timestamp, level, message, stack, service }) => {
    const serviceName = service || process.env.SERVICE_NAME || 'unknown';
    const logMessage = stack || message;
    return `[${timestamp}] [${serviceName}] ${level}: ${logMessage}`;
  })
);

// 創建 Winston Logger
const logger = winston.createLogger({
  levels: logLevels,
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  transports: [
    // 控制台輸出
    new winston.transports.Console({
      handleExceptions: true,
      handleRejections: true
    })
  ],
  exitOnError: false
});

// 添加顏色配置
winston.addColors(logColors);

// 為不同服務添加上下文
logger.child = (serviceName) => {
  const config = require('./config');
  return winston.createLogger({
    level: config.get('logging.level'),
    format: winston.format.combine(
      winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
      winston.format.errors({ stack: true }),
      winston.format.colorize(),
      winston.format.printf(({ timestamp, level, message, service, ...meta }) => {
        const serviceLabel = service || serviceName || 'unknown';
        const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
        return `[${timestamp}] [${serviceLabel}] ${level}: ${message} ${metaStr}`;
      })
    ),
    transports: logger.transports,
    defaultMeta: { service: serviceName }
  });
};

// 添加請求日誌中間件
logger.requestMiddleware = (serviceName) => {
  return (req, res, next) => {
    const start = Date.now();
    const requestId = req.headers['x-request-id'] || Math.random().toString(36).substr(2, 9);
    
    req.requestId = requestId;
    req.logger = logger.child({ service: serviceName, requestId });

    // 記錄請求開始
    req.logger.info(`${req.method} ${req.originalUrl} - Request started`, {
      method: req.method,
      url: req.originalUrl,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });

    // 監聽響應結束
    res.on('finish', () => {
      const duration = Date.now() - start;
      const logLevel = res.statusCode >= 400 ? 'error' : 'info';
      
      req.logger[logLevel](`${req.method} ${req.originalUrl} - ${res.statusCode} - ${duration}ms`, {
        method: req.method,
        url: req.originalUrl,
        statusCode: res.statusCode,
        duration: `${duration}ms`
      });
    });

    next();
  };
};

// 添加錯誤日誌方法
logger.logError = (error, context = {}) => {
  logger.error('Application Error', {
    message: error.message,
    stack: error.stack,
    ...context
  });
};

// 添加性能監控日誌
logger.logPerformance = (operation, duration, context = {}) => {
  const logLevel = duration > 1000 ? 'warn' : 'info';
  logger[logLevel](`Performance: ${operation} took ${duration}ms`, {
    operation,
    duration: `${duration}ms`,
    ...context
  });
};

// 添加業務日誌方法
logger.logBusiness = (event, data = {}) => {
  logger.info(`Business Event: ${event}`, {
    event,
    ...data
  });
};

module.exports = logger;