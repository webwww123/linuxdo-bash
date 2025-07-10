# Linux Analytics 无特权硬件伪装系统部署指南

## 📋 系统概述

Linux Analytics 是一个基于 Docker 的无特权硬件伪装系统，使用 LD_PRELOAD 技术实现完整的硬件信息伪装，无需特权模式，确保安全性。

### 🎯 核心特性

- **无特权容器**: 完全移除特权模式，消除容器逃逸风险
- **完整硬件伪装**: CPU、内存、GPU 信息完全伪装
- **LD_PRELOAD 技术**: 拦截系统调用，支持所有工具（lscpu、htop、free、nvidia-smi 等）
- **Web 终端**: 基于 WebSSH 的浏览器终端
- **Cloudflare 隧道**: 安全的外网访问

### 🔧 伪装效果

- **CPU**: Intel Core i9-13900K @ 3.00GHz (24核心)
- **内存**: 64GB DDR4
- **GPU**: NVIDIA A100-SXM4-80GB

## 🚀 快速部署

### 1. 环境要求

```bash
# 操作系统
Ubuntu 20.04+ / CentOS 8+ / Debian 11+

# 软件依赖
- Docker 20.10+
- Node.js 16+
- Git
- GCC (用于编译 LD_PRELOAD 库)
```

### 2. 克隆项目

```bash
git clone https://github.com/webwww123/linuxdo-bash.git
cd linuxdo-bash
```

### 3. 安装依赖

```bash
# 后端依赖
cd backend
npm install

# 前端依赖
cd ../frontend
npm install
npm run build

cd ..
```

### 4. 编译硬件伪装库

```bash
gcc -shared -fPIC -ldl docker/hardware_spoof.c -o docker/hardware_spoof.so
```

### 5. 构建 Docker 镜像

```bash
docker build -f docker/Dockerfile.ubuntu -t linux-ubuntu:latest .
```

### 6. 启动服务

```bash
# 启动 WebSSH 服务
cd backend
node webssh-server.js &

# 启动主服务
DOCKER_HOST="unix:///var/run/docker.sock" PORT=8080 node server.js &

# 启动 Cloudflare 隧道（可选）
cloudflared tunnel --url http://localhost:8080
```

## 🔧 详细配置

### Docker 权限配置

```bash
# 确保 Docker socket 权限
sudo chmod 666 /var/run/docker.sock

# 或者将用户添加到 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

### 数据库配置

```bash
# 创建数据目录
mkdir -p /tmp/app-data
chmod 777 /tmp/app-data

# 创建数据库文件
touch /tmp/app-data/users.db
chmod 666 /tmp/app-data/users.db
```

### 环境变量

```bash
# 设置 Docker 主机
export DOCKER_HOST="unix:///var/run/docker.sock"

# 设置端口
export PORT=8080
```

## 🐛 常见问题与解决方案

### 1. Docker 相关问题

#### 问题: `connect EACCES /var/run/docker.sock`
```bash
# 解决方案
sudo chmod 666 /var/run/docker.sock
# 或
sudo usermod -aG docker $USER && newgrp docker
```

#### 问题: `No such image: linux-ubuntu:latest`
```bash
# 解决方案：重新构建镜像
docker build -f docker/Dockerfile.ubuntu -t linux-ubuntu:latest .
```

#### 问题: 容器创建失败
```bash
# 检查 Docker 状态
sudo systemctl status docker

# 重启 Docker 服务
sudo systemctl restart docker

# 清理无用镜像和容器
docker system prune -f
```

### 2. 数据库问题

#### 问题: `SQLITE_READONLY: attempt to write a readonly database`
```bash
# 解决方案
sudo chown -R $USER:$USER /tmp/app-data/
chmod -R 777 /tmp/app-data/
```

#### 问题: `SQLITE_CONSTRAINT: UNIQUE constraint failed`
```bash
# 解决方案：清理数据库
rm -f /tmp/app-data/users.db
touch /tmp/app-data/users.db
chmod 666 /tmp/app-data/users.db
```

### 3. 网络问题

#### 问题: 端口被占用
```bash
# 检查端口占用
netstat -tlnp | grep 8080
# 或
lsof -i :8080

# 杀死占用进程
sudo kill -9 <PID>
```

#### 问题: WebSSH 连接失败
```bash
# 检查 WebSSH 服务状态
curl http://localhost:3002

# 重启 WebSSH 服务
cd backend
node webssh-server.js
```

### 4. 硬件伪装问题

#### 问题: LD_PRELOAD 不生效
```bash
# 检查库文件
ls -la docker/hardware_spoof.so

# 重新编译
gcc -shared -fPIC -ldl docker/hardware_spoof.c -o docker/hardware_spoof.so

# 测试库文件
LD_PRELOAD=./docker/hardware_spoof.so cat /proc/cpuinfo | head -5
```

#### 问题: htop 显示真实核心数
```bash
# 确保 /proc/stat 被拦截
LD_PRELOAD=./docker/hardware_spoof.so cat /proc/stat | head -5

# 重新构建镜像
docker build -f docker/Dockerfile.ubuntu -t linux-ubuntu:latest .
```

### 5. 编译问题

#### 问题: `gcc: command not found`
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install build-essential

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
# 或
sudo dnf groupinstall "Development Tools"
```

#### 问题: 缺少头文件
```bash
# 安装开发包
sudo apt install libc6-dev
```

## 🔒 安全配置

### 1. 容器安全

```bash
# 确保无特权模式
docker inspect <container_id> | grep Privileged
# 应该显示: "Privileged": false
```

### 2. 网络安全

```bash
# 使用 Cloudflare 隧道而不是直接暴露端口
cloudflared tunnel --url http://localhost:8080

# 配置防火墙
sudo ufw allow 22/tcp
sudo ufw enable
```

### 3. 文件权限

```bash
# 设置适当的文件权限
chmod 644 docker/hardware_spoof.c
chmod 755 docker/hardware_spoof.so
chmod 755 docker/ld_preload_init.sh
```

## 📊 性能优化

### 1. Docker 优化

```bash
# 清理无用资源
docker system prune -f

# 限制容器资源
docker run --memory="2g" --cpus="2" ...
```

### 2. 数据库优化

```bash
# 使用 WAL 模式
echo "PRAGMA journal_mode=WAL;" | sqlite3 /tmp/app-data/users.db
```

## 🔍 监控与日志

### 1. 服务监控

```bash
# 检查服务状态
ps aux | grep node
docker ps

# 查看日志
tail -f /var/log/syslog | grep docker
```

### 2. 性能监控

```bash
# 监控资源使用
docker stats
htop
```

## 🚀 生产环境部署

### 1. 使用 Docker Compose

```yaml
version: '3.8'
services:
  linux-analytics:
    build:
      context: .
      dockerfile: docker/Dockerfile.ubuntu
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/tmp/app-data
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock
      - PORT=8080
```

### 2. 使用 Systemd 服务

```ini
[Unit]
Description=Linux Analytics Service
After=docker.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/linuxdo-bash/backend
Environment=DOCKER_HOST=unix:///var/run/docker.sock
Environment=PORT=8080
ExecStart=/usr/bin/node server.js
Restart=always

[Install]
WantedBy=multi-user.target
```

### 3. 反向代理配置

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 📞 技术支持

如果遇到问题，请按以下步骤排查：

1. 检查所有服务是否正常运行
2. 查看错误日志
3. 验证权限配置
4. 测试网络连接
5. 重新构建镜像

更多技术支持请访问项目 GitHub 仓库。

## 🧪 测试验证

### 硬件伪装测试

部署完成后，请使用以下命令验证硬件伪装效果：

```bash
# 1. 验证 LD_PRELOAD 设置
echo "LD_PRELOAD: $LD_PRELOAD"
# 预期输出: LD_PRELOAD: /opt/hardware_spoof.so

# 2. 测试 CPU 伪装
lscpu
# 预期: Intel Core i9-13900K @ 3.00GHz, 24 核心

nproc
# 预期输出: 24

htop  # 按 q 退出
# 预期: 显示 24 个 CPU 核心

# 3. 测试内存伪装
free -h
# 预期: 显示 64GB 内存

cat /proc/meminfo | head -5
# 预期: MemTotal: 65536000 kB

# 4. 测试系统文件伪装
cat /proc/stat | head -5
# 预期: 显示 cpu0-cpu23

cat /proc/cpuinfo | head -10
# 预期: Intel Core i9-13900K 信息

# 5. 测试 GPU 伪装
nvidia-smi
# 预期: NVIDIA A100-SXM4-80GB

nvcc --version
# 预期: CUDA 编译器信息

lspci | grep -i nvidia
# 预期: NVIDIA A100 设备

# 6. 综合系统信息
neofetch
# 预期: 完整的伪装硬件配置
```

### 安全性验证

```bash
# 1. 验证容器非特权模式
docker inspect <container_id> | grep -i privileged
# 预期: "Privileged": false

# 2. 验证容器权限
docker exec <container_id> cat /proc/self/status | grep Cap
# 预期: 受限的权限集合

# 3. 验证文件系统隔离
docker exec <container_id> ls /host 2>/dev/null || echo "隔离正常"
# 预期: "隔离正常"
```

## 🔄 维护操作

### 日常维护

```bash
# 1. 清理旧容器
docker container prune -f

# 2. 清理无用镜像
docker image prune -f

# 3. 清理系统资源
docker system prune -f

# 4. 备份数据库
cp /tmp/app-data/users.db /backup/users_$(date +%Y%m%d).db

# 5. 查看系统状态
docker stats --no-stream
df -h
free -h
```

### 更新部署

```bash
# 1. 停止服务
pkill -f "node server.js"
pkill -f "node webssh-server.js"

# 2. 更新代码
git pull origin main

# 3. 重新构建
gcc -shared -fPIC -ldl docker/hardware_spoof.c -o docker/hardware_spoof.so
docker build -f docker/Dockerfile.ubuntu -t linux-ubuntu:latest .

# 4. 重启服务
cd backend
node webssh-server.js &
DOCKER_HOST="unix:///var/run/docker.sock" PORT=8080 node server.js &
```

## 🚨 故障排除

### 紧急恢复

```bash
# 1. 完全重置
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi linux-ubuntu:latest
rm -rf /tmp/app-data/*

# 2. 重新部署
./deploy.sh  # 如果有部署脚本
```

### 日志分析

```bash
# 1. 查看 Docker 日志
journalctl -u docker.service -f

# 2. 查看容器日志
docker logs <container_id>

# 3. 查看应用日志
tail -f backend/logs/app.log  # 如果有日志文件

# 4. 查看系统日志
dmesg | tail -20
```

### 性能问题

```bash
# 1. 检查资源使用
docker stats
top
iotop

# 2. 检查磁盘空间
df -h
du -sh /var/lib/docker

# 3. 检查网络
netstat -tlnp
ss -tlnp
```

## 📋 部署检查清单

### 部署前检查

- [ ] 系统满足最低要求
- [ ] Docker 服务正常运行
- [ ] Node.js 版本正确
- [ ] 网络端口可用
- [ ] 磁盘空间充足

### 部署中检查

- [ ] 代码克隆成功
- [ ] 依赖安装完成
- [ ] 硬件伪装库编译成功
- [ ] Docker 镜像构建成功
- [ ] 权限配置正确

### 部署后检查

- [ ] 所有服务正常启动
- [ ] 数据库连接正常
- [ ] WebSSH 服务可访问
- [ ] 硬件伪装生效
- [ ] 容器创建成功
- [ ] 外网访问正常

## 🔐 安全最佳实践

### 1. 容器安全

```bash
# 使用非 root 用户运行容器
docker run --user 1000:1000 ...

# 限制容器权限
docker run --cap-drop=ALL --cap-add=SETUID --cap-add=SETGID ...

# 使用只读文件系统
docker run --read-only --tmpfs /tmp ...
```

### 2. 网络安全

```bash
# 使用内部网络
docker network create --internal internal-net

# 限制出站连接
iptables -A OUTPUT -p tcp --dport 80,443 -j ACCEPT
iptables -A OUTPUT -p tcp -j DROP
```

### 3. 数据安全

```bash
# 加密敏感数据
echo "sensitive_data" | openssl enc -aes-256-cbc -base64

# 定期备份
crontab -e
# 添加: 0 2 * * * /backup/backup_script.sh
```

## 📈 扩展部署

### 多实例部署

```bash
# 使用不同端口运行多个实例
PORT=8081 node server.js &
PORT=8082 node server.js &
PORT=8083 node server.js &
```

### 负载均衡

```nginx
upstream linux_analytics {
    server localhost:8080;
    server localhost:8081;
    server localhost:8082;
}

server {
    location / {
        proxy_pass http://linux_analytics;
    }
}
```

### 容器编排

```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8080-8083:8080"
    deploy:
      replicas: 4
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

## 🎯 性能调优

### 系统级优化

```bash
# 调整内核参数
echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf
echo 'fs.file-max = 100000' >> /etc/sysctl.conf
sysctl -p

# 调整 Docker 配置
echo '{"storage-driver": "overlay2", "log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}' > /etc/docker/daemon.json
systemctl restart docker
```

### 应用级优化

```javascript
// 在 server.js 中添加
process.env.UV_THREADPOOL_SIZE = 128;
app.use(compression());
app.use(helmet());
```

---

**部署完成后，请访问生成的 Cloudflare 隧道地址测试系统功能！**

如有问题，请参考故障排除章节或提交 GitHub Issue。
