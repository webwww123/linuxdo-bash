#!/bin/bash
# 完全隐蔽的硬件伪装系统
# 基于专业人士建议的零痕迹方案

set -euo pipefail

# 配置参数
FAKE_CPU_COUNT=24
FAKE_MEMORY_KB=67108864  # 64GB

# 日志函数（静默模式）
log_info() { echo "[INFO] $*" >&2; }
log_success() { echo "[SUCCESS] $*" >&2; }
log_warning() { echo "[WARNING] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# 检查权限
check_capabilities() {
    if ! capsh --print | grep -q "cap_sys_admin"; then
        log_error "需要 CAP_SYS_ADMIN 权限"
        return 1
    fi
    log_success "权限检查通过"
}

# 第一阶段：创建隐蔽的tmpfs伪装sysfs
create_stealth_sysfs() {
    log_info "创建隐蔽的CPU sysfs伪装..."

    local CPU_SYS="/sys/devices/system/cpu"

    # 1) 直接用 tmpfs 覆盖，给足 inode（不移动原目录）
    mount -t tmpfs \
          -o size=32M,nr_inodes=200k,mode=755,nosuid,nodev \
          tmpfs "$CPU_SYS"

    # 3) 写伪造文件
    printf '0-23\n' >"$CPU_SYS/online"
    printf '0-23\n' >"$CPU_SYS/possible"
    printf '0-23\n' >"$CPU_SYS/present"

    # 创建24个CPU目录
    for i in $(seq 0 23); do
        mkdir -p "$CPU_SYS/cpu$i"
    done

    # 4) 设只读并把 mount 标记为 private，防止宿主看到
    mount -o remount,ro "$CPU_SYS"
    mount --make-private "$CPU_SYS"

    log_success "CPU sysfs伪装完成"
}

# 第二阶段：创建隐蔽的proc文件伪装
create_stealth_proc() {
    log_info "创建隐蔽的proc文件伪装..."

    # 创建临时隐蔽目录，给足inode
    local SHADOW_DIR="/run/.proc_shadow"
    mkdir -p "$SHADOW_DIR"
    mount -t tmpfs -o size=4M,nr_inodes=10k tmpfs "$SHADOW_DIR"
    
    # 生成伪造的meminfo
    cat > "$SHADOW_DIR/meminfo" << EOF
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
    cat > "$SHADOW_DIR/cpuinfo" << EOF
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
        sed "s/processor	: 0/processor	: $i/g; s/core id		: 0/core id		: $i/g; s/apicid		: 0/apicid		: $i/g; s/initial apicid	: 0/initial apicid	: $i/g" "$SHADOW_DIR/cpuinfo" >> "$SHADOW_DIR/cpuinfo.tmp"
    done
    cat "$SHADOW_DIR/cpuinfo.tmp" >> "$SHADOW_DIR/cpuinfo"
    rm -f "$SHADOW_DIR/cpuinfo.tmp"
    
    # 绑定挂载
    mount --bind "$SHADOW_DIR/meminfo" /proc/meminfo
    mount --bind "$SHADOW_DIR/cpuinfo" /proc/cpuinfo
    
    # 移走源目录到不可见位置
    mkdir -p /run/.dead_shadow
    mount --move "$SHADOW_DIR" /run/.dead_shadow
    
    log_success "proc文件伪装完成"
}

# 第三阶段：创建零痕迹的nproc伪装（简化版本）
create_memfd_nproc_hook() {
    log_info "创建零痕迹的nproc伪装..."

    # 使用方案B：替换nproc可执行文件
    if [ -f /usr/bin/nproc ]; then
        mv /usr/bin/nproc /usr/bin/.nproc_real
    fi

    # 创建伪装的nproc命令
    cat > /usr/bin/nproc << 'NPROC_EOF'
#!/bin/bash
echo "24"
NPROC_EOF

    chmod +x /usr/bin/nproc

    log_success "零痕迹nproc伪装完成"
}

# 备用：完整的memfd方案（暂时注释）
create_memfd_nproc_hook_full() {
    log_info "创建零痕迹的nproc伪装..."

    # 编译memfd hook库
    local hook_source="/tmp/memfd_hook_$$.c"
    cat > "$hook_source" << 'HOOK_EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <sched.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

static int (*orig_sched_getaffinity)(pid_t, size_t, cpu_set_t *) = NULL;
static long (*orig_sysconf)(int) = NULL;

#define FAKE_CPU_COUNT 24

int sched_getaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask) {
    if (!orig_sched_getaffinity) {
        orig_sched_getaffinity = dlsym(RTLD_NEXT, "sched_getaffinity");
        if (!orig_sched_getaffinity) {
            errno = ENOSYS;
            return -1;
        }
    }

    int result = orig_sched_getaffinity(pid, cpusetsize, mask);

    if (result == 0 && mask) {
        CPU_ZERO(mask);
        for (int i = 0; i < FAKE_CPU_COUNT && i < CPU_SETSIZE * 8; i++) {
            CPU_SET(i, mask);
        }
    }

    return result;
}

long sysconf(int name) {
    if (!orig_sysconf) {
        orig_sysconf = dlsym(RTLD_NEXT, "sysconf");
        if (!orig_sysconf) {
            errno = ENOSYS;
            return -1;
        }
    }

    switch (name) {
        case _SC_NPROCESSORS_ONLN:
        case _SC_NPROCESSORS_CONF:
            return FAKE_CPU_COUNT;
        default:
            return orig_sysconf(name);
    }
}

__attribute__((constructor))
static void init_hook(void) {
    orig_sched_getaffinity = dlsym(RTLD_NEXT, "sched_getaffinity");
    orig_sysconf = dlsym(RTLD_NEXT, "sysconf");
}
HOOK_EOF

    # 编译hook库
    local hook_lib="/tmp/memfd_hook_$$.so"
    gcc -shared -fPIC -o "$hook_lib" "$hook_source" -ldl 2>/dev/null

    if [ ! -f "$hook_lib" ]; then
        log_error "编译memfd hook库失败"
        return 1
    fi

    # 创建memfd并加载库
    local memfd_script="/tmp/memfd_loader_$$.sh"
    cat > "$memfd_script" << 'MEMFD_EOF'
#!/bin/bash
# 创建匿名内存文件描述符
exec 200< <(cat /tmp/memfd_hook_$$.so)
export LD_PRELOAD="/proc/self/fd/200"

# 立即清理源文件
rm -f /tmp/memfd_hook_$$.so /tmp/memfd_hook_$$.c

# 验证hook效果
if [ "$(nproc)" = "24" ]; then
    echo "[SUCCESS] memfd nproc hook 生效"
else
    echo "[WARNING] memfd nproc hook 可能失效"
fi

# 进入第二层namespace隐藏LD_PRELOAD
exec unshare -m --propagation private bash -c '
    unset LD_PRELOAD
    exec "$@"
' -- "$@"
MEMFD_EOF

    chmod +x "$memfd_script"

    # 应用memfd hook
    bash "$memfd_script" true

    # 清理临时文件
    rm -f "$hook_source" "$hook_lib" "$memfd_script"

    log_success "零痕迹nproc伪装完成"
}

# 第四阶段：创建伪装的lscpu命令
create_stealth_lscpu() {
    log_info "创建伪装的lscpu命令..."

    # 备份原始命令到隐蔽位置
    if [ -f /usr/bin/lscpu ]; then
        mv /usr/bin/lscpu /usr/bin/.lscpu_real
    fi

    # 创建伪装命令
    cat > /usr/bin/lscpu << 'EOF'
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
EOF
    
    chmod +x /usr/bin/lscpu
    log_success "lscpu命令伪装完成"
}

# 第四阶段：彻底隐蔽施工现场
stealth_cleanup() {
    log_info "执行彻底隐蔽清理..."
    
    # 创建第二层mount namespace
    unshare -m --propagation private bash -c '
        # 创建新的根目录
        mkdir -p /tmp/new_root
        mount --bind / /tmp/new_root
        
        # 创建pivot目录
        mkdir -p /tmp/new_root/.pivot_root
        
        # 执行pivot_root
        pivot_root /tmp/new_root /tmp/new_root/.pivot_root
        
        # 延迟卸载旧根目录
        umount -l /.pivot_root 2>/dev/null || true
        
        # 清理所有痕迹文件
        rm -rf /opt/fakeproc 2>/dev/null || true
        rm -f /opt/libfakehw.c 2>/dev/null || true
        rm -f /opt/generate_fake_files.sh 2>/dev/null || true
        rm -f /opt/hardware_fake_entrypoint.sh 2>/dev/null || true
        rm -f /opt/drop_capabilities.sh 2>/dev/null || true
        rm -f /usr/local/lib/libfakehw.so 2>/dev/null || true
        rm -f /etc/ld.so.preload 2>/dev/null || true
        
        # 清理临时文件
        rm -f /tmp/libfakehw.* 2>/dev/null || true
        rm -f /tmp/hardware_fake_*.log 2>/dev/null || true
        
        # 覆盖/run目录隐藏shadow
        mount -t tmpfs -o size=1M tmpfs /run
        
        log_success "彻底隐蔽清理完成"
    ' &
    
    log_success "隐蔽清理程序已启动"
}

# 验证伪装效果
verify_stealth_fake() {
    log_info "验证隐蔽伪装效果..."
    
    local errors=0
    
    # 测试nproc
    local nproc_result=$(nproc 2>/dev/null || echo "0")
    if [ "$nproc_result" = "24" ]; then
        log_success "nproc: $nproc_result 核"
    else
        log_warning "nproc 显示: $nproc_result (期望: 24)"
        ((errors++))
    fi
    
    # 测试内存
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    if [ "$mem_total" = "$FAKE_MEMORY_KB" ]; then
        log_success "内存: $(($mem_total / 1024 / 1024))GB"
    else
        log_warning "内存显示: $(($mem_total / 1024 / 1024))GB (期望: 64GB)"
        ((errors++))
    fi
    
    # 测试CPU目录数量
    local cpu_count=$(ls /sys/devices/system/cpu/ | grep -c "^cpu[0-9]" 2>/dev/null || echo "0")
    if [ "$cpu_count" = "24" ]; then
        log_success "CPU目录: $cpu_count 个"
    else
        log_warning "CPU目录数量: $cpu_count (期望: 24)"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "所有硬件伪装验证通过"
    else
        log_warning "硬件伪装验证发现 $errors 个问题"
    fi
}

# 主函数
main() {
    log_info "启动完全隐蔽的硬件伪装系统..."
    
    # 检查环境变量
    if [[ "${ENABLE_HARDWARE_FAKE:-}" != "true" ]]; then
        log_info "硬件伪装未启用 (ENABLE_HARDWARE_FAKE != true)"
        return 0
    fi
    
    # 执行伪装流程
    if check_capabilities; then
        create_stealth_sysfs
        create_stealth_proc
        create_memfd_nproc_hook
        create_stealth_lscpu
        verify_stealth_fake
        
        # 延迟执行彻底清理
        sleep 5
        stealth_cleanup
        
        log_success "完全隐蔽的硬件伪装系统部署完成"
    else
        log_error "硬件伪装启动失败：权限不足"
        return 1
    fi
}

# 执行主函数
main "$@"
