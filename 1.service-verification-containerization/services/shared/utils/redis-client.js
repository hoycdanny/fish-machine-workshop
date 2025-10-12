const redis = require('redis');
const logger = require('./logger');

class RedisClient {
  constructor() {
    this.client = null;
    this.isConnected = false;
  }

  async connect() {
    try {
      const redisConfig = {
        socket: {
          host: process.env.REDIS_HOST || 'localhost',
          port: parseInt(process.env.REDIS_PORT) || 6379,
        },
        password: process.env.REDIS_PASSWORD || undefined,
      };

      this.client = redis.createClient(redisConfig);

      // 錯誤處理
      this.client.on('error', (err) => {
        logger.error('Redis Client Error:', err);
        this.isConnected = false;
      });

      // 連接成功
      this.client.on('connect', () => {
        logger.info('Redis Client Connected');
        this.isConnected = true;
      });

      // 連接斷開
      this.client.on('end', () => {
        logger.warn('Redis Client Disconnected');
        this.isConnected = false;
      });

      // 重新連接
      this.client.on('reconnecting', () => {
        logger.info('Redis Client Reconnecting...');
      });

      await this.client.connect();
      logger.info('Redis connection established successfully');
      
      return this.client;
    } catch (error) {
      logger.error('Failed to connect to Redis:', error);
      throw error;
    }
  }

  async disconnect() {
    if (this.client) {
      await this.client.quit();
      this.isConnected = false;
      logger.info('Redis connection closed');
    }
  }

  getClient() {
    if (!this.isConnected || !this.client) {
      throw new Error('Redis client is not connected');
    }
    return this.client;
  }

  async ping() {
    try {
      const result = await this.client.ping();
      return result === 'PONG';
    } catch (error) {
      logger.error('Redis ping failed:', error);
      return false;
    }
  }

  // 常用的 Redis 操作封裝
  async set(key, value, expireInSeconds = null) {
    try {
      const client = this.getClient();
      if (expireInSeconds) {
        return await client.setEx(key, expireInSeconds, JSON.stringify(value));
      } else {
        return await client.set(key, JSON.stringify(value));
      }
    } catch (error) {
      logger.error(`Redis SET error for key ${key}:`, error);
      throw error;
    }
  }

  async get(key) {
    try {
      const client = this.getClient();
      const result = await client.get(key);
      return result ? JSON.parse(result) : null;
    } catch (error) {
      logger.error(`Redis GET error for key ${key}:`, error);
      throw error;
    }
  }

  async del(key) {
    try {
      const client = this.getClient();
      return await client.del(key);
    } catch (error) {
      logger.error(`Redis DEL error for key ${key}:`, error);
      throw error;
    }
  }

  async exists(key) {
    try {
      const client = this.getClient();
      return await client.exists(key);
    } catch (error) {
      logger.error(`Redis EXISTS error for key ${key}:`, error);
      throw error;
    }
  }

  async hSet(key, field, value) {
    try {
      const client = this.getClient();
      return await client.hSet(key, field, JSON.stringify(value));
    } catch (error) {
      logger.error(`Redis HSET error for key ${key}, field ${field}:`, error);
      throw error;
    }
  }

  async hGet(key, field) {
    try {
      const client = this.getClient();
      const result = await client.hGet(key, field);
      return result ? JSON.parse(result) : null;
    } catch (error) {
      logger.error(`Redis HGET error for key ${key}, field ${field}:`, error);
      throw error;
    }
  }

  async hGetAll(key) {
    try {
      const client = this.getClient();
      const result = await client.hGetAll(key);
      const parsed = {};
      for (const [field, value] of Object.entries(result)) {
        try {
          parsed[field] = JSON.parse(value);
        } catch {
          parsed[field] = value;
        }
      }
      return parsed;
    } catch (error) {
      logger.error(`Redis HGETALL error for key ${key}:`, error);
      throw error;
    }
  }

  async sadd(key, ...members) {
    try {
      const client = this.getClient();
      return await client.sAdd(key, members.map(m => JSON.stringify(m)));
    } catch (error) {
      logger.error(`Redis SADD error for key ${key}:`, error);
      throw error;
    }
  }

  async smembers(key) {
    try {
      const client = this.getClient();
      const result = await client.sMembers(key);
      return result.map(member => {
        try {
          return JSON.parse(member);
        } catch {
          return member;
        }
      });
    } catch (error) {
      logger.error(`Redis SMEMBERS error for key ${key}:`, error);
      throw error;
    }
  }

  async srem(key, ...members) {
    try {
      const client = this.getClient();
      return await client.sRem(key, members.map(m => JSON.stringify(m)));
    } catch (error) {
      logger.error(`Redis SREM error for key ${key}:`, error);
      throw error;
    }
  }
}

// 創建單例實例
const redisClient = new RedisClient();

module.exports = redisClient;