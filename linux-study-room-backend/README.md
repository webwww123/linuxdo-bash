# Linux Study Room Backend - 部署指南

## 📦 文件清单

```
linux-study-room-backend/
├── lsr-backend          # Linux 可执行文件 (无需其他依赖)
├── .env                 # 配置文件 (需要修改)
├── cmd/                 # 源码
├── internal/            # 源码
├── go.mod               # Go 模块定义
└── go.sum               # 依赖锁定
```

## 🚀 快速部署

### 1. 上传到服务器

```bash
# 上传整个目录
scp -r linux-study-room-backend/ user@your-server:/opt/
```

### 2. 确保 Docker 已安装

```bash
docker --version
# 如果没有:
curl -fsSL https://get.docker.com | sh
```

### 3. 配置环境变量

```bash
cd /opt/linux-study-room-backend
cp .env.example .env
nano .env
```

修改以下配置:
```env
PORT=8080
DB_PATH=./data/study_room.db
JWT_SECRET=生成一个随机密钥
LINUXDO_CLIENT_ID=你的LinuxDo应用ID  # 最后再配
LINUXDO_CLIENT_SECRET=你的LinuxDo密钥  # 最后再配
```

### 4. 启动服务

```bash
chmod +x lsr-backend
./lsr-backend
```

或使用 systemd 后台运行:
```bash
sudo tee /etc/systemd/system/lsr.service << 'EOF'
[Unit]
Description=Linux Study Room Backend
After=docker.service

[Service]
WorkingDirectory=/opt/linux-study-room-backend
ExecStart=/opt/linux-study-room-backend/lsr-backend
Restart=always
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable lsr
sudo systemctl start lsr
```

### 5. 验证

```bash
curl http://localhost:8080/health
# 应返回: {"service":"linux-study-room","status":"ok"}
```

## 📡 API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/api/container/launch` | POST | 创建容器 `{"os_type":"debian"}` |
| `/api/container/:id/restart` | POST | 重启容器 |
| `/api/container/:id/reset` | POST | 销毁容器 |
| `/ws/terminal?container_id=xxx` | WS | 终端 WebSocket |
| `/ws/lobby` | WS | 聊天大厅 |

## ⚠️ 注意事项

1. **Docker 权限**: 确保运行用户在 `docker` 组中
   ```bash
   sudo usermod -aG docker $USER
   ```

2. **防火墙**: 开放 8080 端口
   ```bash
   sudo ufw allow 8080
   ```

3. **LinuxDo OAuth**: 去 https://connect.linux.do 注册应用后再配置

---
*by 不吃香菜*
