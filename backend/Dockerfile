FROM node:18-alpine

# 安装Python和构建工具（node-pty需要）
RUN apk add --no-cache python3 python3-dev py3-setuptools make g++

WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖（清理缓存并重新安装）
RUN rm -rf node_modules package-lock.json && npm install --only=production

# 复制源代码
COPY . .

# 暴露端口
EXPOSE 3001

# 启动主API服务器
CMD ["node", "server.js"]
