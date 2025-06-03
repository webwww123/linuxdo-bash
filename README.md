# Linux Analytics 🤖

> 机器学习容器管理平台 - 安全、隔离、易用的在线分析环境

## ✨ 特性

### 🐳 容器隔离
- **独立环境**: 每个用户获得独立的Docker容器
- **完全隔离**: 用户无法访问宿主机或其他用户的容器
- **Ubuntu 22.04**: 基于最新LTS版本，预装常用开发工具
- **Sudo权限**: 用户在容器内拥有完整的管理员权限

### 🛡️ 安全特性
- **自动清理**: 容器2小时后自动销毁
- **资源限制**: 内存和CPU使用限制
- **安全配置**: 禁用危险权限，防止容器逃逸

### 🎨 用户体验
- **实时终端**: 基于xterm.js的现代化终端体验
- **进度反馈**: 容器创建时显示详细进度
- **响应式设计**: 支持桌面和移动设备
- **实时聊天**: 内置聊天室，方便用户交流

### 💬 社交功能
- **聊天室**: SQLite驱动的实时聊天系统
- **用户列表**: 查看当前在线用户
- **终端观看**: 可以观看其他用户的终端输出（只读）

## 🚀 快速开始

### 前置要求
- Node.js 18+
- Docker
- npm 或 yarn

### 安装步骤

1. **克隆项目**
```bash
git clone <repository-url>
cd linux-analytics
```

2. **安装依赖**
```bash
npm run install:all
```

3. **启动服务**
```bash
# 推荐：使用新的一键启动脚本
./start-all.sh

# 或者使用传统启动脚本
./start.sh
```

4. **访问应用**
- 主应用: http://localhost:3001
- WebSSH: http://localhost:3002
- 前端开发: http://localhost:5173
- Grafana监控: http://localhost:8080

## 🛠️ 服务管理

### 一键启动（推荐）
```bash
./start-all.sh              # 完整启动（首次使用）
./start-all.sh --skip-deps  # 跳过依赖安装
./start-all.sh --skip-build # 跳过Docker构建
```

### 停止服务
```bash
./stop-all.sh                    # 正常停止
./stop-all.sh --force           # 强制停止所有进程
./stop-all.sh --clean-containers # 同时删除Docker容器
```

### 重启服务
```bash
./restart-all.sh              # 快速重启
./restart-all.sh --full       # 完整重启（重新安装依赖和构建）
./restart-all.sh --with-deps  # 重启并重新安装依赖
```

### 查看日志
```bash
# 查看所有日志
tail -f logs/*.log

# 查看特定服务日志
tail -f logs/backend.log   # 后端API日志
tail -f logs/webssh.log    # WebSSH服务日志
tail -f logs/frontend.log  # 前端开发服务器日志
```

### 手动启动

如果需要手动启动各个服务：

```bash
# 1. 构建Docker镜像
docker build -t linux-ubuntu:latest -f docker/Dockerfile.ubuntu .

# 2. 启动后端API服务
cd backend && npm start &

# 3. 启动WebSSH服务
cd backend && node webssh-server.js &

# 4. 启动前端服务
cd frontend && npm run dev
```

## 📁 项目结构

```
linux-analytics/
├── frontend/           # React前端应用
│   ├── src/
│   │   ├── components/ # React组件
│   │   ├── App.jsx     # 主应用组件
│   │   └── main.jsx    # 入口文件
│   └── package.json
├── backend/            # Node.js后端服务
│   ├── services/       # 业务逻辑服务
│   │   ├── containerManager.js  # Docker容器管理
│   │   ├── terminalService.js   # 终端服务
│   │   ├── chatService.js       # 聊天服务
│   │   └── userService.js       # 用户管理服务
│   ├── data/           # SQLite数据库文件
│   ├── server.js       # 主API服务器
│   └── webssh-server.js # WebSSH服务器
├── docker/             # Docker配置
│   └── Dockerfile.ubuntu
├── logs/               # 服务日志文件
├── start-all.sh        # 一键启动脚本（推荐）
├── stop-all.sh         # 停止服务脚本
├── restart-all.sh      # 重启服务脚本
└── start.sh            # 传统启动脚本
```

## 🔧 技术栈

### 前端
- **React 18**: 现代化UI框架
- **Vite**: 快速构建工具
- **Tailwind CSS**: 实用优先的CSS框架
- **xterm.js**: 终端模拟器
- **Socket.IO**: 实时通信
- **Lucide React**: 图标库

### 后端
- **Node.js**: 服务器运行时
- **Express**: Web框架
- **Socket.IO**: WebSocket通信
- **Dockerode**: Docker API客户端
- **node-pty**: 伪终端
- **SQLite3**: 轻量级数据库

## 🎯 使用说明

1. **登录**: 输入符合Linux用户名规则的用户名
2. **等待**: 系统会自动创建你的专属容器
3. **使用**: 在终端中自由操作，安装软件，运行代码
4. **聊天**: 使用右侧聊天室与其他用户交流
5. **观看**: 可以观看其他用户的终端操作（只读模式）

### 用户名规则
- 只能包含小写字母、数字、下划线、连字符
- 必须以字母开头
- 长度1-32字符
- 不能以连字符结尾

## 🔒 安全说明

- 每个容器都有严格的资源限制
- 容器无法访问宿主机文件系统
- 自动清理机制防止资源滥用
- 禁用了危险的系统调用

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License

## 🙏 致谢

感谢开源社区的支持和贡献！