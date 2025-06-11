# nproc CPU亲和性伪装问题求助文档

## 问题背景

基于专业人士的inode解决方案，硬件伪装系统已基本成功实现，但遇到`nproc`命令仍显示真实CPU数量的问题。

## 当前实现状态

### 已成功的部分
- ✅ **tmpfs sysfs伪装**：`/sys/devices/system/cpu`完全伪装，包含24个CPU目录
- ✅ **proc文件伪装**：`/proc/cpuinfo`和`/proc/meminfo`显示24核64GB
- ✅ **lscpu命令伪装**：显示24核Intel Xeon Platinum 8375C
- ✅ **用户体验**：`neofetch`等工具显示高配置硬件
- ✅ **隐蔽性**：无LD_PRELOAD痕迹，无伪装库文件

### 核心技术实现
```bash
# tmpfs覆盖sysfs（已解决inode问题）
mount -t tmpfs -o size=32M,nr_inodes=200k,mode=755,nosuid,nodev tmpfs /sys/devices/system/cpu

# 创建伪装文件
printf '0-23\n' > /sys/devices/system/cpu/online
printf '0-23\n' > /sys/devices/system/cpu/possible
printf '0-23\n' > /sys/devices/system/cpu/present

# 创建24个CPU目录
for i in $(seq 0 23); do
    mkdir -p /sys/devices/system/cpu/cpu$i
done
```

## 遇到的具体问题

### 问题描述
`nproc`命令仍然显示真实的4核，而不是伪装的24核。

### 测试结果对比
```bash
# 成功的命令
lscpu | grep "^CPU(s):"           # 输出：CPU(s): 24
grep -c "^processor" /proc/cpuinfo # 输出：24
cat /sys/devices/system/cpu/online # 输出：0-23
neofetch | grep CPU               # 输出：Intel Xeon Platinum 8375C (24) @ 2.900GHz

# 问题命令
nproc                             # 输出：4 (期望：24)
```

### 根因分析

#### 1. CPU亲和性限制
```bash
taskset -p $$                     # 输出：pid's current affinity mask: f
# 二进制1111表示只有4个CPU可用
```

#### 2. /proc/stat文件未伪装
```bash
grep "^cpu" /proc/stat | wc -l    # 输出：5 (cpu总行+4个cpu核心)
# 当前只伪装了/proc/cpuinfo和/proc/meminfo，未伪装/proc/stat
```

#### 3. nproc的实现机制
根据strace跟踪，`nproc`可能使用以下方法之一：
- `sched_getaffinity()`系统调用获取CPU亲和性
- 读取`/proc/stat`中的CPU行数
- 其他内核接口而非sysfs文件

## 技术分析

### nproc vs lscpu的差异
| 命令 | 数据源 | 当前状态 | 伪装效果 |
|------|--------|----------|----------|
| `lscpu` | `/sys/devices/system/cpu/` + `/proc/cpuinfo` | 已伪装 | ✅ 24核 |
| `nproc` | `sched_getaffinity()` 或 `/proc/stat` | 未伪装 | ❌ 4核 |
| `neofetch` | 综合多个源 | 部分伪装 | ✅ 24核 |

### 容器环境限制
- **容器类型**：Docker容器，非特权模式
- **权限**：`--privileged --cap-add=SYS_ADMIN`
- **CPU限制**：宿主机4核，容器继承相同的CPU亲和性
- **内核版本**：Linux 6.5.0-1025-azure

## 已尝试的解决方案

### 方案1：检查sysfs伪装完整性
```bash
# 验证结果 - 伪装文件完全正确
cat /sys/devices/system/cpu/online    # 0-23 ✅
cat /sys/devices/system/cpu/possible  # 0-23 ✅
ls /sys/devices/system/cpu/ | grep -c "^cpu[0-9]"  # 24 ✅
```

### 方案2：验证mount状态
```bash
# tmpfs挂载正常
mount | grep cpu
# tmpfs on /sys/devices/system/cpu type tmpfs (ro,nosuid,nodev,relatime,size=32768k,nr_inodes=204800,mode=755,inode64)
```

### 方案3：检查权限和能力
```bash
# 权限充足
capsh --print | grep cap_sys_admin  # ✅ 存在
```

## 技术疑问

### 问题1：CPU亲和性伪装
如何在容器中伪装`sched_getaffinity()`系统调用的返回值？是否需要：
- 使用LD_PRELOAD劫持`sched_getaffinity()`函数
- 修改容器的CPU亲和性设置
- 在内核层面进行更深层的伪装

### 问题2：/proc/stat伪装
是否需要伪装`/proc/stat`文件？当前实现：
```bash
# 当前/proc/stat只显示4个CPU
grep "^cpu" /proc/stat
# cpu  92946 13 88771 2698823 16353 0 3583 0 0 0
# cpu0 22987 9 22335 673729 4628 0 1217 0 0 0
# cpu1 23036 2 21910 676365 3253 0 708 0 0 0
# cpu2 23808 0 22582 674385 3665 0 719 0 0 0
# cpu3 23114 0 21942 674342 4806 0 938 0 0 0
```

### 问题3：nproc的具体实现
`nproc`命令的GNU coreutils实现具体使用哪个系统调用或文件？
- 是否读取`/proc/stat`
- 是否调用`sched_getaffinity()`
- 是否有其他数据源

### 问题4：容器限制突破
在Docker容器中是否可能完全伪装CPU亲和性？需要哪些额外权限或配置？

## 期望的技术指导

### 目标1：完善nproc伪装
使`nproc`命令也显示24核，与其他命令保持一致。

### 目标2：保持隐蔽性
在实现nproc伪装的同时，不引入新的痕迹文件或可疑配置。

### 目标3：系统兼容性
确保伪装方案在不同Linux发行版和内核版本中稳定工作。

## 当前工作环境

### 容器配置
```bash
docker run --privileged --cap-add=SYS_ADMIN -d --name test linux-ubuntu:latest
```

### 验证脚本
```bash
# 完整验证命令
echo "nproc: $(nproc)"
echo "lscpu: $(lscpu | grep '^CPU(s):' | awk '{print $2}')"
echo "cpuinfo: $(grep -c '^processor' /proc/cpuinfo)"
echo "sysfs online: $(cat /sys/devices/system/cpu/online)"
echo "affinity: $(taskset -p $$ | awk '{print $NF}')"
echo "stat cpus: $(grep '^cpu[0-9]' /proc/stat | wc -l)"
```

### 当前输出
```
nproc: 4          ← 需要修复
lscpu: 24         ← 正常
cpuinfo: 24       ← 正常  
sysfs online: 0-23 ← 正常
affinity: f       ← 问题根源？
stat cpus: 4      ← 可能需要伪装
```

## 补充信息

### 成功案例参考
之前使用LD_PRELOAD成功伪装过`nproc`，但留有痕迹文件：
```c
// libfakehw.c 中的实现
long sysconf(int name) {
    if (name == _SC_NPROCESSORS_ONLN) {
        return 24;
    }
    return orig_sysconf(name);
}
```

### 隐蔽性要求
新方案必须避免：
- `/etc/ld.so.preload`配置文件
- `/usr/local/lib/`下的伪装库文件
- 任何可被用户发现的痕迹文件

### 性能要求
- 伪装过程在容器启动30秒内完成
- 不影响正常的系统性能
- 对用户完全透明

## 技术栈信息

- **操作系统**：Ubuntu 22.04 LTS
- **容器运行时**：Docker 24.0.7
- **内核版本**：Linux 6.5.0-1025-azure
- **GNU coreutils**：8.32 (nproc命令版本)
- **glibc版本**：2.35
