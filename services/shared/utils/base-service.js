const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

const logger = require('./logger');
const config = require('./config');
const redisClient = require('./redis-client');
const { createHealthCheck } = require('./health-check');
const { errorHandler, notFoundHandler } = require('../middleware/error-handler');

class BaseService {
  constructor(serviceName) {
    this.serviceName = serviceName;
    this.app = express();
    this.server = null;
    this.healthCheck = createHealthCheck(serviceName);
    this.serviceLogger = logger.child(serviceName);
    
    this.setupMiddleware();
    this.setupHealthChecks();
  }

  setupMiddleware() {
    // 安全中間件
    this.app.use(helmet({
      contentSecurityPolicy: false, // 為了管理後台的內聯樣式
      crossOriginEmbedderPolicy: false
    }));

    // CORS 配置
    this.app.use(cors({
      origin: config.isDevelopment() ? true : process.env.ALLOWED_ORIGINS?.split(',') || [],
      credentials: true
    }));

    // 壓縮響應
    this.app.use(compression());

    // 解析 JSON
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // 請求日誌
    this.app.use(logger.requestMiddleware(this.serviceName));

    // 速率限制
    if (config.isProduction()) {
      const limiter = rateLimit({
        windowMs: 15 * 60 * 1000, // 15 分鐘
        max: 1000, // 每個 IP 最多 1000 個請求
        message: {
          success: false,
          error: {
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'Too many requests from this IP'
          }
        }
      });
      this.app.use(limiter);
    }
  }

  setupHealthChecks() {
    // 健康檢查端點
    this.app.get('/health', this.healthCheck.middleware());
    this.app.get('/health/ready', this.healthCheck.readinessMiddleware());
    this.app.get('/health/live', this.healthCheck.livenessMiddleware());
  }

  // 添加路由
  addRoutes(path, router) {
    this.app.use(path, router);
  }

  // 添加靜態文件服務
  addStaticFiles(path, directory) {
    this.app.use(path, express.static(directory));
  }

  // 設置錯誤處理
  setupErrorHandling() {
    // 404 處理
    this.app.use(notFoundHandler);
    
    // 錯誤處理
    this.app.use(errorHandler(this.serviceName));
  }

  // 連接到 Redis
  async connectToRedis() {
    try {
      await redisClient.connect();
      this.serviceLogger.info('Connected to Redis successfully');
    } catch (error) {
      this.serviceLogger.error('Failed to connect to Redis:', error);
      throw error;
    }
  }

  // 啟動服務
  async start() {
    try {
      // 連接 Redis
      await this.connectToRedis();

      // 設置錯誤處理（必須在所有路由之後）
      this.setupErrorHandling();

      // 啟動 HTTP 服務器
      const port = config.get('service.port');
      this.server = this.app.listen(port, () => {
        this.serviceLogger.info(`${this.serviceName} started on port ${port}`);
        this.serviceLogger.info(`Health check available at http://localhost:${port}/health`);
        this.serviceLogger.info(`Admin panel available at http://localhost:${port}/admin`);
      });

      // 優雅關閉處理
      this.setupGracefulShutdown();

    } catch (error) {
      this.serviceLogger.error('Failed to start service:', error);
      process.exit(1);
    }
  }

  // 設置優雅關閉
  setupGracefulShutdown() {
    const shutdown = async (signal) => {
      this.serviceLogger.info(`Received ${signal}, starting graceful shutdown...`);

      // 停止接受新連接
      if (this.server) {
        this.server.close(async () => {
          this.serviceLogger.info('HTTP server closed');

          try {
            // 關閉 Redis 連接
            await redisClient.disconnect();
            this.serviceLogger.info('Redis connection closed');

            this.serviceLogger.info('Graceful shutdown completed');
            process.exit(0);
          } catch (error) {
            this.serviceLogger.error('Error during shutdown:', error);
            process.exit(1);
          }
        });
      }

      // 強制退出超時
      setTimeout(() => {
        this.serviceLogger.error('Forced shutdown due to timeout');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  }

  // 獲取 Express 應用實例
  getApp() {
    return this.app;
  }

  // 獲取服務日誌器
  getLogger() {
    return this.serviceLogger;
  }

  // 獲取健康檢查實例
  getHealthCheck() {
    return this.healthCheck;
  }
}

module.exports = BaseService;