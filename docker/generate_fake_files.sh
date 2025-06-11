#!/bin/bash

# 硬件伪装数据生成脚本
# 生成伪造的 /proc 文件用于 OverlayFS 覆盖

set -euo pipefail

# 配置参数
FAKE_CPU_CORES=24
FAKE_MEMORY_GB=64
FAKE_STORAGE_TB=1
FAKE_ROOT="/opt/fakeproc"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建目录结构
setup_directories() {
    log_info "创建伪装文件目录结构..."
    
    mkdir -p "$FAKE_ROOT/overlay/upper"
    mkdir -p "$FAKE_ROOT/overlay/work"
    
    log_success "目录结构创建完成"
}

# 生成伪造的 /proc/cpuinfo
generate_cpuinfo() {
    log_info "生成伪造的 /proc/cpuinfo (${FAKE_CPU_CORES}核)..."
    
    local cpuinfo_file="$FAKE_ROOT/overlay/upper/cpuinfo"
    
    # 清空文件
    > "$cpuinfo_file"
    
    # 生成每个CPU核心的信息
    for ((i=0; i<FAKE_CPU_CORES; i++)); do
        cat >> "$cpuinfo_file" << EOF
processor	: $i
vendor_id	: GenuineIntel
cpu family	: 6
model		: 85
model name	: Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz
stepping	: 7
microcode	: 0xd0003d1
cpu MHz		: 2900.000
cache size	: 36608 KB
physical id	: $((i / 12))
siblings	: 24
core id		: $((i % 12))
cpu cores	: 12
apicid		: $i
initial apicid	: $i
fpu		: yes
fpu_exception	: yes
cpuid level	: 27
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon rep_good nopl xtopology cpuid tsc_known_freq pni pclmulqdq vmx ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch cpuid_fault epb cat_l3 cdp_l3 invpcid_single intel_ppin ssbd mba ibrs ibpb stibp ibrs_enhanced tpr_shadow vnmi flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid cqm mpx rdt_a avx512f avx512dq rdseed adx smap clflushopt clwb intel_pt avx512cd avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local split_lock_detect wbnoinvd dtherm ida arat pln pts avx512_vnni md_clear arch_capabilities
vmx flags	: vnmi preemption_timer posted_intr invvpid ept_x_only ept_ad ept_1gb flexpriority apicv tsc_offset vtpr mtf vapic ept vpid unrestricted_guest vapic_reg vid ple shadow_vmcs ept_mode_based_exec tsc_scaling
bugs		: spectre_v1 spectre_v2 spec_store_bypass swapgs
bogomips	: 5800.00
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

EOF
    done
    
    log_success "cpuinfo 生成完成 (${FAKE_CPU_CORES}核)"
}

# 生成伪造的 /proc/meminfo
generate_meminfo() {
    log_info "生成伪造的 /proc/meminfo (${FAKE_MEMORY_GB}GB)..."
    
    local meminfo_file="$FAKE_ROOT/overlay/upper/meminfo"
    local total_kb=$((FAKE_MEMORY_GB * 1024 * 1024))
    local free_kb=$((total_kb / 2))
    local available_kb=$((total_kb * 3 / 4))
    local buffers_kb=$((total_kb / 20))
    local cached_kb=$((total_kb / 4))
    local swap_total_kb=$((total_kb / 2))
    local swap_free_kb=$swap_total_kb
    
    cat > "$meminfo_file" << EOF
MemTotal:        $total_kb kB
MemFree:         $free_kb kB
MemAvailable:    $available_kb kB
Buffers:         $buffers_kb kB
Cached:          $cached_kb kB
SwapCached:      0 kB
Active:          $((cached_kb / 2)) kB
Inactive:        $((cached_kb / 4)) kB
Active(anon):    $((total_kb / 10)) kB
Inactive(anon):  $((total_kb / 20)) kB
Active(file):    $((cached_kb / 3)) kB
Inactive(file):  $((cached_kb / 6)) kB
Unevictable:     0 kB
Mlocked:         0 kB
SwapTotal:       $swap_total_kb kB
SwapFree:        $swap_free_kb kB
Dirty:           64 kB
Writeback:       0 kB
AnonPages:       $((total_kb / 8)) kB
Mapped:          $((total_kb / 16)) kB
Shmem:           $((total_kb / 32)) kB
KReclaimable:    $((buffers_kb / 2)) kB
Slab:            $((buffers_kb * 3 / 4)) kB
SReclaimable:    $((buffers_kb / 2)) kB
SUnreclaim:      $((buffers_kb / 4)) kB
KernelStack:     16384 kB
PageTables:      32768 kB
NFS_Unstable:    0 kB
Bounce:          0 kB
WritebackTmp:    0 kB
CommitLimit:     $((total_kb + swap_total_kb / 2)) kB
Committed_AS:    $((total_kb / 4)) kB
VmallocTotal:    34359738367 kB
VmallocUsed:     65536 kB
VmallocChunk:    0 kB
Percpu:          8192 kB
HardwareCorrupted: 0 kB
AnonHugePages:   0 kB
ShmemHugePages:  0 kB
ShmemPmdMapped:  0 kB
FileHugePages:   0 kB
FilePmdMapped:   0 kB
HugePages_Total: 0
HugePages_Free:  0
HugePages_Rsvd:  0
HugePages_Surp:  0
Hugepagesize:    2048 kB
Hugetlb:         0 kB
DirectMap4k:     1048576 kB
DirectMap2M:     $((total_kb - 1048576)) kB
DirectMap1G:     0 kB
EOF
    
    log_success "meminfo 生成完成 (${FAKE_MEMORY_GB}GB)"
}

# 生成伪造的 /proc/stat
generate_stat() {
    log_info "生成伪造的 /proc/stat..."
    
    local stat_file="$FAKE_ROOT/overlay/upper/stat"
    
    # 生成CPU统计信息
    echo "cpu  123456 0 234567 8901234 5678 0 1234 0 0 0" > "$stat_file"
    
    # 为每个CPU核心生成统计
    for ((i=0; i<FAKE_CPU_CORES; i++)); do
        echo "cpu$i $((123456 / FAKE_CPU_CORES)) 0 $((234567 / FAKE_CPU_CORES)) $((8901234 / FAKE_CPU_CORES)) $((5678 / FAKE_CPU_CORES)) 0 $((1234 / FAKE_CPU_CORES)) 0 0 0" >> "$stat_file"
    done
    
    # 添加其他统计信息
    cat >> "$stat_file" << EOF
intr 123456789 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
ctxt 987654321
btime 1640995200
processes 123456
procs_running 2
procs_blocked 0
softirq 456789123 0 123456 0 234567 345678 0 456789 567890 0 678901
EOF
    
    log_success "stat 生成完成"
}

# 生成伪造的 /proc/version
generate_version() {
    log_info "生成伪造的 /proc/version..."
    
    local version_file="$FAKE_ROOT/overlay/upper/version"
    
    cat > "$version_file" << EOF
Linux version 5.15.0-91-generic (buildd@lcy02-amd64-047) (gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0, GNU ld (GNU Binutils for Ubuntu) 2.38) #101-Ubuntu SMP Tue Nov 14 13:30:08 UTC 2023
EOF
    
    log_success "version 生成完成"
}

# 生成伪造的 /proc/loadavg
generate_loadavg() {
    log_info "生成伪造的 /proc/loadavg..."
    
    local loadavg_file="$FAKE_ROOT/overlay/upper/loadavg"
    
    # 生成合理的负载平均值
    echo "2.45 3.67 4.12 3/512 98765" > "$loadavg_file"
    
    log_success "loadavg 生成完成"
}

# 设置文件权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 设置目录权限
    chmod 755 "$FAKE_ROOT"
    chmod 755 "$FAKE_ROOT/overlay"
    chmod 755 "$FAKE_ROOT/overlay/upper"
    chmod 755 "$FAKE_ROOT/overlay/work"
    
    # 设置文件权限 (模拟 /proc 文件权限)
    find "$FAKE_ROOT/overlay/upper" -type f -exec chmod 444 {} \;
    
    log_success "权限设置完成"
}

# 验证生成的文件
verify_files() {
    log_info "验证生成的伪造文件..."
    
    local files=("cpuinfo" "meminfo" "stat" "version" "loadavg")
    local all_ok=true
    
    for file in "${files[@]}"; do
        local filepath="$FAKE_ROOT/overlay/upper/$file"
        if [[ -f "$filepath" && -r "$filepath" ]]; then
            local size=$(stat -c%s "$filepath")
            log_success "$file: OK (${size} bytes)"
        else
            log_error "$file: 文件不存在或不可读"
            all_ok=false
        fi
    done
    
    if $all_ok; then
        log_success "所有伪造文件验证通过"
    else
        log_error "部分文件验证失败"
        exit 1
    fi
}

# 显示摘要信息
show_summary() {
    log_info "硬件伪装配置摘要:"
    echo "  CPU核心数: $FAKE_CPU_CORES"
    echo "  内存大小: ${FAKE_MEMORY_GB}GB"
    echo "  存储大小: ${FAKE_STORAGE_TB}TB"
    echo "  伪造文件目录: $FAKE_ROOT/overlay/upper/"
    echo ""
    log_success "伪造数据生成完成！"
}

# 主函数
main() {
    log_info "开始生成硬件伪装数据..."
    
    setup_directories
    generate_cpuinfo
    generate_meminfo
    generate_stat
    generate_version
    generate_loadavg
    set_permissions
    verify_files
    show_summary
}

# 执行主函数
main "$@"
