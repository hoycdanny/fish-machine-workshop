# 使用 Node.js 18 官方映像
FROM node:18-alpine

# 安裝 curl 用於健康檢查
RUN apk add --no-cache curl

# 設置工作目錄
WORKDIR /app

# 複製 package.json 和 package-lock.json
COPY package*.json ./

# 安裝依賴
RUN npm install --only=production

# 複製應用程式代碼
COPY . .

# 暴露端口
EXPOSE 8082

# 健康檢查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8082/health || exit 1

# 啟動應用程式
CMD ["npm", "start"]