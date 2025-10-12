// 共用模組統一導出
const BaseService = require('./utils/base-service');
const config = require('./utils/config');
const logger = require('./utils/logger');
const redisClient = require('./utils/redis-client');
const { createHealthCheck } = require('./utils/health-check');

// 錯誤處理
const {
  AppError,
  BusinessError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  RateLimitError,
  errorHandler,
  notFoundHandler,
  asyncHandler
} = require('./middleware/error-handler');

module.exports = {
  BaseService,
  config,
  logger,
  redisClient,
  createHealthCheck,
  AppError,
  BusinessError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  RateLimitError,
  errorHandler,
  notFoundHandler,
  asyncHandler
};