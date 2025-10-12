const logger = require('./logger');

class Config {
  constructor() {
    this.config = {};
    this.loadConfig();
  }

  loadConfig() {
    // 基本配置
    this.config = {
      // 服務配置
      service: {
        name: process.env.SERVICE_NAME || 'fish-game-service',
        port: parseInt(process.env.SERVICE_PORT) || 3000,
        environment: process.env.NODE_ENV || 'development'
      },

      // Redis 配置
      redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT) || 6379
      },

      // 服務間通訊配置
      services: {
        gameSession: process.env.GAME_SESSION_SERVICE_URL || `http://${process.env.GAME_SESSION_SERVICE_HOST || 'game-session-service'}:${process.env.GAME_SESSION_SERVICE_PORT || 8082}`,
        gameServer: process.env.GAME_SERVER_SERVICE_URL || `http://${process.env.GAME_SERVER_SERVICE_HOST || 'game-server-service'}:${process.env.GAME_SERVER_SERVICE_PORT || 8083}`
      }
    };

    this.validateConfig();
  }

  validateConfig() {
    const requiredConfigs = [
      'service.name',
      'service.port',
      'redis.host',
      'redis.port'
    ];

    for (const configPath of requiredConfigs) {
      if (!this.get(configPath)) {
        throw new Error(`Required configuration missing: ${configPath}`);
      }
    }

    // 驗證端口範圍
    if (this.config.service.port < 1 || this.config.service.port > 65535) {
      throw new Error('Service port must be between 1 and 65535');
    }

    logger.info('Configuration validated successfully');
  }

  get(path, defaultValue = undefined) {
    const keys = path.split('.');
    let current = this.config;

    for (const key of keys) {
      if (current[key] === undefined) {
        return defaultValue;
      }
      current = current[key];
    }

    return current;
  }

  set(path, value) {
    const keys = path.split('.');
    let current = this.config;

    for (let i = 0; i < keys.length - 1; i++) {
      const key = keys[i];
      if (!current[key] || typeof current[key] !== 'object') {
        current[key] = {};
      }
      current = current[key];
    }

    current[keys[keys.length - 1]] = value;
  }

  getAll() {
    return { ...this.config };
  }

  // 獲取服務配置
  getServiceConfig() {
    return this.get('service');
  }

  // 獲取 Redis 配置
  getRedisConfig() {
    return this.get('redis');
  }



  // 獲取服務 URL
  getServiceUrl(serviceName) {
    return this.get(`services.${serviceName}`);
  }

  // 是否為開發環境
  isDevelopment() {
    return this.get('service.environment') === 'development';
  }

  // 是否為生產環境
  isProduction() {
    return this.get('service.environment') === 'production';
  }
}

// 創建單例實例
const config = new Config();

module.exports = config;