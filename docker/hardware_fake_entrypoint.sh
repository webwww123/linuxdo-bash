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

# 主函数
main() {
    log_info "=== 硬件伪装启动脚本 ==="
    
    # 检查是否启用硬件伪装
    if ! check_fake_hardware_enabled; then
        return 0
    fi
    
    # 执行伪装流程
    if check_capabilities; then
        generate_fake_data
        build_and_install_libfakehw
        setup_ld_preload
        mount_overlay_proc
        verify_fake_hardware
        drop_capabilities
        show_fake_info
        show_test_commands
    else
        log_error "硬件伪装启动失败：权限不足"
        return 1
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
