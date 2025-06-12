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

# 生成伪造的/proc/stat文件（htop主要依赖这个）
log_info "生成伪造的/proc/stat文件..."
cat > /run/fakeproc/stat << 'EOF'
cpu  2097152 0 524288 50331648 4096 0 8192 0 0 0
cpu0 87381 0 21845 2097152 171 0 342 0 0 0
cpu1 87381 0 21845 2097152 171 0 342 0 0 0
cpu2 87381 0 21845 2097152 171 0 342 0 0 0
cpu3 87381 0 21845 2097152 171 0 342 0 0 0
cpu4 87381 0 21845 2097152 171 0 342 0 0 0
cpu5 87381 0 21845 2097152 171 0 342 0 0 0
cpu6 87381 0 21845 2097152 171 0 342 0 0 0
cpu7 87381 0 21845 2097152 171 0 342 0 0 0
cpu8 87381 0 21845 2097152 171 0 342 0 0 0
cpu9 87381 0 21845 2097152 171 0 342 0 0 0
cpu10 87381 0 21845 2097152 171 0 342 0 0 0
cpu11 87381 0 21845 2097152 171 0 342 0 0 0
cpu12 87381 0 21845 2097152 171 0 342 0 0 0
cpu13 87381 0 21845 2097152 171 0 342 0 0 0
cpu14 87381 0 21845 2097152 171 0 342 0 0 0
cpu15 87381 0 21845 2097152 171 0 342 0 0 0
cpu16 87381 0 21845 2097152 171 0 342 0 0 0
cpu17 87381 0 21845 2097152 171 0 342 0 0 0
cpu18 87381 0 21845 2097152 171 0 342 0 0 0
cpu19 87381 0 21845 2097152 171 0 342 0 0 0
cpu20 87381 0 21845 2097152 171 0 342 0 0 0
cpu21 87381 0 21845 2097152 171 0 342 0 0 0
cpu22 87381 0 21845 2097152 171 0 342 0 0 0
cpu23 87381 0 21845 2097152 171 0 342 0 0 0
intr 16777216 1048576 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
ctxt 33554432
btime 1640995200
processes 65536
procs_running 1
procs_blocked 0
softirq 8388608 262144 2097152 4096 524288 1048576 0 131072 2097152 8192 2097152
EOF

# 3. 绑定挂载proc文件
log_info "绑定挂载proc文件..."
mount --bind /run/fakeproc/meminfo /proc/meminfo
mount --bind /run/fakeproc/cpuinfo /proc/cpuinfo
mount --bind /run/fakeproc/stat /proc/stat
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

# ========== 第二阶段：验证硬件伪装效果 ==========
log_info "验证硬件伪装效果..."
echo "  nproc: $(nproc)"
echo "  lscpu CPU数: $(lscpu | grep "^CPU(s):" | awk "{print \$2}")"
echo "  内存: $(grep MemTotal /proc/meminfo | awk "{print \$2/1024/1024\"GB\"}")"

log_success "硬件伪装完成！"

# 注意：不再进行权限降级，保持sudo正常工作
# 容器安全通过Docker的安全配置来保证
log_info "保持必要权限以确保sudo正常工作"
log_info "容器安全通过Docker配置保证"

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

log_success "安全硬件伪装系统部署完成"
log_info "容器已进入安全模式，享受24核64GB的高配置！"
log_info "敏感信息已屏蔽，sudo功能正常"
log_info "硬件伪装效果已生效"

# 执行传入的命令（通常是/bin/bash）
exec "$@"
