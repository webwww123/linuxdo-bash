# 🚀 Linux Study Room

一个在线协作式 Linux 终端学习平台，让用户可以在浏览器中使用真实的 Linux 环境，并与其他用户实时互动。

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?style=flat&logo=go" alt="Go Version">
  <img src="https://img.shields.io/badge/Vue-3.x-4FC08D?style=flat&logo=vue.js" alt="Vue Version">
  <img src="https://img.shields.io/badge/Docker-Required-2496ED?style=flat&logo=docker" alt="Docker">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat" alt="License">
</p>

## ✨ 功能特性

### 🖥️ 终端功能
- **真实 Linux 环境** - 每个用户独享一个 Docker 容器
- **多发行版支持** - Alpine Linux / Debian Slim 可选
- **持久化容器** - 断线重连后环境保持不变
- **Fish Shell** - 开箱即用的现代化 Shell

### 👥 社交功能
- **LiveWall 实时墙** - 查看所有在线用户的终端
- **实时聊天** - 内置聊天室，支持图片分享
- **点赞与置顶** - 给喜欢的终端点赞或置顶

### 🎮 协作功能
- **远程协助** - 邀请其他用户控制你的终端
- **实时同步** - 小窗口实时显示终端输出
- **双向控制** - 被邀请者可以输入命令

### 🔐 认证系统
- **LinuxDo OAuth2** - 一键登录，无需注册
- **游客模式** - 无需登录即可浏览
- **信任等级** - 基于 LinuxDo 信任等级的权限控制

## 🏗️ 技术栈

| 组件 | 技术 |
|------|------|
| 后端 | Go + Gin + WebSocket |
| 前端 | Vue 3 + TypeScript + Tailwind CSS |
| 终端 | xterm.js + Docker API |
| 数据库 | SQLite |
| 认证 | LinuxDo OAuth2 + JWT |

## 📦 快速开始

### 环境要求
- Go 1.21+
- Node.js 18+
- Docker

### 本地开发

```bash
# 克隆项目
git clone https://github.com/webwww123/linuxdo-bash.git
cd linuxdo-bash

# 启动后端
cd linux-study-room-backend
cp .env.example .env
go run ./cmd/server

# 启动前端（新终端）
cd linux-study-room-web
npm install
npm run dev
```

访问 http://localhost:5173

### 生产部署

参考 [DEPLOY.md](./DEPLOY.md) 获取完整部署指南。

## ⚙️ 环境变量

```env
# 服务器
PORT=8080

# 数据库
DB_PATH=./data/study_room.db

# JWT 密钥
JWT_SECRET=your-random-secret

# LinuxDo OAuth2（从 https://connect.linux.do 获取）
LINUXDO_CLIENT_ID=your_client_id
LINUXDO_CLIENT_SECRET=your_client_secret
LINUXDO_CALLBACK_URL=https://your-domain/api/auth/linuxdo/callback
FRONTEND_URL=https://your-domain
```

## 📁 项目结构

```
linuxdo-bash/
├── linux-study-room-backend/    # Go 后端
│   ├── cmd/server/              # 入口
│   ├── internal/
│   │   ├── handler/             # HTTP/WS 处理器
│   │   ├── service/             # 业务逻辑
│   │   └── store/               # 数据存储
│   └── .env.example
│
├── linux-study-room-web/        # Vue 前端
│   ├── src/
│   │   ├── components/          # 组件
│   │   ├── api.ts               # API 封装
│   │   └── App.vue
│   └── package.json
│
├── DEPLOY.md                    # 部署文档
└── README.md
```

## 🔒 安全特性

- **容器隔离** - 每个用户独立容器，禁止容器间通信
- **资源限制** - CPU/内存限制防止滥用
- **权限控制** - 容器内 Drop 不必要的 Linux Capabilities
- **无特权容器** - 禁止容器内提权

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 License

MIT License
