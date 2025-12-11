# Linux Study Room 部署指南

## 📦 准备文件

### 后端
- 文件：`linux-study-room-backend/server-linux`
- 配置：创建 `.env` 文件

### 前端
- 目录：`linux-study-room-web/dist/`

---

## 🚀 服务器部署步骤

### 1. 上传文件到服务器

```bash
# 创建目录
mkdir -p /opt/linux-study-room/backend
mkdir -p /opt/linux-study-room/frontend

# 上传文件（从本地执行）
scp linux-study-room-backend/server-linux user@server:/opt/linux-study-room/backend/
scp -r linux-study-room-web/dist/* user@server:/opt/linux-study-room/frontend/
```

### 2. 配置后端环境变量

在服务器上创建 `/opt/linux-study-room/backend/.env`：

```env
# 服务器配置
PORT=8080

# 数据库
DB_PATH=./data/study_room.db

# JWT 密钥（请生成随机字符串）
JWT_SECRET=your-random-secret-key-here

# LinuxDo OAuth2（从 https://connect.linux.do 获取）
LINUXDO_CLIENT_ID=你的_client_id
LINUXDO_CLIENT_SECRET=你的_client_secret
LINUXDO_CALLBACK_URL=https://你的域名/api/auth/linuxdo/callback

# 前端地址
FRONTEND_URL=https://你的域名
```

### 3. 安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker
```

### 4. 创建 Systemd 服务

创建 `/etc/systemd/system/linux-study-room.service`：

```ini
[Unit]
Description=Linux Study Room Backend
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/linux-study-room/backend
ExecStart=/opt/linux-study-room/backend/server-linux
Restart=always
RestartSec=5
Environment=GIN_MODE=release

[Install]
WantedBy=multi-user.target
```

```bash
# 设置权限并启动
chmod +x /opt/linux-study-room/backend/server-linux
systemctl daemon-reload
systemctl enable linux-study-room
systemctl start linux-study-room
```

### 5. 配置 Nginx 反向代理

创建 `/etc/nginx/sites-available/linux-study-room`：

```nginx
server {
    listen 80;
    server_name 你的域名;
    
    # 前端静态文件
    location / {
        root /opt/linux-study-room/frontend;
        try_files $uri $uri/ /index.html;
    }
    
    # 后端 API
    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # WebSocket
    location /ws {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/linux-study-room /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### 6. 配置 HTTPS（推荐）

```bash
apt install certbot python3-certbot-nginx -y
certbot --nginx -d 你的域名
```

---

## 🔧 LinuxDo OAuth2 配置

1. 访问 https://connect.linux.do
2. 点击"我的应用接入" → "申请新接入"
3. 填写信息：
   - **应用名称**：Linux Study Room
   - **回调地址**：`https://你的域名/api/auth/linuxdo/callback`
4. 获取 **Client ID** 和 **Client Secret**
5. 更新 `.env` 文件

---

## 📋 常用命令

```bash
# 查看后端日志
journalctl -u linux-study-room -f

# 重启后端
systemctl restart linux-study-room

# 查看状态
systemctl status linux-study-room

# 查看 Docker 容器
docker ps
```

---

## ⚠️ 注意事项

1. 确保服务器防火墙开放 80/443 端口
2. 确保 Docker 服务正常运行
3. OAuth 回调地址必须与 LinuxDo 配置的完全一致
4. 建议配置 HTTPS 以保护 OAuth token
