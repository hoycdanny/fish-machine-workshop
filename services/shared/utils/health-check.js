const redisClient = require('./redis-client');
const logger = require('./logger');

class HealthCheck {
  constructor(serviceName) {
    this.serviceName = serviceName;
    this.startTime = Date.now();
    this.checks = new Map();
    
    // 註冊基本檢查
    this.registerCheck('service', () => this.checkService());
    this.registerCheck('redis', () => this.checkRedis());
  }

  // 註冊健康檢查項目
  registerCheck(name, checkFunction) {
    this.checks.set(name, checkFunction);
  }

  // 基本服務檢查
  async checkService() {
    return {
      status: 'healthy',
      uptime: Date.now() - this.startTime,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development'
    };
  }

  // Redis 連接檢查
  async checkRedis() {
    try {
      const isConnected = await redisClient.ping();
      return {
        status: isConnected ? 'healthy' : 'unhealthy',
        connected: isConnected,
        host: process.env.REDIS_HOST || 'localhost',
        port: process.env.REDIS_PORT || 6379
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        connected: false,
        error: error.message
      };
    }
  }

  // 執行所有健康檢查
  async performHealthCheck() {
    const results = {
      service: this.serviceName,
      status: 'healthy',
      timestamp: new Date().toISOString(),
      checks: {}
    };

    let hasUnhealthyCheck = false;

    // 執行所有註冊的檢查
    for (const [name, checkFunction] of this.checks) {
      try {
        const checkResult = await checkFunction();
        results.checks[name] = checkResult;
        
        if (checkResult.status === 'unhealthy') {
          hasUnhealthyCheck = true;
        }
      } catch (error) {
        results.checks[name] = {
          status: 'unhealthy',
          error: error.message
        };
        hasUnhealthyCheck = true;
      }
    }

    // 設置整體狀態
    results.status = hasUnhealthyCheck ? 'unhealthy' : 'healthy';

    return results;
  }

  // 創建健康檢查中間件
  middleware() {
    return async (req, res) => {
      try {
        const healthStatus = await this.performHealthCheck();
        const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
        
        res.status(statusCode).json(healthStatus);
      } catch (error) {
        logger.error('Health check failed:', error);
        res.status(503).json({
          service: this.serviceName,
          status: 'unhealthy',
          timestamp: new Date().toISOString(),
          error: 'Health check execution failed'
        });
      }
    };
  }

  // 創建就緒檢查中間件（用於 Kubernetes）
  readinessMiddleware() {
    return async (req, res) => {
      try {
        const healthStatus = await this.performHealthCheck();
        
        // 就緒檢查更嚴格，所有檢查都必須通過
        const isReady = healthStatus.status === 'healthy' && 
                       Object.values(healthStatus.checks).every(check => check.status === 'healthy');
        
        const statusCode = isReady ? 200 : 503;
        
        res.status(statusCode).json({
          service: this.serviceName,
          ready: isReady,
          timestamp: new Date().toISOString(),
          checks: healthStatus.checks
        });
      } catch (error) {
        logger.error('Readiness check failed:', error);
        res.status(503).json({
          service: this.serviceName,
          ready: false,
          timestamp: new Date().toISOString(),
          error: 'Readiness check execution failed'
        });
      }
    };
  }

  // 創建存活檢查中間件（用於 Kubernetes）
  livenessMiddleware() {
    return (req, res) => {
      // 存活檢查只檢查服務是否還在運行
      res.status(200).json({
        service: this.serviceName,
        alive: true,
        timestamp: new Date().toISOString(),
        uptime: Date.now() - this.startTime
      });
    };
  }
}

// 創建健康檢查工廠函數
const createHealthCheck = (serviceName) => {
  return new HealthCheck(serviceName);
};

module.exports = {
  HealthCheck,
  createHealthCheck
};