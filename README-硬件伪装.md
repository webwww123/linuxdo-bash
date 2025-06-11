# 硬件伪装功能说明

## 概述

本项目实现了完整的硬件信息伪装功能，让用户容器内显示为高配置服务器，同时保持真实资源限制不变。采用 **OverlayFS + LD_PRELOAD** 双层伪装技术，确保伪装效果彻底且安全。

## 伪装效果

### 目标配置
- **CPU**: 24核心 Intel Xeon Platinum 8375C @ 2.90GHz
- **内存**: 64GB
- **存储**: 1TB

### 真实配置
- **CPU**: 4核心 (Codespace)
- **内存**: 15GB (实际容器限制512MB)
- **存储**: 118GB临时存储

## 技术方案

### 双层伪装架构

| 伪装层 | 技术方案 | 覆盖范围 | 安全性 |
|--------|----------|----------|--------|
| **文件系统层** | OverlayFS覆盖/proc | lscpu, htop, /proc/* | 需要临时CAP_SYS_ADMIN |
| **系统调用层** | LD_PRELOAD钩子 | free, df, sysinfo() | 用户态劫持，安全 |

### 核心组件

1. **libfakehw.so** - LD_PRELOAD钩子库
   - 劫持 `sysinfo()` - 内存信息
   - 劫持 `statvfs()` - 存储信息
   - 劫持 `sysconf()` - CPU核心数
   - 劫持 `get_nprocs()` - 处理器数量

2. **伪造数据文件**
   - `/proc/cpuinfo` - 24核CPU信息
   - `/proc/meminfo` - 64GB内存信息
   - `/proc/stat` - CPU统计信息
   - `/proc/version` - 内核版本
   - `/proc/loadavg` - 负载平均值

3. **启动脚本**
   - `hardware_fake_entrypoint.sh` - 主启动脚本
   - `generate_fake_files.sh` - 数据生成脚本
   - `drop_capabilities.sh` - 权限回收脚本

## 使用方法

### 自动启用 (推荐)

硬件伪装已集成到容器创建流程中，用户容器会自动启用伪装：

```bash
# 启动应用 (硬件伪装自动生效)
./start-all.sh

# 创建用户容器时会自动应用伪装
```

### 手动测试

```bash
# 生成伪造数据
sudo ./docker/generate_fake_files.sh

# 编译LD_PRELOAD库
sudo gcc -shared -fPIC -o /usr/local/lib/libfakehw.so docker/libfakehw.c -ldl

# 设置LD_PRELOAD
echo "/usr/local/lib/libfakehw.so" | sudo tee /etc/ld.so.preload

# 运行测试脚本
./test-hardware-fake.sh
```

## 验证效果

### 测试命令

在用户容器内运行以下命令验证伪装效果：

```bash
# CPU信息
lscpu                                    # 应显示24核
nproc                                    # 应显示24
cat /proc/cpuinfo | grep processor | wc -l  # 应显示24

# 内存信息
free -h                                  # 应显示~64GB
cat /proc/meminfo | grep MemTotal       # 应显示~64GB

# 存储信息
df -h                                    # 应显示~1TB

# 系统监控
htop                                     # 应显示24个CPU核心
neofetch                                 # 应显示完整的高配置信息
```

### 预期输出示例

```bash
$ lscpu
Architecture:        x86_64
CPU(s):              24
Model name:          Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz

$ free -h
              total        used        free
Mem:           64Gi       2.1Gi        61Gi

$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
overlay         1.0T  100G  900G  10% /
```

## 安全机制

### 权限控制

1. **临时权限** - 仅在启动时需要 `CAP_SYS_ADMIN`
2. **自动回收** - 伪装完成后立即回收危险权限
3. **最小权限** - 只保留必要的基础权限

### 权限回收流程

```bash
# 启动时权限
CAP_SYS_ADMIN, CAP_SETPCAP, CAP_SETFCAP, CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FOWNER, CAP_SETGID, CAP_SETUID

# 伪装完成后权限
CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FOWNER, CAP_SETGID, CAP_SETUID
```

### 安全保护

- LD_PRELOAD配置文件权限保护 (`root:root 644`)
- 伪造数据文件只读权限 (`444`)
- 用户无法修改伪装配置
- 容器隔离保护宿主机安全

## 技术细节

### OverlayFS 挂载

```bash
mount -t overlay overlay \
  -o lowerdir=/proc,upperdir=/opt/fakeproc/overlay/upper,workdir=/opt/fakeproc/overlay/work \
  /proc
```

- **lowerdir**: 原始/proc文件系统
- **upperdir**: 伪造文件目录
- **workdir**: OverlayFS工作目录
- **挂载点**: /proc (原位覆盖)

### LD_PRELOAD 劫持

```c
// 内存信息劫持
int sysinfo(struct sysinfo *info) {
    static sysinfo_t real_sysinfo = dlsym(RTLD_NEXT, "sysinfo");
    int result = real_sysinfo(info);
    info->totalram = 64ULL * 1024 * 1024 * 1024;  // 64GB
    return result;
}
```

### 容器配置

```javascript
// 容器创建时添加必要权限
HostConfig: {
  CapAdd: ['CHOWN', 'DAC_OVERRIDE', 'FOWNER', 'SETGID', 'SETUID', 'SYS_ADMIN'],
  Env: ['ENABLE_HARDWARE_FAKE=true']
}
```

## 故障排除

### 常见问题

1. **OverlayFS挂载失败**
   ```bash
   # 检查权限
   capsh --print | grep cap_sys_admin
   
   # 检查内核支持
   grep overlay /proc/filesystems
   ```

2. **LD_PRELOAD不生效**
   ```bash
   # 检查库文件
   ls -la /usr/local/lib/libfakehw.so
   
   # 检查配置
   cat /etc/ld.so.preload
   
   # 检查环境变量
   echo $FAKEHW_LOADED
   ```

3. **权限回收失败**
   ```bash
   # 检查当前权限
   capsh --print
   
   # 手动回收权限
   ./docker/drop_capabilities.sh
   ```

### 调试工具

```bash
# 运行完整测试
./test-hardware-fake.sh

# 检查挂载状态
mount | grep overlay

# 检查进程权限
cat /proc/self/status | grep Cap

# 验证伪装文件
ls -la /opt/fakeproc/overlay/upper/
```

## 性能影响

- **OverlayFS**: 极轻微的I/O开销 (<1%)
- **LD_PRELOAD**: 系统调用劫持开销 (<0.1%)
- **内存占用**: 伪造数据文件 (~50KB)
- **启动时间**: 增加 ~2-3秒

## 注意事项

### ⚠️ 重要提醒

1. **仅用于演示** - 真实资源限制仍然有效
2. **教学目的** - 帮助用户学习高配置环境
3. **临时环境** - 适合Codespace等临时容器
4. **数据丢失** - 重启后伪装配置会丢失

### 💡 最佳实践

1. **及时说明** - 向用户说明这是演示环境
2. **监控资源** - 真实资源使用仍需监控
3. **定期清理** - 清理不需要的伪装数据
4. **安全审计** - 定期检查权限配置

## 扩展功能

### 自定义配置

可以通过修改配置参数自定义伪装规格：

```bash
# 在 docker/libfakehw.c 中修改
#define FAKE_CPU_CORES 24      # CPU核心数
#define FAKE_MEMORY_GB 64ULL   # 内存大小(GB)
#define FAKE_STORAGE_TB 1ULL   # 存储大小(TB)
```

### 动态调整

未来可以实现动态调整伪装参数：

- 通过环境变量配置
- 支持多种预设配置
- 用户自定义硬件规格

## 技术支持

如遇到问题，请：

1. 运行测试脚本：`./test-hardware-fake.sh`
2. 检查日志：容器启动日志
3. 验证权限：`capsh --print`
4. 提交Issue：附上详细的错误信息和环境配置
