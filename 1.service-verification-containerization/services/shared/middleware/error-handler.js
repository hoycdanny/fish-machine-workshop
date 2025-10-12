const logger = require('../utils/logger');

// 自定義錯誤類
class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

// 業務邏輯錯誤
class BusinessError extends AppError {
  constructor(message, code = 'BUSINESS_ERROR') {
    super(message, 400, code);
  }
}

// 驗證錯誤
class ValidationError extends AppError {
  constructor(message, field = null) {
    super(message, 400, 'VALIDATION_ERROR');
    this.field = field;
  }
}

// 認證錯誤
class AuthenticationError extends AppError {
  constructor(message = 'Authentication failed') {
    super(message, 401, 'AUTHENTICATION_ERROR');
  }
}

// 授權錯誤
class AuthorizationError extends AppError {
  constructor(message = 'Access denied') {
    super(message, 403, 'AUTHORIZATION_ERROR');
  }
}

// 資源未找到錯誤
class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}

// 衝突錯誤
class ConflictError extends AppError {
  constructor(message = 'Resource conflict') {
    super(message, 409, 'CONFLICT_ERROR');
  }
}

// 速率限制錯誤
class RateLimitError extends AppError {
  constructor(message = 'Too many requests') {
    super(message, 429, 'RATE_LIMIT_ERROR');
  }
}

// 錯誤處理中間件
const errorHandler = (serviceName) => {
  return (error, req, res, next) => {
    const requestLogger = req.logger || logger.child(serviceName);
    
    // 記錄錯誤
    requestLogger.error('Application Error', {
      message: error.message,
      stack: error.stack,
      requestId: req.requestId,
      method: req.method,
      url: req.originalUrl,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });

    // 如果是自定義錯誤
    if (error.isOperational) {
      return res.status(error.statusCode).json({
        success: false,
        error: {
          code: error.code,
          message: error.message,
          ...(error.field && { field: error.field })
        },
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    }

    // 處理 MongoDB 錯誤
    if (error.name === 'MongoError' || error.name === 'MongooseError') {
      return res.status(500).json({
        success: false,
        error: {
          code: 'DATABASE_ERROR',
          message: 'Database operation failed'
        },
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    }

    // 處理 JWT 錯誤
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: {
          code: 'INVALID_TOKEN',
          message: 'Invalid authentication token'
        },
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    }

    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: {
          code: 'TOKEN_EXPIRED',
          message: 'Authentication token has expired'
        },
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    }

    // 處理驗證錯誤
    if (error.name === 'ValidationError') {
      const validationErrors = Object.values(error.errors).map(err => ({
        field: err.path,
        message: err.message
      }));

      return res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Validation failed',
          details: validationErrors
        },
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    }

    // 處理語法錯誤
    if (error instanceof SyntaxError && error.status === 400 && 'body' in error) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_JSON',
          message: 'Invalid JSON in request body'
        },
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    }

    // 未知錯誤
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: process.env.NODE_ENV === 'production' 
          ? 'Internal server error' 
          : error.message
      },
      timestamp: new Date().toISOString(),
      requestId: req.requestId
    });
  };
};

// 404 處理中間件
const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: `Route ${req.method} ${req.originalUrl} not found`
    },
    timestamp: new Date().toISOString(),
    requestId: req.requestId
  });
};

// 異步錯誤包裝器
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

module.exports = {
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