# 容器逃逸保护需求求助文档

## 问题背景

在Docker容器中实现硬件伪装功能时，需要使用`CAP_SYS_ADMIN`权限来执行tmpfs挂载和bind mount操作。但这个权限同时带来了容器逃逸的安全风险。需要在保持硬件伪装效果的同时，最大化容器安全性。

## 当前实现状态

### 硬件伪装功能
- ✅ **CPU伪装**：24核Intel Xeon Platinum 8375C
- ✅ **内存伪装**：64GB内存
- ✅ **用户体验**：完全透明，所有检测工具显示高配置
- ✅ **隐蔽性**：基本实现零痕迹（已重命名脚本为system_init.sh）

### 技术实现
```bash
# 核心权限需求
docker run --privileged --cap-add=SYS_ADMIN

# 关键操作
mount -t tmpfs -o size=32M,nr_inodes=200k tmpfs /sys/devices/system/cpu
mount --bind /fake/meminfo /proc/meminfo
mount --bind /fake/cpuinfo /proc/cpuinfo
```

## 发现的安全风险

### 容器逃逸风险评估
通过安全测试发现以下风险：

#### 1. 高危权限
- **CAP_SYS_ADMIN权限**：容器具有系统管理员级别权限
- **特权容器模式**：--privileged标志提供了几乎完整的宿主机访问权限

#### 2. 信息泄露
- **宿主机进程访问**：可以读取`/proc/1/`等宿主机进程信息
- **内核信息暴露**：可以访问`/proc/version`、`/proc/cmdline`等敏感信息

#### 3. 潜在攻击向量
- **挂载攻击**：尝试挂载宿主机文件系统（当前被阻止）
- **cgroup逃逸**：尝试修改cgroup限制（当前被阻止）
- **namespace突破**：虽然namespace隔离正常，但高权限增加风险

### 当前防护状况
**有效防护**：
- ✅ 宿主机文件系统挂载被阻止
- ✅ cgroup修改被限制
- ✅ 没有Docker socket访问
- ✅ namespace隔离正常工作

**安全缺陷**：
- ❌ 过度的CAP_SYS_ADMIN权限
- ❌ 可访问宿主机进程信息
- ❌ 特权模式带来的潜在风险

## 技术需求

### 核心目标
在保持硬件伪装功能完全正常的前提下，最大化容器安全性。

### 具体需求

#### 1. 权限最小化
**当前状态**：
```bash
--privileged --cap-add=SYS_ADMIN
```

**期望状态**：
```bash
# 只保留硬件伪装必需的最小权限
--cap-add=SYS_ADMIN --cap-drop=ALL_EXCEPT_REQUIRED
```

**疑问**：
- 硬件伪装的tmpfs和bind mount操作具体需要哪些最小权限？
- 是否可以用更细粒度的capability替代SYS_ADMIN？
- 能否在伪装完成后动态撤销权限？

#### 2. 文件系统隔离加强
**当前问题**：
- 可以访问`/proc/1/`宿主机进程信息
- 可以读取宿主机内核信息

**期望解决方案**：
- 限制对宿主机敏感proc文件的访问
- 保持硬件伪装所需的proc文件访问（/proc/cpuinfo、/proc/meminfo等）

#### 3. 运行时权限控制
**技术方案需求**：
- 容器启动时具有SYS_ADMIN权限执行硬件伪装
- 伪装完成后自动撤销危险权限
- 用户访问时容器处于受限权限状态

#### 4. 网络和设备隔离
**当前状态**：基本隔离正常
**加强需求**：
- 确保网络命名空间完全隔离
- 限制设备文件访问
- 防止通过网络进行逃逸

## 环境约束

### 硬件伪装不可妥协的需求
1. **tmpfs挂载**：必须能够挂载tmpfs到`/sys/devices/system/cpu`
2. **bind mount**：必须能够覆盖`/proc/meminfo`和`/proc/cpuinfo`
3. **文件创建**：必须能够在tmpfs中创建CPU目录和文件
4. **只读设置**：必须能够将挂载点设为只读

### 用户体验要求
- 硬件伪装对用户完全透明
- 所有常用命令（nproc、lscpu、free、neofetch）显示伪装信息
- 容器启动时间不能显著增加
- 不能影响容器内正常的软件安装和使用

### 部署环境
- **容器运行时**：Docker 24.0.7
- **宿主机OS**：Ubuntu 22.04 LTS
- **内核版本**：Linux 6.8.0-1027-azure
- **用户权限**：容器内root用户
- **网络模式**：bridge网络

## 技术疑问

### 问题1：权限细分可行性
是否可以将CAP_SYS_ADMIN细分为更具体的权限？例如：
- CAP_SYS_MOUNT（用于挂载操作）
- 其他特定的capability组合

### 问题2：动态权限撤销
是否可以在容器运行时动态撤销权限？实现方案：
- 容器启动 → 执行伪装（高权限）→ 撤销权限 → 用户访问（低权限）

### 问题3：安全容器技术
是否可以使用以下技术加强安全性：
- gVisor（用户空间内核）
- Kata Containers（轻量级虚拟机）
- Firecracker（微虚拟机）

### 问题4：SELinux/AppArmor集成
如何在启用SELinux或AppArmor的环境中：
- 保持硬件伪装功能
- 加强容器安全策略
- 防止权限滥用

## 期望的解决方案

### 理想状态
1. **最小权限原则**：只保留硬件伪装必需的权限
2. **时间限制权限**：高权限仅在伪装阶段使用
3. **完整功能保持**：硬件伪装效果不受影响
4. **安全加固**：防止容器逃逸和信息泄露
5. **易于部署**：不增加部署复杂度

### 可接受的妥协
- 轻微的容器启动时间增加
- 适度的配置复杂度提升
- 某些高级容器功能的限制（如果不影响基本使用）

## 补充信息

### 当前安全测试结果
```bash
# 权限检查
capsh --print | grep "Current:"
# Current: cap_chown,cap_dac_override,cap_fowner,cap_setgid,cap_setuid,cap_sys_admin=ep

# 逃逸尝试结果
mount /dev/sda1 /tmp/host_escape  # 失败 ✅
echo $$ > /sys/fs/cgroup/cgroup.procs  # 失败 ✅
ls /proc/1/  # 成功 ❌（安全风险）
```

### 硬件伪装验证
```bash
nproc                    # 24 ✅
lscpu | grep "CPU(s):"   # CPU(s): 24 ✅
free -h | grep Mem       # Mem: 64Gi ✅
neofetch | grep CPU      # Intel Xeon Platinum 8375C (24) ✅
```

### 隐蔽性状况
- 脚本文件已重命名为`system_init.sh`
- 无LD_PRELOAD痕迹文件
- 无可疑进程运行
- tmpfs挂载对普通用户不明显
