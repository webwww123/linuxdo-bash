# Docker容器内lscpu硬件伪装失败求助文档

## 问题描述

在Docker容器内实现硬件信息伪装时，`lscpu`命令仍然显示真实的4核CPU，而不是伪装的24核。其他伪装功能（nproc、内存、存储）工作正常。

## 环境信息

### 宿主机环境
- **平台**: GitHub Codespace
- **操作系统**: Ubuntu 20.04.6 LTS (containerized)
- **内核版本**: 6.8.0-1027-azure
- **真实硬件**: 4核AMD EPYC 7763, 15GB内存
- **Docker版本**: 27.5.1-1

### 容器环境
- **基础镜像**: Ubuntu 22.04
- **容器运行时**: Docker
- **权限配置**: CAP_SYS_ADMIN + no-new-privileges
- **目标伪装**: 24核CPU, 64GB内存, 1TB存储

## 当前伪装状态

### ✅ 成功的伪装
1. **nproc命令成功**:
   ```bash
   root@938eefea6f97:~# nproc
   24
   ```

2. **LD_PRELOAD钩子生效**:
   ```bash
   # LD_PRELOAD=/usr/local/lib/libfakehw.so 已设置
   # 劫持了 sysinfo(), sysconf(), get_nprocs() 等函数
   ```

3. **伪造文件生成成功**:
   ```bash
   [SUCCESS] cpuinfo: OK (37870 bytes)
   [SUCCESS] meminfo: OK (1293 bytes) 
   [SUCCESS] stat: OK (1671 bytes)
   ```

### ❌ 失败的伪装
**lscpu命令显示真实值**:
```bash
root@938eefea6f97:~# lscpu
CPU(s):                   4
  On-line CPU(s) list:    0-3
Vendor ID:                AuthenticAMD
  Model name:             AMD EPYC 7763 64-Core Processor
```

## 技术分析

### lscpu的数据源
通过strace分析，lscpu主要读取：
1. `/proc/cpuinfo` - ✅ 已成功伪装
2. `/sys/devices/system/cpu/` - ❌ 伪装失败
3. `/sys/devices/system/cpu/online` - ❌ 伪装失败
4. `/sys/devices/system/cpu/possible` - ❌ 伪装失败

### 容器内/sys文件系统状态
```bash
root@938eefea6f97:~# ls /sys/devices/system/cpu/
cpu0  cpu2  cpufreq  crash_hotplug  isolated    modalias   offline  possible  present  uevent
cpu1  cpu3  cpuidle  hotplug        kernel_max  nohz_full  online   power     smt      vulnerabilities

# 只有4个CPU目录，不是24个
root@938eefea6f97:~# cat /sys/devices/system/cpu/online
0-3

root@938eefea6f97:~# cat /sys/devices/system/cpu/possible
0-3
```

### 问题根因
1. **Docker容器隔离**: 容器内的`/sys`是由Docker重新挂载的，继承宿主机的真实硬件信息
2. **OverlayFS挂载失败**: 在容器内无法使用OverlayFS覆盖`/proc`或`/sys`
3. **文件系统只读**: 容器内的`/sys/devices/system/cpu`目录为只读，无法修改
4. **CPU目录数量**: lscpu通过扫描cpu0-cpu3目录来计算CPU数量，而不是读取控制文件

## 已尝试的解决方案

### 方案1: OverlayFS覆盖/proc
```bash
mount -t overlay overlay -o lowerdir=/proc,upperdir=/opt/fakeproc/overlay/upper,workdir=/opt/fakeproc/overlay/work /proc
```
**结果**: `mount: /proc: wrong fs type, bad option, bad superblock on overlay`

### 方案2: LD_PRELOAD钩子库
```c
// 劫持系统调用
int sysconf(int name) {
    if (name == _SC_NPROCESSORS_ONLN) return 24;
    return original_sysconf(name);
}
```
**结果**: nproc成功显示24，但lscpu仍读取/sys目录

### 方案3: bind mount覆盖单个文件
```bash
echo "0-23" > /tmp/fake_online
mount --bind /tmp/fake_online /sys/devices/system/cpu/online
```
**结果**: 权限被拒绝，/sys为只读文件系统

### 方案4: 创建伪造的CPU目录
尝试在容器内创建cpu4-cpu23目录：
```bash
mkdir -p /sys/devices/system/cpu/cpu{4..23}
```
**结果**: 权限被拒绝，/sys为只读

## 容器启动配置

### Docker运行参数
```bash
docker run --rm -it \
  --cap-add=SYS_ADMIN \
  --security-opt no-new-privileges:true \
  -e ENABLE_HARDWARE_FAKE=true \
  linux-ubuntu:latest /bin/bash
```

### 容器内权限状态
```bash
root@938eefea6f97:~# capsh --print
Current: = cap_chown,cap_dac_override,cap_fowner,cap_setgid,cap_setuid,cap_sys_admin+eip
```

### 硬件伪装脚本执行日志
```bash
[FAKE-HW] === 硬件伪装启动脚本 ===
[FAKE-HW] 检查容器权限...
[FAKE-HW] 权限检查通过
[FAKE-HW] 生成硬件伪装数据...
[SUCCESS] 伪造数据生成完成！
[FAKE-HW] 编译和安装 LD_PRELOAD 钩子库...
[FAKE-HW] libfakehw.so 编译成功
[FAKE-HW] 配置 LD_PRELOAD...
[FAKE-HW] LD_PRELOAD 配置完成
[FAKE-HW] 挂载 OverlayFS 覆盖 /proc...
mount: /proc: wrong fs type, bad option, bad superblock on overlay, missing codepage or helper program, or other error.
```

## 技术难点

1. **Docker的/sys隔离**: Docker为每个容器创建独立的/sys视图，继承宿主机硬件
2. **只读文件系统**: 容器内的/sys/devices/system/cpu为只读，无法修改
3. **内核限制**: 即使有CAP_SYS_ADMIN，某些/sys操作仍被内核拒绝
4. **lscpu实现**: lscpu通过扫描CPU目录数量而非读取控制文件来计算CPU数

## 错误信息

### OverlayFS挂载错误
```bash
mount: /proc: wrong fs type, bad option, bad superblock on overlay, missing codepage or helper program, or other error.
```

### /sys修改权限错误
```bash
mkdir: cannot create directory '/sys/devices/system/cpu/cpu4': Read-only file system
mount: /sys/devices/system/cpu/online: permission denied
```

## 相关代码文件

- `docker/hardware_fake_entrypoint.sh` - 硬件伪装启动脚本
- `docker/libfakehw.c` - LD_PRELOAD钩子库源码
- `docker/generate_fake_files.sh` - 伪造数据生成脚本
- `docker/Dockerfile.ubuntu` - 容器镜像构建文件
- `backend/services/containerManager.js` - 容器创建管理逻辑

## 测试环境

- **GitHub Codespace**: friendly-space-waddle-q7xp6jjr65vx26x6j
- **项目仓库**: webwww123/linuxdo-bash
- **Docker镜像**: linux-ubuntu:latest (已包含硬件伪装文件)
- **测试容器ID**: 938eefea6f97

## 期望解决方案

需要一种方法让容器内的`lscpu`命令显示24核，可能的技术方向：

1. **更深层的LD_PRELOAD**: 劫持lscpu使用的底层文件访问函数
2. **FUSE文件系统**: 在容器内使用FUSE重新实现/sys/devices/system/cpu
3. **容器启动时预配置**: 在容器创建阶段就配置好伪装的/sys结构
4. **自定义lscpu**: 提供一个伪装版本的lscpu命令

这个问题的核心是如何在Docker容器内成功伪装/sys/devices/system/cpu目录结构，使lscpu命令读取到伪造的24核CPU信息。
