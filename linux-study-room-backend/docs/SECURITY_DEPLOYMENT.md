# Linux Study Room 容器网络安全部署指南

## 概述

本项目实现了以下安全措施：
- 🔒 **容器隔离**：禁止容器间通信（ICC disabled）
- 🛡️ **防火墙规则**：封锁 SSH/RDP/代理/VPN 端口
- 📊 **带宽限制**：100KB/s 限速
- 🚫 **隧道防护**：阻止反向隧道和代理协议

---

## 快速部署

### 1. 部署后端（自动创建隔离网络）

```bash
./lsr-backend
```

后端启动时会自动创建 `lsr-isolated` 网络。

### 2. 配置防火墙和带宽限制

在 **Linux 服务器** 上以 root 权限运行：

```bash
sudo bash scripts/security-setup.sh
```

---

## 安全配置详情

### 自动应用（代码层面）

| 安全措施 | 实现方式 |
|---------|---------|
| 容器网络隔离 | `NetworkMode: "lsr-isolated"` |
| 禁止容器互通 | `enable_icc=false` |
| 移除危险权限 | `CapDrop: ALL`, 仅保留必要权限 |
| 防止提权 | `SecurityOpt: no-new-privileges` |

### 手动配置（脚本）

运行 `security-setup.sh` 后应用：

| 封锁端口 | 用途 |
|---------|------|
| 22 | SSH（防反向隧道）|
| 3389 | RDP |
| 1080 | SOCKS5 代理 |
| 8080 | HTTP 代理 |
| 1194 | OpenVPN |
| 51820 | WireGuard |
| 9050 | Tor |

| 白名单端口 | 用途 |
|----------|------|
| 80 | HTTP |
| 443 | HTTPS |
| 53 | DNS |

---

## 验证测试

### 1. 检查网络隔离

```bash
# 查看网络
docker network ls | grep lsr-isolated

# 查看网络配置
docker network inspect lsr-isolated
# 应该看到 "com.docker.network.bridge.enable_icc": "false"
```

### 2. 测试容器间隔离

```bash
# 启动两个容器
docker run -d --name test1 --network lsr-isolated alpine sleep 3600
docker run -d --name test2 --network lsr-isolated alpine sleep 3600

# 尝试互相 ping（应该失败）
docker exec test1 ping -c 1 test2
# 结果: ping: bad address 'test2' 或超时

# 清理
docker rm -f test1 test2
```

### 3. 测试端口封锁

```bash
# 在容器内尝试连接 SSH（应该失败）
docker run --rm --network lsr-isolated alpine sh -c "nc -zv 1.2.3.4 22"
# 结果: 超时或被拒绝

# 测试 HTTPS（应该成功）
docker run --rm --network lsr-isolated alpine sh -c "wget -q -O- https://httpbin.org/get"
```

### 4. 检查防火墙规则

```bash
# 查看 DOCKER-USER 规则
sudo iptables -L DOCKER-USER -n -v --line-numbers
```

---

## 故障排查

### 问题：容器无法访问互联网

1. 检查 DNS 是否被允许：
   ```bash
   sudo iptables -L DOCKER-USER -n | grep 53
   ```

2. 重新运行安全脚本：
   ```bash
   sudo bash scripts/security-setup.sh
   ```

### 问题：防火墙规则重启后丢失

添加到开机脚本：
```bash
# /etc/rc.local 或 systemd service
/opt/linux-study-room-backend/scripts/security-setup.sh
```

---

## 文件清单

```
linux-study-room-backend/
├── internal/service/docker.go    # 网络隔离代码
├── scripts/security-setup.sh     # 防火墙配置脚本
└── docs/SECURITY_DEPLOYMENT.md   # 本文档
```
