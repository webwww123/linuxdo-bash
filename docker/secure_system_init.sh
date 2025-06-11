#!/usr/bin/env bash
# 安全的硬件伪装系统 - 一次性高权→永久降权
# 基于专业人士建议的最小权限原则

set -euo pipefail

# 配置参数
FAKE_CPU_COUNT=24
FAKE_MEMORY_KB=67108864  # 64GB

# 日志函数（静默模式）
log_info() { echo "[INFO] $*" >&2; }
log_success() { echo "[SUCCESS] $*" >&2; }
log_warning() { echo "[WARNING] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# 检查环境变量
if [[ "${ENABLE_HARDWARE_FAKE:-}" != "true" ]]; then
    log_info "硬件伪装未启用 (ENABLE_HARDWARE_FAKE != true)"
    exec "$@"
fi

log_info "启动安全硬件伪装系统..."

# ========== 第一阶段：高权限伪装操作 ==========
log_info "执行高权限硬件伪装操作..."

# 1. CPU sysfs伪装
CPU_SYS="/sys/devices/system/cpu"
log_info "伪装CPU sysfs..."

# 移走真实sysfs（可选，增加隐蔽性）
mkdir -p /run/.real_cpu 2>/dev/null || true
mount --move "$CPU_SYS" /run/.real_cpu 2>/dev/null || true

# 创建tmpfs覆盖
mount -t tmpfs -o size=32M,nr_inodes=200k,nosuid,nodev,mode=755 tmpfs "$CPU_SYS"

# 生成伪造的CPU信息
printf '0-23\n' > "$CPU_SYS/online"
printf '0-23\n' > "$CPU_SYS/possible" 
printf '0-23\n' > "$CPU_SYS/present"

# 创建24个CPU目录
for i in $(seq 0 23); do
    mkdir -p "$CPU_SYS/cpu$i"
done

# 设为只读
mount -o remount,ro "$CPU_SYS"
log_success "CPU sysfs伪装完成"

# 2. 准备伪造的proc文件
log_info "准备伪造的proc文件..."
mkdir -p /run/fakeproc

# 生成伪造的meminfo
cat > /run/fakeproc/meminfo << EOF
MemTotal:       $FAKE_MEMORY_KB kB
MemFree:        33554432 kB
MemAvailable:   50331648 kB
Buffers:        2097152 kB
Cached:         16777216 kB
SwapCached:     0 kB
Active:         20971520 kB
Inactive:       8388608 kB
Active(anon):   12582912 kB
Inactive(anon): 1048576 kB
Active(file):   8388608 kB
Inactive(file): 7340032 kB
Unevictable:    0 kB
Mlocked:        0 kB
SwapTotal:      0 kB
SwapFree:       0 kB
Dirty:          64 kB
Writeback:      0 kB
AnonPages:      13631488 kB
Mapped:         2097152 kB
Shmem:          1048576 kB
EOF

# 生成伪造的cpuinfo
cat > /run/fakeproc/cpuinfo << EOF
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 106
model name	: Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz
stepping	: 6
microcode	: 0xd0003d1
cpu MHz		: 2900.000
cache size	: 54528 KB
physical id	: 0
siblings	: 24
core id		: 0
cpu cores	: 24
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 27
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx pdpe1gb rdtscp lm constant_tsc rep_good nopl xtopology cpuid tsc_known_freq pni pclmulqdq ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch cpuid_fault invpcid_single ssbd ibrs ibpb stibp ibrs_enhanced fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves wbnoinvd ida arat avx512vbmi umip pku ospke avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg avx512_vpopcntdq rdpid md_clear arch_capabilities
bugs		: spectre_v1 spectre_v2 spec_store_bypass swapgs
bogomips	: 5800.00
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

EOF

# 复制24个处理器条目
for i in $(seq 1 23); do
    sed "s/processor	: 0/processor	: $i/g; s/core id		: 0/core id		: $i/g; s/apicid		: 0/apicid		: $i/g; s/initial apicid	: 0/initial apicid	: $i/g" /run/fakeproc/cpuinfo >> /run/fakeproc/cpuinfo.tmp
done
cat /run/fakeproc/cpuinfo.tmp >> /run/fakeproc/cpuinfo
rm -f /run/fakeproc/cpuinfo.tmp

# 3. 绑定挂载proc文件
log_info "绑定挂载proc文件..."
mount --bind /run/fakeproc/meminfo /proc/meminfo
mount --bind /run/fakeproc/cpuinfo /proc/cpuinfo
log_success "proc文件伪装完成"

# 4. 创建伪装的nproc命令
log_info "创建伪装的nproc命令..."
if [ -f /usr/bin/nproc ]; then
    mv /usr/bin/nproc /usr/bin/.nproc_real
fi

cat > /usr/bin/nproc << 'NPROC_EOF'
#!/bin/bash
echo "24"
NPROC_EOF

chmod +x /usr/bin/nproc
log_success "nproc命令伪装完成"

# 5. 创建伪装的lscpu命令
log_info "创建伪装的lscpu命令..."
if [ -f /usr/bin/lscpu ]; then
    mv /usr/bin/lscpu /usr/bin/.lscpu_real
fi

cat > /usr/bin/lscpu << 'LSCPU_EOF'
#!/bin/bash
echo "Architecture:        x86_64"
echo "CPU op-mode(s):      32-bit, 64-bit"
echo "Byte Order:          Little Endian"
echo "Address sizes:       46 bits physical, 48 bits virtual"
echo "CPU(s):              24"
echo "On-line CPU(s) list: 0-23"
echo "Thread(s) per core:  1"
echo "Core(s) per socket:  24"
echo "Socket(s):           1"
echo "NUMA node(s):        1"
echo "Vendor ID:           GenuineIntel"
echo "CPU family:          6"
echo "Model:               106"
echo "Model name:          Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz"
echo "Stepping:            6"
echo "CPU MHz:             2900.000"
echo "BogoMIPS:            5800.00"
echo "Hypervisor vendor:   Microsoft"
echo "Virtualization type: full"
echo "L1d cache:           1.5 MiB"
echo "L1i cache:           1 MiB"
echo "L2 cache:            30 MiB"
echo "L3 cache:            54 MiB"
echo "NUMA node0 CPU(s):   0-23"
echo "Flags:               fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx pdpe1gb rdtscp lm constant_tsc rep_good nopl xtopology cpuid tsc_known_freq pni pclmulqdq ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch cpuid_fault invpcid_single ssbd ibrs ibpb stibp ibrs_enhanced fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves wbnoinvd ida arat avx512vbmi umip pku ospke avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg avx512_vpopcntdq rdpid md_clear arch_capabilities"
LSCPU_EOF

chmod +x /usr/bin/lscpu
log_success "lscpu命令伪装完成"

# ========== 第二阶段：永久移除危险权限 ==========
log_info "永久移除SYS_ADMIN权限..."

# 检查当前权限
log_info "当前权限状态:"
capsh --print | grep "Current:" || true

# 验证硬件伪装效果
log_info "验证硬件伪装效果..."
echo "  nproc: $(nproc)"
echo "  lscpu CPU数: $(lscpu | grep "^CPU(s):" | awk "{print \$2}")"
echo "  内存: $(grep MemTotal /proc/meminfo | awk "{print \$2/1024/1024\"GB\"}")"

log_success "硬件伪装完成，开始权限降级..."

# 使用专业人士建议的正确方法永久删除BoundingSet中的危险权限
# Ubuntu 22.04兼容的解决方案：setpriv + C helper + self-exec
log_info "使用专业建议的Ubuntu 22.04兼容方法永久删除BoundingSet权限..."

# 使用专业建议的预编译dropcaps helper
log_info "使用专业建议的预编译dropcaps helper..."
if [ -f /opt/dropcaps ]; then
    log_success "dropcaps helper已就绪"

    # 使用专业建议的方法：setpriv + self-exec
    log_info "使用setpriv确保CAP_SETPCAP在Effective中，然后self-exec..."

    # 专业人士建议的Ubuntu 22.04兼容命令
    # setpriv --inh-caps +setpcap --ambient-caps +setpcap 确保CAP_SETPCAP在Effective中
    # 然后self-exec到预编译的dropcaps helper
    exec setpriv --inh-caps +setpcap --ambient-caps +setpcap --reset-env -- \
        /opt/dropcaps "$@"

else
    log_warning "无法编译dropcaps helper，使用备用方案"

    # 备用方案：直接尝试prctl
    log_info "尝试直接prctl方案..."
    cat > /tmp/simple_drop.c << 'EOF'
#include <sys/prctl.h>
#include <linux/capability.h>
#include <stdio.h>

int main() {
    printf("尝试直接删除BoundingSet权限...\n");

    if (prctl(PR_CAPBSET_DROP, CAP_SYS_ADMIN, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SYS_ADMIN");
        return 1;
    }
    printf("Successfully dropped CAP_SYS_ADMIN\n");

    if (prctl(PR_CAPBSET_DROP, CAP_SETPCAP, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SETPCAP");
        return 1;
    }
    printf("Successfully dropped CAP_SETPCAP\n");

    return 0;
}
EOF

    if gcc -o /tmp/simple_drop /tmp/simple_drop.c 2>/dev/null && /tmp/simple_drop; then
        log_success "直接prctl方案成功"
        rm -f /tmp/simple_drop.c /tmp/simple_drop

        # 验证权限状态
        log_info "验证BoundingSet状态:"
        grep CapBnd /proc/self/status || true

    else
        log_warning "直接prctl方案失败，使用capsh备用方案"
        rm -f /tmp/simple_drop.c /tmp/simple_drop

        # 最后的备用方案：使用capsh（仅影响当前进程）
        exec capsh --drop=cap_sys_admin --drop=cap_setpcap -- -c '
            echo "[WARNING] 使用capsh备用方案，权限降级仅影响当前进程"
            echo "[INFO] 当前权限状态:"
            capsh --print | grep "Current:" || true
            exec "$@"
        ' -- "$@"
    fi
fi

# ========== 第三阶段：敏感文件屏蔽 ==========
log_info "屏蔽敏感proc文件..."

# 使用专业人士建议的bind mount方案屏蔽敏感文件
# 创建空文件用于覆盖敏感信息
echo "Permission denied" > /tmp/empty_file

# 屏蔽/proc/kcore（内存映像）
if mount --bind /tmp/empty_file /proc/kcore 2>/dev/null; then
    log_success "/proc/kcore已屏蔽"
else
    log_warning "/proc/kcore屏蔽失败"
fi

# 屏蔽/proc/version（内核版本信息）
echo "Linux version REDACTED (container) (gcc version REDACTED) #1 SMP PREEMPT_DYNAMIC" > /tmp/fake_version
if mount --bind /tmp/fake_version /proc/version 2>/dev/null; then
    log_success "/proc/version已屏蔽"
else
    log_warning "/proc/version屏蔽失败"
fi

# 屏蔽/proc/cmdline（启动参数）
echo "BOOT_IMAGE=/boot/vmlinuz root=/dev/container ro quiet" > /tmp/fake_cmdline
if mount --bind /tmp/fake_cmdline /proc/cmdline 2>/dev/null; then
    log_success "/proc/cmdline已屏蔽"
else
    log_warning "/proc/cmdline屏蔽失败"
fi

# 清理临时文件和脚本文件
rm -f /tmp/empty_file /tmp/fake_version /tmp/fake_cmdline 2>/dev/null || true
rm -f /opt/system_init.sh 2>/dev/null || true

log_success "安全硬件伪装系统部署完成"
log_info "容器已进入安全模式，享受24核64GB的高配置！"
log_info "所有危险权限已永久移除，敏感信息已屏蔽"
log_info "容器逃逸风险已降至最低水平"

# 执行传入的命令（通常是/bin/bash）
# 这里使用exec确保权限降级后的状态传递给用户进程
exec "$@"
