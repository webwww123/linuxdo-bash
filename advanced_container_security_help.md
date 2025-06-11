# 高级容器安全与BoundingSet权限降级求助文档

## 问题背景

基于专业人士的建议，我们实现了"一次性高权→永久低权"的容器硬件伪装系统。虽然核心功能已经成功实现，但在BoundingSet权限降级和高级安全防护方面遇到了技术难题，需要进一步的专业指导。

## 当前实现状态

### 成功实现的功能
- ✅ **完美硬件伪装**: 24核64GB配置完全生效
- ✅ **ENTRYPOINT模式**: 脚本在PID 1正确执行
- ✅ **基础权限降级**: no-new-privileges安全选项生效
- ✅ **用户体验**: 对用户完全透明，所有监控命令正常显示高配置

### 技术实现架构
```bash
# 容器启动配置
docker run --cap-drop=ALL --cap-add=SYS_ADMIN --cap-add=SETPCAP \
  --security-opt=no-new-privileges:true \
  -e ENABLE_HARDWARE_FAKE=true \
  linux-ubuntu:latest

# ENTRYPOINT脚本执行流程
1. 硬件伪装操作 (需要SYS_ADMIN)
2. prctl系统调用删除BoundingSet权限
3. 清理脚本文件
4. 执行用户命令
```

## 核心技术问题

### 问题1: BoundingSet权限降级不完全生效

**现象描述**:
```bash
# PID 1中prctl调用报告成功
Successfully dropped CAP_SYS_ADMIN from BoundingSet
Successfully dropped CAP_SETPCAP from BoundingSet

# 但docker exec进入后仍显示权限
Current: cap_setpcap,cap_sys_admin=ep

# /proc/self/status显示权限仍存在
CapBnd: 0000000000200100  # 包含CAP_SETPCAP(8)和CAP_SYS_ADMIN(21)
```

**使用的C代码**:
```c
#include <sys/prctl.h>
#include <linux/capability.h>

int main() {
    // 永久删除CAP_SYS_ADMIN从BoundingSet
    if (prctl(PR_CAPBSET_DROP, CAP_SYS_ADMIN, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SYS_ADMIN");
        return 1;
    }
    
    // 永久删除CAP_SETPCAP从BoundingSet  
    if (prctl(PR_CAPBSET_DROP, CAP_SETPCAP, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SETPCAP");
        return 1;
    }
    
    return 0;
}
```

**疑问**: 为什么prctl调用成功但BoundingSet实际未改变？是否需要特殊的执行环境或额外的系统调用？

### 问题2: docker exec权限重新分配机制

**现象**: 即使在PID 1中成功降级权限，`docker exec`创建的新进程仍然获得容器初始配置的权限。

**权限对比**:
```bash
# PID 1权限状态
CapBnd: 0000000000200100

# docker exec进程权限状态  
CapBnd: 0000000000200100  # 相同的权限值
```

**疑问**: 如何确保BoundingSet的修改能够影响所有后续进程，包括通过docker exec创建的进程？

### 问题3: 敏感信息访问控制

**当前状况**:
```bash
# 仍可访问的敏感信息
cat /proc/version     # 显示宿主机内核信息
cat /proc/cmdline     # 显示宿主机启动参数
cat /proc/kcore       # 可以访问内存映像
cat /proc/net/route   # 显示网络路由信息
```

**尝试的解决方案**:
- Docker SecurityOpt中的masked-paths和readonly-paths语法错误
- 无法正确配置seccomp profile
- AppArmor配置在当前环境中不可用

**疑问**: 在不影响硬件伪装功能的前提下，如何有效限制对这些敏感文件的访问？

### 问题4: 危险系统调用阻断

**当前状况**:
```bash
# 仍可执行的危险操作
unshare -m bash -c "echo 新namespace创建成功"  # 成功执行
mount -t tmpfs tmpfs /tmp/test                # 被阻止（挂载点不存在）
```

**seccomp配置尝试**:
```json
{
  "names": ["unshare", "mount", "umount", "pivot_root"],
  "action": "SCMP_ACT_KILL"
}
```

**疑问**: 为什么seccomp配置没有生效？如何正确配置seccomp来阻断这些系统调用？

## 环境信息

### 宿主机环境
- **云平台**: Microsoft Azure Codespace
- **操作系统**: Ubuntu 22.04 LTS  
- **内核版本**: 6.8.0-1027-azure
- **Docker版本**: 24.0.7
- **真实硬件**: 4核CPU, 16GB内存

### 容器配置
```bash
# 当前启动参数
--cap-drop=ALL 
--cap-add=SYS_ADMIN 
--cap-add=SETPCAP
--security-opt=no-new-privileges:true

# 尝试但失败的配置
--security-opt=seccomp=seccomp-hardened.json        # 语法错误
--security-opt=masked-paths=/proc/kcore             # 不支持
--security-opt=readonly-paths=/proc/version         # 不支持
```

### 权限状态详细信息
```bash
# PID 1权限状态
CapInh: 0000000000000000  # 继承权限集
CapPrm: 0000000000200100  # 允许权限集  
CapEff: 0000000000200100  # 有效权限集
CapBnd: 0000000000200100  # 边界权限集
CapAmb: 0000000000000000  # 环境权限集

# 权限解码
0x100    = CAP_SETPCAP (8)
0x200000 = CAP_SYS_ADMIN (21)
```

## 具体技术疑问

### 疑问1: prctl系统调用的正确使用方法
- prctl(PR_CAPBSET_DROP)调用成功但权限仍存在的原因？
- 是否需要在特定的进程状态下调用？
- 是否需要配合其他系统调用使用？

### 疑问2: Docker权限继承机制
- docker exec如何分配新进程的权限？
- BoundingSet修改如何影响容器级别的权限分配？
- 是否存在容器级别的权限配置覆盖进程级别的修改？

### 疑问3: seccomp配置的正确语法
- 当前Docker版本支持的seccomp配置格式？
- 如何正确引用seccomp profile文件？
- seccomp规则不生效的常见原因？

### 疑问4: 文件系统访问控制
- 如何在保持硬件伪装的同时限制/proc文件访问？
- masked-paths和readonly-paths的正确配置方法？
- 是否有其他方法实现细粒度的文件访问控制？

### 疑问5: 权限降级的时机和方法
- 在容器生命周期的哪个阶段进行权限降级最有效？
- 除了prctl之外是否有其他方法永久修改BoundingSet？
- 如何确保权限降级对所有进程都生效？

## 测试验证方法

### 当前测试脚本
```bash
# 权限状态检查
capsh --print | grep "Bounding set:"
grep CapBnd /proc/self/status

# 危险操作测试
unshare -m bash -c "echo test"
mount -t tmpfs tmpfs /tmp/test

# 敏感信息访问测试  
cat /proc/version
cat /proc/kcore | head -1

# 硬件伪装验证
nproc
lscpu | grep "CPU(s):"
grep MemTotal /proc/meminfo
```

### 期望的测试结果
```bash
# 理想的权限状态
CapBnd: 0000000000000000  # 所有危险权限已删除

# 理想的安全状态
unshare: Operation not permitted
mount: Operation not permitted
cat /proc/version: Permission denied
cat /proc/kcore: Permission denied

# 保持的功能
nproc: 24
lscpu CPU(s): 24  
MemTotal: 67108864 kB
```

## 业务需求约束

### 必须保持的功能
- 硬件伪装效果完全正常（24核64GB显示）
- 用户体验完全透明
- 容器启动时间不能显著增加
- 所有监控命令正常工作（nproc、lscpu、free、htop、neofetch等）

### 可接受的限制
- 某些高级容器功能的限制
- 适度的配置复杂度增加
- 轻微的性能开销
- 部分系统调用的阻断

### 安全目标
- 完全阻断容器逃逸路径
- 限制敏感信息泄露
- 防止权限提升
- 阻断危险系统调用

## 补充技术信息

### 硬件伪装实现方法
```bash
# CPU伪装 - tmpfs覆盖sysfs
mount -t tmpfs tmpfs /sys/devices/system/cpu
# 创建24个CPU目录和控制文件

# 内存伪装 - bind mount覆盖proc文件
mount --bind /tmp/fake_meminfo /proc/meminfo

# 命令伪装 - 替换可执行文件
cp /tmp/fake_nproc /usr/local/bin/nproc
```

### 当前安全防护状态
```bash
# 有效的防护
- Docker基础隔离机制正常
- 磁盘设备访问被阻止
- Docker socket未暴露
- cgroup文件系统只读
- 特权文件系统挂载被阻止

# 需要改进的方面
- BoundingSet权限降级
- 敏感proc文件访问控制
- 危险系统调用阻断
- 信息泄露防护
```

### 错误日志和调试信息
```bash
# seccomp配置错误
invalid --security-opt 2: "masked-paths=/proc/kcore:/proc/latency_stats:/proc/acpi"

# prctl调用成功但权限未变化
Successfully dropped CAP_SYS_ADMIN from BoundingSet
Successfully dropped CAP_SETPCAP from BoundingSet
# 但 /proc/self/status 仍显示权限存在
```

## 期望的解决方案

### 技术方案期望
1. **正确的BoundingSet权限降级方法**
2. **有效的seccomp配置语法和应用方法**  
3. **敏感文件访问控制的实现方案**
4. **危险系统调用的完全阻断方法**
5. **权限降级持久性的保证机制**

### 实现复杂度期望
- 优先考虑技术可行性
- 可接受适度的配置复杂度
- 希望有详细的实现步骤
- 需要可验证的测试方法

这是一个在硬件伪装功能基础上进行高级安全加固的技术挑战，涉及Linux权限管理、Docker安全机制、系统调用控制等多个复杂领域。
