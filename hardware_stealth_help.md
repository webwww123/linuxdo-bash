# 硬件伪装隐蔽性问题求助文档

## 问题描述

在Docker容器中实现硬件信息伪装（显示24核CPU、64GB内存），功能已完全实现，但存在痕迹文件清理不彻底的问题。

## 当前实现状态

### 成功的功能
- ✅ CPU伪装：`nproc`、`lscpu`、`neofetch` 均显示24核
- ✅ 内存伪装：`free -h`、`neofetch` 均显示64GB
- ✅ 系统文件伪装：`/sys/devices/system/cpu/` 显示24个CPU目录
- ✅ 自动化：容器启动时自动执行伪装
- ✅ 用户体验：完全透明，用户看到高配置硬件

### 存在的问题
用户要求"一丝痕迹都不能有"，但当前实现在容器中仍可发现以下痕迹文件：

## 具体痕迹文件列表

### /opt 目录下的文件
```
/opt/fakeproc/overlay/upper/stat
/opt/fakeproc/overlay/upper/cpuinfo  
/opt/fakeproc/overlay/upper/loadavg
/opt/fakeproc/overlay/upper/version
/opt/fakeproc/overlay/upper/meminfo
/opt/drop_capabilities.sh
/opt/generate_fake_files.sh
/opt/hardware_fake_entrypoint.sh
/opt/libfakehw.c
```

### 其他位置的文件
```
/usr/local/lib/libfakehw.so
/etc/ld.so.preload
```

## 技术实现细节

### 伪装技术栈
1. **tmpfs挂载**：替换 `/sys/devices/system/cpu` 目录
2. **LD_PRELOAD钩子**：劫持 `sysconf(_SC_NPROCESSORS_ONLN)` 系统调用
3. **bind mount**：覆盖 `/proc/meminfo`、`/proc/cpuinfo` 等文件
4. **命令替换**：创建伪装版本的 `lscpu` 命令

### 文件依赖关系
- `libfakehw.so`：LD_PRELOAD库，用于 `nproc` 命令伪装
- `/etc/ld.so.preload`：LD_PRELOAD配置文件
- `/opt/fakeproc/overlay/upper/*`：bind mount的源文件
- 其他 `/opt/` 下文件：构建时使用的源文件

### 清理脚本逻辑
当前使用延迟清理脚本：
```bash
# 创建清理脚本
cat > /tmp/.sys_cleanup << 'EOF'
#!/bin/bash
sleep 10
rm -f /opt/libfakehw.c 2>/dev/null || true
rm -f /opt/generate_fake_files.sh 2>/dev/null || true  
rm -f /opt/drop_capabilities.sh 2>/dev/null || true
rm -f /opt/hardware_fake_entrypoint.sh 2>/dev/null || true
rm -f /usr/local/lib/libfakehw.so 2>/dev/null || true
rm -f /etc/ld.so.preload 2>/dev/null || true
# ... 其他清理操作
EOF

# 后台执行
nohup /tmp/.sys_cleanup >/dev/null 2>&1 &
```

## 遇到的具体问题

### 问题1：挂载文件无法删除
`/opt/fakeproc/overlay/upper/` 下的文件正在被bind mount使用，无法直接删除。

### 问题2：LD_PRELOAD依赖
删除 `libfakehw.so` 和 `/etc/ld.so.preload` 会导致 `nproc` 命令失效，显示真实的4核。

### 问题3：清理时机
容器启动时执行伪装，但清理脚本在伪装完成后立即执行，可能导致伪装失效。

### 问题4：文件锁定
某些文件可能被系统进程锁定，无法删除。

## 已尝试的解决方案

### 方案1：延迟清理
使用 `sleep` 延迟清理，但仍有文件残留。

### 方案2：强制卸载
尝试 `umount` 后删除，但挂载关系复杂。

### 方案3：替代实现
创建 `/usr/local/bin/nproc` 替代LD_PRELOAD，但PATH优先级问题。

### 方案4：隐蔽移动
将文件移动到隐蔽位置而非删除，但仍可被发现。

## 环境信息

### 容器配置
- 基础镜像：Ubuntu 22.04
- 权限：`CAP_SYS_ADMIN`（用于tmpfs和bind mount）
- 运行模式：非特权容器

### 文件系统
- 容器文件系统：overlay2
- 挂载点：tmpfs、bind mount
- 权限：root用户执行

### 测试命令
用户可能执行的检查命令：
```bash
find /opt -type f 2>/dev/null
ls -la /opt/
find /usr/local/lib -name "*fake*"
cat /etc/ld.so.preload
ps aux | grep -E "(cleanup|hardware|fake)"
```

## 期望结果

实现完全隐蔽的硬件伪装：
1. 保持所有伪装功能正常（24核、64GB内存显示）
2. 用户无法通过任何常规方式发现伪装痕迹
3. 所有相关文件、配置、进程完全隐蔽
4. 系统表现如同天然的高配置硬件

## 补充信息

### 容器启动流程
1. Docker容器启动
2. 执行 `/opt/hardware_fake_entrypoint.sh`
3. 应用硬件伪装
4. 启动清理程序
5. 用户获得容器访问权限

### 用户访问方式
用户通过WebSSH访问容器，具有root权限，可以执行任意命令检查系统。

### 性能要求
伪装过程需要在容器启动后30秒内完成，不能影响用户体验。
