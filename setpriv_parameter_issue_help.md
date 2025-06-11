# setpriv参数兼容性与权限降级实现求助文档

## 问题背景

在实现专业人士建议的"一次性高权→永久低权"容器硬件伪装系统时，遇到了setpriv命令参数兼容性问题，导致BoundingSet权限降级无法完成。硬件伪装功能已经完全成功，但权限降级步骤因setpriv参数错误而失败。

## 当前实现状态

### 成功实现的功能
- ✅ **完美硬件伪装**: 24核64GB配置完全生效
- ✅ **ENTRYPOINT模式**: 脚本在PID 1正确执行
- ✅ **高权限阶段**: 所有挂载操作成功完成
- ✅ **用户体验**: 对用户完全透明，所有监控命令显示高配置

### 硬件伪装验证结果
```bash
[SUCCESS] CPU sysfs伪装完成
[SUCCESS] proc文件伪装完成  
[SUCCESS] nproc命令伪装完成
[SUCCESS] lscpu命令伪装完成
[INFO] 验证硬件伪装效果...
  nproc: 24
  lscpu CPU数: 24
  内存: 64GB
[SUCCESS] 硬件伪装完成，开始权限降级...
```

## 核心技术问题

### 问题描述: setpriv参数不兼容

**错误信息**:
```bash
setpriv: unrecognized option '--apply-caps'
Try 'setpriv --help' for more information.
```

**当前使用的命令**:
```bash
setpriv --ambient-caps +cap_setpcap --inh-caps +cap_setpcap --apply-caps /bin/bash -c '...'
```

**问题分析**: 
- Ubuntu 22.04中的setpriv版本不支持`--apply-caps`参数
- 导致专业人士建议的权限降级方法无法执行
- 脚本在此处失败退出，无法完成BoundingSet权限删除

### 问题影响

1. **硬件伪装完全正常**: 24核64GB配置已经生效
2. **权限降级失败**: BoundingSet仍保留危险权限
3. **容器提前退出**: 脚本执行失败导致容器停止
4. **安全目标未达成**: 无法实现"永久低权"状态

## 环境信息

### 系统环境
- **操作系统**: Ubuntu 22.04 LTS
- **内核版本**: 6.8.0-1027-azure
- **Docker版本**: 24.0.7
- **容器基础镜像**: ubuntu:22.04

### setpriv版本信息
```bash
# 容器内setpriv版本
setpriv --help
# 显示不支持--apply-caps参数
```

### 当前权限状态
```bash
# 硬件伪装完成后的权限状态
Current: cap_setpcap,cap_sys_admin=ep
CapBnd: 0000000000200100  # 仍包含SYS_ADMIN和SETPCAP
CapEff: 0000000000200100
CapPrm: 0000000000200100
```

## 尝试的解决方案

### 方案1: 修正setpriv参数
**尝试**: 移除`--apply-caps`参数
```bash
setpriv --ambient-caps +cap_setpcap --inh-caps +cap_setpcap /bin/bash -c '...'
```
**结果**: 仍然有语法问题

### 方案2: 直接使用prctl系统调用
**实现**: 编写C程序直接调用prctl
```c
#include <sys/prctl.h>
#include <linux/capability.h>

int main() {
    if (prctl(PR_CAPBSET_DROP, CAP_SYS_ADMIN, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SYS_ADMIN");
        return 1;
    }
    if (prctl(PR_CAPBSET_DROP, CAP_SETPCAP, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SETPCAP");
        return 1;
    }
    return 0;
}
```
**问题**: 需要确保CAP_SETPCAP在Effective中才能成功

### 方案3: 使用capsh替代
**尝试**: 使用capsh进行权限降级
```bash
exec capsh --drop=cap_sys_admin --drop=cap_setpcap -- -c 'exec "$@"' -- "$@"
```
**限制**: 只影响当前进程，docker exec仍会获得高权限

## 具体技术疑问

### 疑问1: setpriv正确参数语法
- Ubuntu 22.04中setpriv支持的参数格式是什么？
- 如何正确设置ambient capabilities和inheritable capabilities？
- 是否有替代的命令行工具可以实现相同功能？

### 疑问2: prctl系统调用的前置条件
- 调用PR_CAPBSET_DROP需要什么样的权限状态？
- 如何确保CAP_SETPCAP在Effective中？
- 是否需要特定的进程状态或环境？

### 疑问3: 权限降级的时机和方法
- 在什么时机调用prctl最合适？
- 如何确保权限降级对docker exec也生效？
- 是否有其他方法实现BoundingSet的永久修改？

### 疑问4: 容器生命周期管理
- 如何在权限降级失败时让容器继续运行？
- 是否应该在权限降级失败时使用备用方案？
- 如何确保用户命令能够正常执行？

## 期望的解决方案

### 技术目标
1. **修复setpriv参数兼容性问题**
2. **成功实现BoundingSet权限降级**
3. **确保docker exec无法获得高权限**
4. **保持硬件伪装功能完全正常**
5. **容器能够正常运行用户命令**

### 实现要求
- 兼容Ubuntu 22.04环境
- 不影响已经成功的硬件伪装功能
- 权限降级必须对所有进程生效
- 容器启动后能够正常接受用户操作

## 当前工作代码

### 硬件伪装部分（已成功）
```bash
# CPU sysfs伪装
mount --move "$CPU_SYS" /run/.real_cpu
mount -t tmpfs -o size=32M,nr_inodes=200k,nosuid,nodev,mode=755 tmpfs "$CPU_SYS"
# 创建24个CPU目录...

# proc文件伪装
mount --bind /tmp/fake_meminfo /proc/meminfo
# 创建伪装命令...
```

### 权限降级部分（失败）
```bash
# 当前失败的实现
setpriv --ambient-caps +cap_setpcap --inh-caps +cap_setpcap --apply-caps /bin/bash -c '
    # prctl系统调用...
'
```

### 期望的权限状态
```bash
# 目标权限状态
CapBnd: 0000000000000000  # 所有危险权限已删除
CapEff: 0000000000000000  # 无有效权限
CapPrm: 0000000000000000  # 无允许权限
```

## 业务影响

### 当前状况
- **硬件伪装**: 完全成功，用户看到24核64GB
- **安全防护**: 部分失败，仍有高权限残留
- **用户体验**: 因容器退出而无法使用

### 紧急程度
- **功能影响**: 中等（硬件伪装正常）
- **安全影响**: 高（权限未降级）
- **用户影响**: 高（容器无法正常使用）

## 补充信息

### 容器启动参数
```bash
docker run --cap-drop=ALL --cap-add=SYS_ADMIN --cap-add=SETPCAP \
  --security-opt=no-new-privileges:true \
  -e ENABLE_HARDWARE_FAKE=true \
  linux-ubuntu:latest
```

### 执行日志
```bash
[INFO] 启动安全硬件伪装系统...
[SUCCESS] CPU sysfs伪装完成
[SUCCESS] proc文件伪装完成
[SUCCESS] nproc命令伪装完成
[SUCCESS] lscpu命令伪装完成
[SUCCESS] 硬件伪装完成，开始权限降级...
[INFO] 使用专业建议的方法永久删除BoundingSet中的危险权限...
[INFO] 确保CAP_SETPCAP在Effective中...
setpriv: unrecognized option '--apply-caps'
# 脚本在此处失败退出
```

### 验证方法
```bash
# 硬件伪装验证（成功）
nproc                    # 应显示: 24
lscpu | grep "CPU(s):"   # 应显示: 24
free -h                  # 应显示: 64GB

# 权限降级验证（失败）
grep CapBnd /proc/self/status  # 当前: 0000000000200100, 期望: 0000000000000000
```

这是一个在硬件伪装功能完全成功基础上的权限降级技术实现问题，需要专业指导来解决setpriv参数兼容性和prctl系统调用的正确使用方法。
