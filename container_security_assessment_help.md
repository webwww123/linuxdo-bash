# 容器安全评估与权限优化求助文档

## 问题背景

在实现Docker容器硬件伪装系统后，进行了全面的容器逃逸安全测试。虽然主要逃逸路径被阻止，但发现了一些安全风险和权限配置问题，需要专业指导进行进一步优化。

## 当前系统状态

### 硬件伪装功能
- ✅ **CPU伪装**: 24核Intel Xeon Platinum 8375C @ 2.90GHz
- ✅ **内存伪装**: 64GB内存显示
- ✅ **命令伪装**: nproc、lscpu、free、neofetch完全生效
- ✅ **用户体验**: 对用户完全透明

### 容器配置
```bash
# 启动参数
docker run --cap-drop=ALL --cap-add=SYS_ADMIN --cap-add=SETPCAP \
  --security-opt=no-new-privileges:true \
  -e ENABLE_HARDWARE_FAKE=true \
  linux-ubuntu:latest
```

### 技术实现
- **ENTRYPOINT模式**: 脚本在PID 1执行
- **权限降级**: 使用capsh尝试降级（部分生效）
- **文件清理**: 脚本执行后自动删除
- **隔离机制**: Docker基础隔离 + no-new-privileges

## 安全测试结果

### 逃逸尝试测试
进行了全面的容器逃逸攻击测试，包括：

#### 1. 基础信息收集
```bash
# 当前权限状态
Current: cap_setpcap,cap_sys_admin=ep

# 用户身份
uid=0(root) gid=0(root) groups=0(root)

# 容器化检测
0::/  # 确认在容器中
```

#### 2. 宿主机信息泄露
**成功获取的敏感信息**:
```bash
# 宿主机内核版本
Linux version 6.8.0-1027-azure (buildd@lcy02-amd64-088)

# 宿主机启动参数
BOOT_IMAGE=/boot/vmlinuz-6.8.0-1027-azure 
root=PARTUUID=0a49d4ad-a5c4-4492-bd05-267b58f96d09 
ro console=tty1 console=ttyS0

# Docker overlay路径
/var/lib/docker/overlay2/l/PGMJGIYNK7OMY3THDLFONN7L65:/var/lib/docker/overlay2/...

# 网络路由信息
Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask
eth0	00000000	010011AC	0003	0	0	0	00000000
```

#### 3. 逃逸尝试结果
**失败的逃逸尝试**:
- ❌ 磁盘设备挂载: `/dev/sda1`等设备不存在
- ❌ Docker socket访问: 未找到docker.sock
- ❌ 宿主机文件系统: 无法访问`/var/lib/docker`
- ❌ cgroup逃逸: 文件系统只读
- ❌ 特权挂载: tmpfs挂载被阻止

**成功的操作**:
- ✅ namespace创建: `unshare -m`命令成功执行
- ✅ 内存访问: 可以访问`/proc/kcore`文件
- ✅ 信息收集: 可以读取敏感的proc文件

## 发现的安全问题

### 问题1: 权限降级不完全
**现象**: 
```bash
# 脚本执行时权限降级成功
[INFO] 当前权限状态: Current: cap_setpcap,cap_sys_admin=ep
[SUCCESS] 权限已永久移除: Current: =

# 但docker exec时权限恢复
Current: cap_setpcap,cap_sys_admin=ep
```

**分析**: docker exec会重新分配容器初始权限，绕过了进程级权限降级

### 问题2: 敏感信息泄露
**泄露的信息**:
- 宿主机内核版本和编译信息
- 宿主机启动参数和根分区UUID
- Docker存储路径结构
- 网络配置信息

**风险评估**: 虽然无法直接逃逸，但信息泄露可能被用于其他攻击

### 问题3: 特权命令可执行
**可执行的危险操作**:
```bash
# namespace操作
unshare -m bash -c "echo 新namespace创建成功"  # 成功

# 内存访问
ls -la /proc/kcore  # 可访问
crw-rw-rw- 1 root root 1, 3 Jun 11 12:12 /proc/kcore

# 网络信息
cat /proc/net/route  # 可读取
```

## 环境信息

### 宿主机环境
- **云平台**: Microsoft Azure
- **操作系统**: Ubuntu 22.04 LTS
- **内核版本**: 6.8.0-1027-azure
- **Docker版本**: 24.0.7
- **真实硬件**: 4核CPU, 16GB内存

### 容器配置
- **基础镜像**: ubuntu:22.04
- **运行用户**: root
- **网络模式**: bridge
- **安全选项**: no-new-privileges:true
- **权限配置**: --cap-drop=ALL --cap-add=SYS_ADMIN --cap-add=SETPCAP

### 硬件伪装验证
```bash
# 伪装效果完美
nproc: 24
lscpu CPU数: 24
内存: 64GB
CPU型号: Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz
neofetch: CPU: Intel Xeon Platinum 8375C (24) @ 2.900GHz
         Memory: 15360MiB / 65536MiB
```

## 核心疑问

### 疑问1: 权限降级的持久性
如何确保权限降级对所有进入容器的进程都有效？当前的capsh方案只影响当前进程，docker exec会重新分配权限。

### 疑问2: 信息泄露的防护
如何在保持硬件伪装功能的同时，限制对敏感proc文件的访问？特别是：
- `/proc/version` - 宿主机内核信息
- `/proc/cmdline` - 宿主机启动参数
- `/proc/kcore` - 内存访问
- `/proc/net/route` - 网络信息

### 疑问3: 最小权限原则
硬件伪装完成后，是否可以进一步移除权限？当前保留的权限：
- `CAP_SYS_ADMIN` - 用于挂载操作
- `CAP_SETPCAP` - 用于权限降级

### 疑问4: namespace隔离加强
如何防止unshare等命令创建新的namespace？这些操作虽然没有直接导致逃逸，但增加了攻击面。

## 期望的安全改进

### 目标1: 完全的权限降级
- 硬件伪装完成后彻底移除所有危险权限
- 确保任何方式进入容器的进程都是低权限
- 保持硬件伪装效果不受影响

### 目标2: 信息泄露防护
- 限制对宿主机敏感信息的访问
- 保持必要的proc文件访问（用于硬件伪装）
- 实现细粒度的文件访问控制

### 目标3: 攻击面最小化
- 阻止危险命令的执行（unshare、mount等）
- 限制内存和内核信息访问
- 加强namespace隔离

### 目标4: 监控和检测
- 检测容器内的可疑活动
- 监控权限提升尝试
- 记录敏感文件访问

## 可接受的妥协

### 功能方面
- 轻微的容器启动延迟
- 某些高级容器功能的限制
- 适度的配置复杂度增加

### 安全方面
- 保持基本的Docker隔离机制
- 允许必要的硬件伪装操作
- 维持良好的用户体验

## 补充信息

### 当前防护有效性
**有效阻止的攻击**:
- 磁盘设备挂载攻击
- Docker API访问
- 宿主机文件系统直接访问
- cgroup限制修改
- 特权文件系统挂载

**需要改进的方面**:
- 权限降级的持久性
- 敏感信息访问控制
- 危险命令执行限制
- 内存访问权限控制

### 测试方法
所有安全测试都在隔离环境中进行，使用标准的容器逃逸技术：
- 挂载攻击
- namespace逃逸
- cgroup逃逸
- 设备访问
- 网络逃逸
- 内存访问
- 信息收集

### 业务需求
- 硬件伪装功能必须保持完全正常
- 用户体验不能受到影响
- 系统必须对用户完全透明
- 容器启动时间不能显著增加
