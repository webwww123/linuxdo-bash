# 权限降级与硬件伪装冲突问题求助文档

## 问题描述

在实现Docker容器的安全硬件伪装系统时，遇到权限降级与硬件伪装功能冲突的问题。系统设计为"一次性高权→永久降权"模式，但在实际部署中发现硬件伪装脚本未能正确执行。

## 技术背景

### 系统架构
- **容器运行时**: Docker 24.0.7
- **基础镜像**: Ubuntu 22.04 LTS
- **内核版本**: Linux 6.8.0-1027-azure
- **容器管理**: Node.js + dockerode库

### 硬件伪装技术方案
使用以下技术实现24核64GB硬件伪装：
1. **tmpfs覆盖sysfs**: `mount -t tmpfs tmpfs /sys/devices/system/cpu`
2. **bind mount覆盖proc**: 替换`/proc/meminfo`和`/proc/cpuinfo`
3. **命令替换**: 替换`nproc`和`lscpu`可执行文件
4. **权限需求**: 需要`CAP_SYS_ADMIN`和`CAP_SETPCAP`权限

### 权限降级方案
基于专业建议实现的安全方案：
```bash
# 启动参数
--cap-drop=ALL --cap-add=SYS_ADMIN --cap-add=SETPCAP --security-opt=no-new-privileges:true

# 权限降级命令
exec capsh --drop=cap_sys_admin --drop=cap_setpcap -- -c 'exec /bin/bash'
```

## 当前问题状况

### 问题1：镜像构建问题
**现象**: 容器中缺少硬件伪装脚本文件
```bash
# 容器内检查结果
$ ls -la /opt/
total 8
drwxr-xr-x 1 root root 4096 Jun 11 11:32 .
drwxr-xr-x 1 root root 4096 Jun 11 11:32 ..

# 预期应该存在
-rwxr-xr-x 1 root root 7937 Jun 11 11:19 system_init.sh
```

**影响**: 硬件伪装完全失效，显示真实硬件信息

### 问题2：容器管理器调用流程
**当前流程**:
```javascript
// containerManager.js setupUser方法
const commands = [
  `ENABLE_HARDWARE_FAKE=true /opt/system_init.sh`,  // 第一个命令
  `useradd -m -s /bin/bash ${username}`,
  // ... 其他用户设置命令
];

for (const cmd of commands) {
  const exec = await container.exec({
    Cmd: ['bash', '-c', cmd],
    AttachStdout: true,
    AttachStderr: true
  });
  await exec.start();
}
```

**问题**: 脚本不存在导致第一个命令失败，但后续命令继续执行

### 问题3：权限状态不一致
**测试结果**:
```bash
# 直接测试权限降级脚本（成功）
[INFO] 当前权限状态:
Current: cap_setpcap,cap_sys_admin=ep
[SUCCESS] 权限已永久移除
[INFO] 当前权限状态:
Current: =

# 但通过容器管理器创建的容器（失败）
Current: cap_chown,cap_dac_override,cap_fowner,cap_setgid,cap_setuid,cap_setpcap,cap_sys_admin=ep
```

**分析**: 直接执行脚本时权限降级成功，但通过容器管理器时失效

## 技术细节

### Dockerfile配置
```dockerfile
# 复制安全的系统初始化脚本
COPY docker/secure_system_init.sh /opt/system_init.sh

# 设置执行权限
RUN chmod +x /opt/system_init.sh
```

### 容器启动配置
```javascript
HostConfig: {
  Memory: 512 * 1024 * 1024,
  CpuShares: 512,
  NetworkMode: 'bridge',
  ReadonlyRootfs: false,
  SecurityOpt: ['no-new-privileges:true'],
  CapDrop: ['ALL'],
  CapAdd: ['CHOWN', 'DAC_OVERRIDE', 'FOWNER', 'SETGID', 'SETUID', 'SYS_ADMIN', 'SETPCAP'],
  // ...
}
```

### 硬件伪装脚本核心逻辑
```bash
# 第一阶段：高权限伪装操作
mount -t tmpfs -o size=32M,nr_inodes=200k,nosuid,nodev,mode=755 tmpfs /sys/devices/system/cpu
mount --bind /run/fakeproc/meminfo /proc/meminfo
mount --bind /run/fakeproc/cpuinfo /proc/cpuinfo

# 第二阶段：永久权限降级
exec capsh --drop=cap_sys_admin --drop=cap_setpcap -- -c '
    echo "[SUCCESS] 权限已永久移除"
    capsh --print | grep "Current:"
    exec /bin/bash
'
```

## 验证测试结果

### 硬件伪装效果测试
```bash
# 预期结果（脚本正常执行时）
$ nproc
24
$ lscpu | grep "CPU(s):"
CPU(s):              24
$ grep MemTotal /proc/meminfo
MemTotal:       67108864 kB

# 实际结果（脚本缺失时）
$ nproc
4  # 显示真实硬件
$ lscpu | grep "CPU(s):"
CPU(s):              4
$ grep MemTotal /proc/meminfo
MemTotal:       16384000 kB  # 显示真实内存
```

### 权限状态测试
```bash
# 容器创建后的权限状态
$ capsh --print | grep "Current:"
Current: cap_chown,cap_dac_override,cap_fowner,cap_setgid,cap_setuid,cap_setpcap,cap_sys_admin=ep

# 预期的权限降级后状态
Current: =
```

### 容器逃逸测试结果
```bash
# 挂载测试
$ mount -t tmpfs tmpfs /tmp/test
mount: /tmp/test: mount point does not exist.  # 被阻止

# cgroup测试  
$ echo $$ > /sys/fs/cgroup/cgroup.procs
bash: /sys/fs/cgroup/cgroup.procs: Read-only file system  # 被阻止

# Docker socket测试
$ find / -name "docker.sock" 2>/dev/null
# 无结果，未找到socket
```

## 环境信息

### 宿主机环境
- **操作系统**: Ubuntu 22.04 LTS (Codespace)
- **Docker版本**: 24.0.7
- **内核版本**: 6.8.0-1027-azure
- **CPU**: 4核 (真实硬件)
- **内存**: 16GB (真实硬件)

### 容器配置
- **基础镜像**: ubuntu:22.04
- **运行用户**: root
- **网络模式**: bridge
- **存储**: tmpfs + bind mounts
- **安全选项**: no-new-privileges:true

### 构建环境
- **构建工具**: Docker buildx
- **构建上下文**: /workspaces/linuxdo-bash
- **Dockerfile路径**: docker/Dockerfile.ubuntu

## 已尝试的解决方案

### 方案1：直接测试权限降级脚本
```bash
docker run --cap-drop=ALL --cap-add=SYS_ADMIN --cap-add=SETPCAP \
  --security-opt=no-new-privileges:true -it linux-ubuntu:latest \
  bash -c 'ENABLE_HARDWARE_FAKE=true /opt/system_init.sh'
```
**结果**: 权限降级成功，但脚本文件不存在

### 方案2：检查镜像构建
```bash
docker build -f docker/Dockerfile.ubuntu -t linux-ubuntu:latest .
```
**结果**: 构建成功，但容器中脚本文件缺失

### 方案3：手动验证容器内容
```bash
docker exec container ls -la /opt/
```
**结果**: 目录为空，确认脚本文件未包含在镜像中

## 核心疑问

### 疑问1：镜像构建与部署不一致
为什么Dockerfile中明确复制了脚本文件，但最终容器中却不存在？是否存在镜像版本不一致或缓存问题？

### 疑问2：容器管理器调用时机
容器管理器在setupUser阶段调用硬件伪装脚本是否合适？是否应该在容器启动时就执行？

### 疑问3：权限降级的持久性
通过capsh降级的权限是否会在docker exec时被重置？如何确保权限降级对所有进入容器的会话都有效？

### 疑问4：硬件伪装与权限降级的执行顺序
当前设计是先伪装再降权，但如果在容器启动后才执行脚本，是否会导致时机问题？

## 期望的解决方案

### 理想状态
1. **镜像构建正确**: 脚本文件正确包含在Docker镜像中
2. **硬件伪装生效**: 显示24核64GB的伪装硬件信息
3. **权限成功降级**: 从高权限降级到零权限
4. **安全性保证**: 容器逃逸风险最小化
5. **用户体验**: 对用户完全透明

### 可接受的妥协
- 轻微的容器启动延迟
- 适度的配置复杂度
- 某些高级容器功能的限制

## 补充信息

### 相关文件路径
- **Dockerfile**: `docker/Dockerfile.ubuntu`
- **安全脚本**: `docker/secure_system_init.sh`
- **容器管理器**: `backend/services/containerManager.js`
- **构建日志**: 构建过程无错误输出

### 错误日志
```bash
# 容器管理器执行日志
执行命令失败: ENABLE_HARDWARE_FAKE=true /opt/system_init.sh
Error: bash: line 1: /opt/system_init.sh: No such file or directory
```

### 当前工作状态
- **硬件伪装**: 完全失效
- **权限降级**: 未执行
- **容器安全**: 依赖Docker基础隔离
- **用户体验**: 显示真实硬件信息
