# 隐蔽硬件伪装实现问题求助文档

## 问题背景

基于专业人士提供的零痕迹硬件伪装方案，在Docker容器中实现24核CPU、64GB内存的硬件信息伪装时遇到技术实现问题。

## 专业人士建议的技术方案

### 核心思路
1. **不使用LD_PRELOAD** - `nproc`从`/sys/devices/system/cpu/{online,possible}`读取，只需伪装sysfs
2. **tmpfs覆盖sysfs** - 用tmpfs替换`/sys/devices/system/cpu`目录
3. **bind mount伪装/proc** - 覆盖`/proc/meminfo`、`/proc/cpuinfo`
4. **mount --move隐藏源文件** - 将伪装源文件移到不可见位置
5. **pivot_root双命名空间** - 彻底隐藏挂载痕迹

## 当前实现代码

### 容器配置
```bash
docker run --privileged --cap-add=SYS_ADMIN -d --name test-stealth linux-ubuntu:latest
```

### 核心伪装脚本
```bash
# 第一阶段：创建隐蔽的tmpfs伪装sysfs
create_stealth_sysfs() {
    local CPU_SYS="/sys/devices/system/cpu"
    
    # 直接创建tmpfs覆盖
    mount -t tmpfs -o size=4M,mode=755,nosuid,nodev tmpfs "$CPU_SYS"
    
    # 只创建关键文件
    echo "0-23" > "$CPU_SYS/online"
    echo "0-23" > "$CPU_SYS/possible"
    echo "0-23" > "$CPU_SYS/present"
    
    # 创建几个关键的CPU目录
    for i in 0 1 23; do
        mkdir -p "$CPU_SYS/cpu$i"
    done
    
    # 设为只读
    mount -o remount,ro "$CPU_SYS"
}
```

## 遇到的具体错误

### 错误信息
```
[INFO] 启动完全隐蔽的硬件伪装系统...
[SUCCESS] 权限检查通过
[INFO] 创建隐蔽的CPU sysfs伪装...
/opt/stealth_hardware_fake.sh: line 46: echo: write error: No space left on device
```

### 错误位置
第46行：`mount -o remount,ro "$CPU_SYS"`

### 调试结果
1. **tmpfs挂载成功**：
   ```bash
   mount -t tmpfs -o size=4M,mode=755,nosuid,nodev tmpfs /sys/devices/system/cpu
   mkdir /sys/devices/system/cpu/cpu0
   echo "test" > /sys/devices/system/cpu/test.txt
   # 成功执行，df显示4MB空间可用
   ```

2. **单独操作正常**：
   ```bash
   echo "0-23" > /sys/devices/system/cpu/online  # 单独执行成功
   ```

3. **脚本中失败**：在脚本环境中执行相同操作时出现"No space left on device"错误

## 已尝试的解决方案

### 方案1：增加tmpfs大小
- 从64K增加到1M，再到4M
- 错误依然存在

### 方案2：简化文件创建
- 减少CPU目录数量（从24个减少到3个）
- 只创建必要的关键文件
- 错误依然存在

### 方案3：移除mount --move
- 去掉复杂的目录移动操作
- 直接覆盖挂载
- 错误依然存在

### 方案4：调试验证
- 单独执行每个命令都成功
- 在脚本中组合执行时失败

## 环境信息

### 容器环境
- **基础镜像**：Ubuntu 22.04
- **权限**：--privileged --cap-add=SYS_ADMIN
- **文件系统**：overlay2
- **内核版本**：Linux 6.5.0-1025-azure

### 挂载状态
```bash
# 执行前
/sys/devices/system/cpu 是 sysfs 挂载点

# 执行后期望
/sys/devices/system/cpu 是 tmpfs 挂载点，包含伪造的CPU信息
```

### 脚本执行环境
- **执行方式**：`docker exec container bash -c 'ENABLE_HARDWARE_FAKE=true /opt/script.sh'`
- **用户**：root
- **工作目录**：/root

## 具体技术疑问

### 问题1：空间计算异常
为什么4MB的tmpfs在只写入几个小文件时报告"No space left on device"？

### 问题2：脚本环境差异
为什么相同的命令在交互式shell中成功，在脚本中失败？

### 问题3：挂载时机
是否需要在挂载tmpfs之前先卸载原始的sysfs？

### 问题4：权限问题
`/sys/devices/system/cpu`的特殊权限是否影响tmpfs覆盖？

## 期望的技术指导

### 目标1：成功创建tmpfs伪装
- 在`/sys/devices/system/cpu`创建包含24核信息的tmpfs
- 确保`nproc`、`lscpu`等命令读取到24核

### 目标2：实现完全隐蔽
- 所有伪装源文件被隐藏或删除
- 用户无法通过常规方式发现伪装痕迹

### 目标3：自动化部署
- 容器启动时自动执行伪装
- 无需手动干预

## 补充信息

### 成功的参考实现
之前使用LD_PRELOAD + bind mount方案成功实现了功能，但留有痕迹文件：
- `/usr/local/lib/libfakehw.so`
- `/etc/ld.so.preload`
- `/opt/fakeproc/overlay/upper/*`

### 当前代码仓库
完整的实现代码位于：
- 主脚本：`docker/stealth_hardware_fake.sh`
- 容器管理：`backend/services/containerManager.js`
- Docker配置：`docker/Dockerfile.ubuntu`

### 测试方法
```bash
# 验证CPU伪装
nproc                    # 期望：24
lscpu | grep "CPU(s):"   # 期望：CPU(s): 24
ls /sys/devices/system/cpu/ | grep -c "^cpu[0-9]"  # 期望：24

# 验证隐蔽性
find /opt -type f 2>/dev/null | wc -l  # 期望：0
cat /proc/self/mountinfo | grep tmpfs | wc -l  # 期望：最小化
```

## 技术栈信息

- **容器运行时**：Docker 24.0.7
- **操作系统**：Ubuntu 22.04 LTS
- **Shell**：bash 5.1.16
- **挂载工具**：util-linux 2.37.2
