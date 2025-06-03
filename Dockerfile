# Linux自习室 - 单一Docker镜像
# 第一阶段：构建前端
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# 复制前端package文件
COPY frontend/package*.json ./

# 安装前端依赖
RUN npm ci

# 复制前端源码
COPY frontend/ ./

# 构建前端
RUN npm run build

# 第二阶段：最终运行环境
FROM node:18-alpine

# 安装系统依赖
RUN apk add --no-cache \
    docker-cli \
    python3 \
    make \
    g++ \
    sqlite \
    curl \
    bash \
    supervisor

# 创建应用目录
WORKDIR /app

# 复制项目文件
COPY backend/ ./backend/
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist
COPY package*.json ./
COPY docker/ ./docker/

# 安装后端依赖
WORKDIR /app/backend
RUN npm ci --only=production

# 回到根目录
WORKDIR /app

# 安装根目录依赖
RUN npm ci --only=production

# 创建必要的目录
RUN mkdir -p backend/data logs /var/log/supervisor

# 设置环境变量
ENV NODE_ENV=production
ENV PORT=3001
ENV WEBSSH_PORT=3002
ENV FRONTEND_PORT=5173

# 暴露端口
EXPOSE 3001 3002 5173

# 复制supervisor配置
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 复制启动脚本
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3001/api/health || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]
