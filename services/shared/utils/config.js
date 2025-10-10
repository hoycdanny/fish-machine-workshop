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
        port: parseInt(process.env.REDIS_PORT) || 6379,
        password: process.env.REDIS_PASSWORD || undefined
      },

      // JWT 配置
      jwt: {
        secret: process.env.JWT_SECRET || 'default-secret-key',
        expiresIn: process.env.JWT_EXPIRES_IN || '24h'
      },

      // 日誌配置
      logging: {
        level: process.env.LOG_LEVEL || 'info'
      },

      // 遊戲配置
      game: {
        roomMaxPlayers: parseInt(process.env.GAME_ROOM_MAX_PLAYERS) || 4,
        fishSpawnInterval: parseInt(process.env.GAME_FISH_SPAWN_INTERVAL) || 2000,
        bulletSpeed: parseInt(process.env.GAME_BULLET_SPEED) || 200
      },

      // 魚類機率配置
      fish: {
        hitRates: {
          small: parseFloat(process.env.FISH_HIT_RATE_SMALL) || 0.8,
          medium: parseFloat(process.env.FISH_HIT_RATE_MEDIUM) || 0.6,
          large: parseFloat(process.env.FISH_HIT_RATE_LARGE) || 0.4,
          boss: parseFloat(process.env.FISH_HIT_RATE_BOSS) || 0.2
        },
        payouts: {
          small: this.parsePayoutArray(process.env.FISH_PAYOUT_SMALL) || [2, 4, 6],
          medium: this.parsePayoutArray(process.env.FISH_PAYOUT_MEDIUM) || [5, 10, 15],
          large: this.parsePayoutArray(process.env.FISH_PAYOUT_LARGE) || [10, 20, 30],
          boss: this.parsePayoutArray(process.env.FISH_PAYOUT_BOSS) || [50, 100, 200]
        }
      },

      // 服務間通訊配置
      services: {
        userWallet: process.env.USER_WALLET_SERVICE_URL || 'http://user-wallet-service:8081',
        gameSession: process.env.GAME_SESSION_SERVICE_URL || 'http://game-session-service:8082',
        gameServer: process.env.GAME_SERVER_SERVICE_URL || 'http://game-server-service:8083'
      }
    };

    this.validateConfig();
  }

  parsePayoutArray(payoutString) {
    if (!payoutString) return null;
    try {
      return payoutString.split(',').map(num => parseInt(num.trim()));
    } catch (error) {
      logger.warn(`Failed to parse payout array: ${payoutString}`);
      return null;
    }
  }

  validateConfig() {
    const requiredConfigs = [
      'service.name',
      'service.port',
      'redis.host',
      'redis.port',
      'jwt.secret'
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

    // 驗證機率值
    Object.values(this.config.fish.hitRates).forEach(rate => {
      if (rate < 0 || rate > 1) {
        throw new Error('Fish hit rates must be between 0 and 1');
      }
    });

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

  // 獲取 JWT 配置
  getJwtConfig() {
    return this.get('jwt');
  }

  // 獲取遊戲配置
  getGameConfig() {
    return this.get('game');
  }

  // 獲取魚類配置
  getFishConfig() {
    return this.get('fish');
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