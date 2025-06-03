# Linux Analytics - Docker一键部署 🐳

> 一个命令启动完整的机器学习容器管理系统！

## 🚀 快速部署

### 方式一：直接运行（推荐）

```bash
docker run -d \
  --name grafana-analytics \
  --restart unless-stopped \
  -p 3001:3001 \
  -p 3002:3002 \
  -p 5173:5173 \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v analytics-data:/app/backend/data \
  -v analytics-logs:/app/logs \
  15162104132/grafana-analytics:latest
```

### 方式二：使用docker-compose

```yaml
version: '3.8'
services:
  grafana-analytics:
    image: 15162104132/grafana-analytics:latest
    container_name: grafana-analytics
    restart: unless-stopped
    ports:
      - "3001:3001"
      - "3002:3002"
      - "5173:5173"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - analytics-data:/app/backend/data
      - analytics-logs:/app/logs
    environment:
      - NODE_ENV=production

volumes:
  analytics-data:
  analytics-logs:
```

## 📱 访问应用

部署成功后，访问：

- **主应用**: http://localhost:3001
- **WebSSH**: http://localhost:3002

## 🔧 服务说明

Docker容器内自动启动以下服务：

| 服务 | 端口 | 说明 |
|------|------|------|
| 后端API | 3001 | 主应用服务器（包含前端静态文件） |
| WebSSH | 3002 | WebSSH服务器 |

## 📋 功能特性

✅ **一键部署** - 单个Docker容器包含所有服务  
✅ **自动启动** - 使用Supervisor管理多个进程  
✅ **数据持久化** - SQLite数据库和日志文件持久化  
✅ **健康检查** - 内置健康检查机制  
✅ **容器管理** - 支持为每个用户创建独立容器  
✅ **实时聊天** - 内置聊天室功能  
✅ **现代化UI** - React前端界面  

## 🛠️ 管理命令

### 查看日志
```bash
# 查看容器日志
docker logs linuxdo-webssh

# 查看详细服务日志
docker exec -it linuxdo-webssh tail -f /var/log/supervisor/*.log
```

### 进入容器
```bash
docker exec -it linuxdo-webssh bash
```

### 重启服务
```bash
docker restart linuxdo-webssh
```

### 更新镜像
```bash
# 停止并删除旧容器
docker stop linuxdo-webssh
docker rm linuxdo-webssh

# 拉取最新镜像
docker pull your-dockerhub-username/linuxdo-webssh:latest

# 重新运行
docker run -d \
  --name linuxdo-webssh \
  --restart unless-stopped \
  -p 3001:3001 \
  -p 3002:3002 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v linuxdo-data:/app/backend/data \
  your-dockerhub-username/linuxdo-webssh:latest
```

## 🔒 安全注意事项

⚠️ **重要**: 容器需要访问Docker socket来管理用户容器  
⚠️ **端口**: 确保端口3001和3002未被占用  
⚠️ **防火墙**: 在生产环境中配置适当的防火墙规则  

## 🐛 故障排除

### 容器无法启动
```bash
# 检查端口占用
netstat -tlnp | grep :3001
netstat -tlnp | grep :3002

# 检查Docker状态
docker info
```

### 用户容器创建失败
```bash
# 检查Docker socket权限
ls -la /var/run/docker.sock

# 查看详细日志
docker logs linuxdo-webssh
```

### 服务无响应
```bash
# 检查服务状态
docker exec -it linuxdo-webssh supervisorctl status

# 重启特定服务
docker exec -it linuxdo-webssh supervisorctl restart backend-api
docker exec -it linuxdo-webssh supervisorctl restart webssh-server
```

## 📊 资源要求

- **内存**: 最少1GB，推荐2GB
- **CPU**: 最少1核，推荐2核
- **磁盘**: 最少5GB可用空间
- **Docker**: 版本20.10+

## 🎯 使用流程

1. **部署容器** - 运行上述Docker命令
2. **访问应用** - 打开 http://localhost:3001
3. **用户注册** - 输入用户名和密码
4. **等待容器** - 系统自动创建独立容器
5. **开始使用** - 在终端中自由操作
6. **实时聊天** - 与其他用户交流

## 🤝 技术支持

如有问题，请：
1. 查看容器日志
2. 检查系统资源
3. 确认网络连接
4. 提交Issue到项目仓库

---

**LinuxDo自习室** - 让每个人都有自己的Linux学习环境！ 🐧
