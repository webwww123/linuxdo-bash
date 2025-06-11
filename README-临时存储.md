# Linux Analytics - 临时存储配置

## 概述

本项目已针对Codespace等临时开发环境进行了优化，将容器数据和应用数据配置到临时存储区，充分利用临时环境的大容量临时存储空间。

## 存储架构

### 传统存储 vs 临时存储

| 组件 | 传统存储 | 临时存储 | 优势 |
|------|----------|----------|------|
| 用户容器数据 | `/var/lib/docker` | `/tmp/containers/` | 更大空间，更快访问 |
| 应用数据 | `backend/data/` | `/tmp/app-data/` | 避免占用工作区空间 |
| 应用日志 | `logs/` | `/tmp/app-logs/` | 日志不占用持久化空间 |
| Docker数据 | `/var/lib/docker` | `/tmp/docker-data/` | 镜像和容器使用临时空间 |

### 存储空间对比

在典型的Codespace环境中：

```bash
# 工作区空间 (有限)
/workspaces     32GB    (41% 已使用)

# 临时存储空间 (充足)
/tmp           118GB    (17% 已使用)
```

## 快速开始

### 1. 自动配置 (推荐)

项目会自动检测Codespace环境并配置临时存储：

```bash
# 直接启动，会自动配置临时存储
./start-all.sh
```

### 2. 手动配置

如果需要手动配置临时存储：

```bash
# 运行临时存储配置脚本
./setup-temp-storage.sh

# 启动应用
./start-all.sh
```

### 3. 使用Docker Compose

```bash
# 使用临时存储配置启动
docker-compose up -d
```

## 监控和管理

### 存储监控

```bash
# 完整检查
./monitor-temp-storage.sh

# 快速检查
./monitor-temp-storage.sh -q

# 实时监控
./monitor-temp-storage.sh -m

# 清理建议
./monitor-temp-storage.sh -c
```

### 存储清理

当临时存储空间不足时：

```bash
# 清理Docker缓存
docker system prune -f

# 清理构建缓存
docker builder prune -f

# 清理未使用的镜像
docker image prune -f

# 清理停止的容器
docker container prune -f
```

## 目录结构

```
/tmp/
├── containers/          # 用户容器数据
│   ├── user1/          # 用户1的home目录
│   ├── user2/          # 用户2的home目录
│   └── ...
├── app-data/           # 应用数据 (SQLite数据库等)
├── app-logs/           # 应用日志
└── docker-data/        # Docker数据 (镜像、容器等)

/workspaces/linuxdo-bash/
├── backend/
│   └── data -> /tmp/app-data    # 符号链接
├── logs -> /tmp/app-logs        # 符号链接
└── ...
```

## 配置说明

### 环境变量

- `TEMP_STORAGE=true` - 启用临时存储模式
- `CONTAINER_DATA_PATH=/tmp/containers` - 容器数据路径
- `CODESPACE_NAME` - 自动检测Codespace环境

### 容器配置

用户容器会自动挂载临时存储：

```javascript
// 容器创建配置
HostConfig: {
  Binds: [
    `/tmp/containers/${username}:/home/${username}:rw`,
    `/tmp/containers/${username}-var:/var/tmp:rw`
  ],
  Tmpfs: {
    '/tmp': 'rw,noexec,nosuid,size=1g'
  }
}
```

## 注意事项

### ⚠️ 数据持久性

- **临时存储在系统重启后会丢失所有数据**
- 适合临时开发和测试环境
- 重要数据请及时备份到外部存储

### 💡 最佳实践

1. **定期监控存储使用情况**
   ```bash
   ./monitor-temp-storage.sh -q
   ```

2. **及时清理不需要的数据**
   ```bash
   docker system prune -f
   ```

3. **备份重要配置**
   ```bash
   # 备份数据库
   cp /tmp/app-data/*.db ./backup/
   
   # 备份用户数据
   tar -czf backup/user-data.tar.gz /tmp/containers/
   ```

### 🔧 故障排除

#### 存储空间不足

```bash
# 检查存储使用情况
df -h /tmp

# 查看大文件
find /tmp -type f -size +100M -exec ls -lh {} \;

# 清理Docker数据
docker system prune -a -f
```

#### 符号链接问题

```bash
# 检查符号链接
ls -la backend/data logs

# 重新创建符号链接
rm -f backend/data logs
ln -sf /tmp/app-data backend/data
ln -sf /tmp/app-logs logs
```

#### 权限问题

```bash
# 修复权限
sudo chown -R $USER:$USER /tmp/containers
sudo chmod -R 755 /tmp/containers
```

## 性能优化

### 临时存储优势

1. **更大的可用空间** - 118GB vs 32GB
2. **更快的I/O性能** - 通常临时存储使用更快的存储介质
3. **减少工作区占用** - 保持工作区整洁
4. **自动清理** - 系统重启时自动清理

### 监控指标

- 临时存储使用率 < 80%
- 容器数量 < 50个
- 单个用户数据 < 1GB
- Docker镜像总大小 < 10GB

## 迁移指南

### 从持久化存储迁移到临时存储

```bash
# 1. 备份现有数据
cp -r backend/data backup/data-backup
cp -r logs backup/logs-backup

# 2. 运行配置脚本
./setup-temp-storage.sh

# 3. 恢复数据
cp -r backup/data-backup/* /tmp/app-data/
cp -r backup/logs-backup/* /tmp/app-logs/
```

### 从临时存储迁移到持久化存储

```bash
# 1. 备份临时数据
cp -r /tmp/app-data backup/
cp -r /tmp/app-logs backup/
cp -r /tmp/containers backup/

# 2. 删除符号链接
rm -f backend/data logs

# 3. 创建实际目录
mkdir -p backend/data logs

# 4. 恢复数据
cp -r backup/app-data/* backend/data/
cp -r backup/app-logs/* logs/
```

## 支持

如果遇到问题，请：

1. 运行诊断脚本：`./monitor-temp-storage.sh`
2. 检查日志：`tail -f /tmp/app-logs/*.log`
3. 查看Docker状态：`docker system df`
4. 提交Issue并附上诊断信息
