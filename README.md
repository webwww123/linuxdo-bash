# Linux Analytics 🤖

> 机器学习容器管理平台 - 安全、隔离、易用的在线分析环境

## ✨ 特性

### 🐳 容器隔离
- **独立环境**: 每个用户获得独立的Docker容器
- **完全隔离**: 用户无法访问宿主机或其他用户的容器
- **Ubuntu 22.04**: 基于最新LTS版本，预装常用开发工具
- **Sudo权限**: 用户在容器内拥有完整的管理员权限

### 🛡️ 安全特性
- **自动清理**: 20分钟无活动后自动销毁容器
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
- **点赞系统**: 为其他用户点赞

### 🏗️ 三合一架构
- **单端口部署**: 所有服务通过8080端口统一访问
- **Docker容器化**: 完全容器化部署，一键启动
- **Nginx反向代理**: 智能路由，统一入口
- **内置监控**: Grafana监控面板，实时查看系统状态

## 🚀 快速开始

### 前置要求
- **Docker**: 用于容器化部署
- **Docker Compose**: 用于多服务编排

### 一键部署

1. **克隆项目**
```bash
git clone <repository-url>
cd linux-analytics
```

2. **启动所有服务**
```bash
docker compose up -d
```

3. **访问应用**
- **主应用**: http://localhost:8080
- **监控面板**: http://localhost:8080/grafana
- **WebSSH终端**: http://localhost:8080/webssh

### 🎯 三合一架构说明

所有服务都通过 **单一端口 8080** 访问：

```
外部访问 (localhost:8080)
         ↓
    [Nginx 反向代理]
         ↓
    ┌─────────────────────────────────┐
    │  /                             │ → 前端应用
    │  /api/*                        │ → 后端API服务
    │  /socket.io/*                  │ → 实时通信
    │  /webssh/*                     │ → SSH终端服务
    │  /grafana/*                    │ → 监控面板
    └─────────────────────────────────┘
```

## 🛠️ 服务管理

### 启动服务
```bash
# 启动所有服务（后台运行）
docker compose up -d

# 启动并查看日志
docker compose up

# 重新构建并启动
docker compose up --build -d
```

### 停止服务
```bash
# 停止所有服务
docker compose down

# 停止并删除数据卷
docker compose down -v
```

### 查看状态
```bash
# 查看服务状态
docker compose ps

# 查看服务日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f backend   # 后端API日志
docker compose logs -f webssh    # WebSSH服务日志
docker compose logs -f nginx     # Nginx代理日志
docker compose logs -f grafana   # Grafana监控日志
```

### 重启服务
```bash
# 重启所有服务
docker compose restart

# 重启特定服务
docker compose restart backend
docker compose restart nginx
```

### 开发模式

如果需要开发调试，可以单独启动前端开发服务器：

```bash
# 启动后端服务
docker compose up -d backend webssh grafana

# 启动前端开发服务器
cd frontend && npm run dev
# 访问: http://localhost:5173
```

## 📁 项目结构

```
linux-analytics/
├── frontend/                    # React前端应用
│   ├── src/
│   │   ├── components/         # React组件
│   │   │   ├── Terminal.jsx    # 终端组件
│   │   │   ├── Chat.jsx        # 聊天组件
│   │   │   ├── UserList.jsx    # 用户列表
│   │   │   └── OtherUsersTerminals.jsx # 其他用户终端观看
│   │   ├── App.jsx             # 主应用组件
│   │   └── main.jsx            # 入口文件
│   └── package.json
├── backend/                     # Node.js后端服务
│   ├── services/               # 业务逻辑服务
│   │   ├── containerManager.js # Docker容器管理
│   │   ├── terminalService.js  # 终端服务
│   │   ├── chatService.js      # 聊天服务
│   │   └── userService.js      # 用户管理服务
│   ├── data/                   # SQLite数据库文件
│   ├── server.js               # 主API服务器
│   ├── webssh-server.js        # WebSSH服务器
│   ├── grafana-server.js       # Grafana模拟服务器
│   ├── Dockerfile              # 后端Docker镜像
│   ├── Dockerfile.webssh       # WebSSH Docker镜像
│   └── Dockerfile.grafana      # Grafana Docker镜像
├── nginx/                      # Nginx反向代理
│   ├── Dockerfile              # Nginx Docker镜像
│   └── nginx.conf              # Nginx配置文件
├── docker/                     # 用户容器Docker配置
│   └── Dockerfile.ubuntu       # Ubuntu用户容器镜像
├── docker-compose.yml          # Docker Compose配置
└── README.md                   # 项目文档
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

### 基础设施
- **Docker**: 容器化平台
- **Docker Compose**: 多服务编排
- **Nginx**: 反向代理和静态文件服务
- **Ubuntu 22.04**: 用户容器基础镜像

### 监控
- **Grafana**: 监控面板（模拟）
- **Docker Stats**: 容器资源监控

## 🎯 使用说明

1. **访问应用**: 打开 http://localhost:8080
2. **登录**: 输入符合Linux用户名规则的用户名
3. **等待**: 系统会自动创建你的专属容器
4. **使用**: 在终端中自由操作，安装软件，运行代码
5. **聊天**: 使用右侧聊天室与其他用户交流
6. **观看**: 可以观看其他用户的终端操作（只读模式）
7. **监控**: 访问 /grafana 查看系统监控面板

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
- 网络隔离，容器间无法直接通信

## 🚀 部署优势

### 三合一架构优势
- **简化部署**: 只需要开放一个端口（8080）
- **统一管理**: 所有服务通过Docker Compose统一管理
- **负载均衡**: Nginx提供负载均衡和静态文件缓存
- **安全性**: 内部服务不直接暴露，通过代理访问

### 容器化优势
- **环境一致性**: 开发、测试、生产环境完全一致
- **快速部署**: 一键启动所有服务
- **资源隔离**: 每个服务独立运行，互不影响
- **易于扩展**: 可以轻松添加新的服务

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License

## 🙏 致谢

感谢开源社区的支持和贡献！