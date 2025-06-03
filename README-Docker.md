# linux自习室 Docker部署指南 🐳

> 一键部署linux自习室 - 基于Docker的WebSSH系统

## 🚀 快速开始

### 方式一：直接运行Docker镜像（推荐）

```bash
# 拉取并运行镜像
docker run -d \
  --name linux-webssh \
  --restart unless-stopped \
  -p 3001:3001 \
  -p 3002:3002 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v linux-data:/app/backend/data \
  -v linux-logs:/app/logs \
  your-dockerhub-username/linux-webssh:latest
```

### 方式二：使用docker-compose

```bash
# 克隆项目
git clone <repository-url>
cd linux-webssh

# 启动服务
docker-compose up -d
```

### 方式三：本地构建

```bash
# 克隆项目
git clone <repository-url>
cd linux-webssh

# 构建镜像
docker build -t linux-webssh .

# 运行容器
docker run -d \
  --name linux-webssh \
  --restart unless-stopped \
  -p 3001:3001 \
  -p 3002:3002 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v linux-data:/app/backend/data \
  linux-webssh
```

## 📱 访问应用

启动成功后，访问以下地址：

- **主应用**: http://localhost:3001
- **WebSSH**: http://localhost:3002

## 🔧 环境要求

- Docker 20.10+
- Docker Compose 2.0+ (如果使用compose方式)
- 至少2GB可用内存
- 至少10GB可用磁盘空间

## 📋 端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| 3001 | 主应用 | 前端界面 + 后端API |
| 3002 | WebSSH | WebSSH服务器 |

## 🗂️ 数据持久化

容器使用以下卷进行数据持久化：

- `linux-data`: 存储SQLite数据库和用户数据
- `linux-logs`: 存储应用日志

## 🛠️ 管理命令

### 查看日志
```bash
# 查看容器日志
docker logs linux-webssh

# 查看详细服务日志
docker exec -it linux-webssh tail -f /var/log/supervisor/*.log
```

### 进入容器
```bash
docker exec -it linux-webssh bash
```

### 重启服务
```bash
docker restart linux-webssh
```

### 停止服务
```bash
docker stop linux-webssh
```

### 更新镜像
```bash
# 停止并删除旧容器
docker stop linux-webssh
docker rm linux-webssh

# 拉取最新镜像
docker pull your-dockerhub-username/linux-webssh:latest

# 重新运行
docker run -d \
  --name linux-webssh \
  --restart unless-stopped \
  -p 3001:3001 \
  -p 3002:3002 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v linux-data:/app/backend/data \
  -v linux-logs:/app/logs \
  your-dockerhub-username/linux-webssh:latest
```

## 🔒 安全注意事项

1. **Docker Socket**: 容器需要访问Docker socket来管理用户容器，这是必需的但需要注意安全性
2. **端口暴露**: 只暴露必要的端口，避免暴露到公网
3. **资源限制**: 建议设置内存和CPU限制
4. **网络隔离**: 在生产环境中使用防火墙和网络隔离

## 🐛 故障排除

### 容器无法启动
```bash
# 检查Docker是否运行
docker info

# 检查端口是否被占用
netstat -tlnp | grep :3001
netstat -tlnp | grep :3002
```

### 用户容器创建失败
```bash
# 检查Docker socket权限
ls -la /var/run/docker.sock

# 检查容器日志
docker logs linux-webssh
```

### 服务无响应
```bash
# 检查服务状态
docker exec -it linux-webssh supervisorctl status

# 重启特定服务
docker exec -it linux-webssh supervisorctl restart backend-api
docker exec -it linux-webssh supervisorctl restart webssh-server
```

## 📊 性能优化

### 资源限制建议
```bash
docker run -d \
  --name linux-webssh \
  --restart unless-stopped \
  --memory=2g \
  --cpus=2 \
  -p 3001:3001 \
  -p 3002:3002 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v linux-data:/app/backend/data \
  your-dockerhub-username/linux-webssh:latest
```

### 日志轮转
```bash
# 设置日志大小限制
docker run -d \
  --name linux-webssh \
  --restart unless-stopped \
  --log-driver json-file \
  --log-opt max-size=100m \
  --log-opt max-file=3 \
  -p 3001:3001 \
  -p 3002:3002 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v linux-data:/app/backend/data \
  your-dockerhub-username/linux-webssh:latest
```

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License
