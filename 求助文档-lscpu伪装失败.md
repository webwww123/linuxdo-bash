# lscpu硬件伪装失败求助文档

## 问题描述

在Docker容器内实现硬件信息伪装时，`lscpu`命令仍然显示真实的4核CPU，而不是伪装的24核。其他伪装功能（内存、存储、部分CPU信息）工作正常。

## 环境信息

### 宿主机环境
- **平台**: GitHub Codespace
- **操作系统**: Ubuntu 20.04.6 LTS (containerized)
- **内核版本**: 6.8.0-1027-azure
- **真实硬件**: 4核CPU, 15GB内存
- **Docker版本**: 27.5.1-1

### 容器环境
- **基础镜像**: Ubuntu 22.04
- **容器运行时**: Docker
- **权限配置**: 非特权容器 + CAP_SYS_ADMIN
- **目标伪装**: 24核CPU, 64GB内存, 1TB存储

## 当前伪装状态

### ✅ 成功的伪装
1. **内存信息完全成功**:
   ```bash
   # 宿主机
   $ free -h
   Mem:           64Gi        11Gi        32Gi       2.0Gi        20Gi        48Gi
   
   # 容器内
   $ docker exec container free -h
   Mem:           64Gi        11Gi        32Gi       2.0Gi        20Gi        48Gi
   ```

2. **存储信息成功**:
   ```bash
   $ df -h /
   overlay         1.0T  512G  512G  50% /
   ```

3. **部分CPU信息成功**:
   ```bash
   # nproc命令成功
   $ nproc
   24
   
   # /proc/cpuinfo成功
   $ cat /proc/cpuinfo | grep processor | wc -l
   24
   
   # neofetch显示成功
   CPU: Intel Xeon Platinum 8375C (24) @ 2.900GHz
   ```

### ❌ 失败的伪装
**lscpu命令显示真实值**:
```bash
# 宿主机上 (伪装成功)
$ lscpu | grep "CPU(s):"
CPU(s):              24

# 容器内 (伪装失败)
$ docker exec container lscpu | grep "CPU(s):"
CPU(s):                               4
NUMA node0 CPU(s):                    0-3
```

## 已实施的技术方案

### 1. LD_PRELOAD钩子库
- **文件**: `/usr/local/lib/libfakehw.so`
- **劫持函数**: `sysinfo()`, `sysconf()`, `get_nprocs()`, `sched_getaffinity()`
- **状态**: 部分生效 (nproc显示24核)

### 2. /proc文件系统伪装
- **方法**: bind mount覆盖
- **文件**: `/proc/cpuinfo`, `/proc/meminfo`, `/proc/stat`
- **状态**: 完全生效

### 3. /sys文件系统伪装
- **方法**: bind mount覆盖
- **文件**: `/sys/devices/system/cpu/online`, `present`, `possible`
- **状态**: 宿主机生效，容器内失效

## 技术分析

### lscpu的数据源分析
通过strace分析，lscpu读取以下数据源：
```bash
$ strace -e trace=openat,read lscpu 2>&1 | grep -E "(sys|proc)"
openat(AT_FDCWD, "/proc", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/sys/devices/system/cpu", O_RDONLY|O_CLOEXEC) = 4
openat(AT_FDCWD, "/sys/devices/system/node", O_RDONLY|O_CLOEXEC) = 5
```

### 容器内文件系统状态
```bash
# 容器内的挂载情况
$ docker exec container mount | grep cpu
# (无输出 - 说明容器内没有CPU相关的特殊挂载)

# 容器内的/sys/devices/system/cpu目录
$ docker exec container ls /sys/devices/system/cpu/ | grep cpu
cpu0
cpu1  
cpu2
cpu3
# (只有4个CPU目录，不是24个)

# 容器内的CPU控制文件
$ docker exec container cat /sys/devices/system/cpu/online
0-3
$ docker exec container cat /sys/devices/system/cpu/possible  
0-3
```

## 问题根因

1. **容器隔离**: 宿主机上的bind mount和文件系统伪装不会自动传递到容器内
2. **/sys文件系统**: 容器内的/sys是由Docker重新挂载的，不继承宿主机的修改
3. **权限限制**: 即使容器有CAP_SYS_ADMIN权限，对/sys的修改仍然受限

## 已尝试的解决方案

### 方案1: 容器启动时挂载
在容器创建时添加卷挂载：
```javascript
Binds: [
  `/tmp/fake_cpu_sys:/sys/devices/system/cpu:rw`
]
```
**结果**: Docker拒绝挂载到/sys路径

### 方案2: 容器内执行伪装脚本
在容器启动后执行硬件伪装脚本：
```bash
docker exec container /opt/hardware_fake_entrypoint.sh
```
**结果**: /sys文件系统只读，无法修改

### 方案3: OverlayFS覆盖
尝试在容器内使用OverlayFS覆盖/sys：
```bash
mount -t overlay overlay -o lowerdir=/sys/devices/system/cpu,upperdir=/opt/fake,workdir=/opt/work /sys/devices/system/cpu
```
**结果**: 权限被拒绝

## 当前容器配置

### Docker容器创建参数
```javascript
{
  Image: 'linux-ubuntu:latest',
  Env: ['ENABLE_HARDWARE_FAKE=true'],
  HostConfig: {
    Memory: 512 * 1024 * 1024,
    CpuShares: 512,
    CapAdd: ['CHOWN', 'DAC_OVERRIDE', 'FOWNER', 'SETGID', 'SETUID', 'SYS_ADMIN'],
    CapDrop: ['ALL'],
    SecurityOpt: ['no-new-privileges:true'],
    Binds: [
      `/tmp/containers/${username}:/home/${username}:rw`,
      `/tmp/containers/${username}-var:/var/tmp:rw`
    ]
  }
}
```

### 容器内权限状态
```bash
$ docker exec container capsh --print
Current: = cap_chown,cap_dac_override,cap_fowner,cap_setgid,cap_setuid,cap_sys_admin+eip
```

## 技术难点

1. **Docker的/sys隔离**: Docker为每个容器创建独立的/sys视图
2. **只读文件系统**: 容器内的/sys/devices/system/cpu为只读
3. **内核限制**: 即使有CAP_SYS_ADMIN，某些/sys操作仍被内核拒绝
4. **命名空间隔离**: 容器的PID/Mount命名空间与宿主机隔离

## 期望解决方案

需要一种方法让容器内的`lscpu`命令显示24核，可能的方向：

1. **容器启动时预配置**: 在容器创建阶段就配置好伪装的/sys结构
2. **更深层的LD_PRELOAD**: 劫持更底层的系统调用或文件访问
3. **自定义容器运行时**: 修改Docker的容器创建过程
4. **FUSE文件系统**: 在容器内使用FUSE重新实现/sys/devices/system/cpu

## 补充信息

### 相关代码文件
- `backend/services/containerManager.js` - 容器创建逻辑
- `docker/libfakehw.c` - LD_PRELOAD钩子库
- `docker/hardware_fake_entrypoint.sh` - 硬件伪装启动脚本
- `docker/generate_fake_files.sh` - 伪造数据生成脚本

### 测试环境
- GitHub Codespace: friendly-space-waddle-q7xp6jjr65vx26x6j
- 项目仓库: webwww123/linuxdo-bash
- Docker daemon运行在临时存储: /tmp/docker-data

### 错误日志
```bash
# 容器内尝试修改/sys时的错误
mount: /sys/devices/system/cpu: permission denied
chmod: cannot access '/sys/devices/system/cpu/possible': Read-only file system
```

这个问题的核心是如何在Docker容器内成功伪装/sys/devices/system/cpu目录结构，使lscpu命令读取到伪造的24核CPU信息。
