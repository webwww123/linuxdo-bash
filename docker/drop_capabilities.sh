#!/bin/bash

# 权限回收脚本
# 在硬件伪装完成后立即回收临时权限

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[CAP-DROP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[CAP-DROP]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[CAP-DROP]${NC} $1"
}

log_error() {
    echo -e "${RED}[CAP-DROP]${NC} $1"
}

# 显示当前权限
show_current_capabilities() {
    log_info "当前进程权限:"
    
    if command -v capsh &> /dev/null; then
        capsh --print | grep -E "(Current|Bounding)" || true
    else
        log_warning "capsh 不可用，无法显示详细权限信息"
    fi
    
    # 显示有效权限
    if [[ -r /proc/self/status ]]; then
        grep -E "Cap(Inh|Prm|Eff|Bnd|Amb):" /proc/self/status || true
    fi
}

# 检查是否需要回收权限
check_need_drop() {
    # 检查是否有 SYS_ADMIN 权限
    if capsh --print 2>/dev/null | grep -q "cap_sys_admin"; then
        return 0  # 需要回收
    else
        log_info "未检测到需要回收的权限"
        return 1  # 不需要回收
    fi
}

# 方法1: 使用 capsh 回收权限
drop_with_capsh() {
    log_info "使用 capsh 回收权限..."
    
    if ! command -v capsh &> /dev/null; then
        log_error "capsh 不可用"
        return 1
    fi
    
    # 回收危险权限，保留必要权限
    local keep_caps="cap_chown,cap_dac_override,cap_fowner,cap_setgid,cap_setuid"
    
    log_info "保留权限: $keep_caps"
    log_info "回收权限: cap_sys_admin, cap_setpcap, cap_setfcap"
    
    # 注意：这里不能直接 exec，因为会替换当前进程
    # 而是返回一个可以执行的命令
    echo "capsh --drop=cap_sys_admin,cap_setpcap,cap_setfcap --caps=\"$keep_caps+eip\" --"
}

# 方法2: 使用 prctl 系统调用 (通过C程序)
create_prctl_dropper() {
    log_info "创建 prctl 权限回收程序..."
    
    local dropper_c="/tmp/cap_dropper.c"
    local dropper_bin="/tmp/cap_dropper"
    
    # 创建C程序
    cat > "$dropper_c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/prctl.h>
#include <linux/capability.h>
#include <errno.h>
#include <string.h>

int main(int argc, char *argv[]) {
    // 回收 CAP_SYS_ADMIN
    if (prctl(PR_CAPBSET_DROP, CAP_SYS_ADMIN, 0, 0, 0) == -1) {
        fprintf(stderr, "Failed to drop CAP_SYS_ADMIN: %s\n", strerror(errno));
    } else {
        printf("Dropped CAP_SYS_ADMIN\n");
    }
    
    // 回收 CAP_SETPCAP
    if (prctl(PR_CAPBSET_DROP, CAP_SETPCAP, 0, 0, 0) == -1) {
        fprintf(stderr, "Failed to drop CAP_SETPCAP: %s\n", strerror(errno));
    } else {
        printf("Dropped CAP_SETPCAP\n");
    }
    
    // 回收 CAP_SETFCAP
    if (prctl(PR_CAPBSET_DROP, CAP_SETFCAP, 0, 0, 0) == -1) {
        fprintf(stderr, "Failed to drop CAP_SETFCAP: %s\n", strerror(errno));
    } else {
        printf("Dropped CAP_SETFCAP\n");
    }
    
    // 如果有参数，执行指定的命令
    if (argc > 1) {
        execvp(argv[1], &argv[1]);
        fprintf(stderr, "Failed to exec %s: %s\n", argv[1], strerror(errno));
        return 1;
    }
    
    return 0;
}
EOF
    
    # 编译程序
    if gcc -o "$dropper_bin" "$dropper_c" 2>/dev/null; then
        log_success "权限回收程序编译成功"
        chmod +x "$dropper_bin"
        echo "$dropper_bin"
    else
        log_error "权限回收程序编译失败"
        return 1
    fi
}

# 方法3: 直接写入 securebits
set_securebits() {
    log_info "设置 securebits..."
    
    # 设置 SECBIT_NO_SETUID_FIXUP 和 SECBIT_NOROOT
    local securebits_file="/proc/self/securebits"
    
    if [[ -w "$securebits_file" ]]; then
        # 设置安全位，防止权限提升
        echo 3 > "$securebits_file" 2>/dev/null || log_warning "无法设置 securebits"
        log_success "securebits 已设置"
    else
        log_warning "无法写入 securebits"
    fi
}

# 验证权限回收效果
verify_drop_result() {
    log_info "验证权限回收效果..."
    
    local errors=0
    
    # 检查是否还有 SYS_ADMIN 权限
    if capsh --print 2>/dev/null | grep -q "cap_sys_admin"; then
        log_error "CAP_SYS_ADMIN 权限仍然存在"
        ((errors++))
    else
        log_success "CAP_SYS_ADMIN 权限已回收"
    fi
    
    # 检查是否还有 SETPCAP 权限
    if capsh --print 2>/dev/null | grep -q "cap_setpcap"; then
        log_error "CAP_SETPCAP 权限仍然存在"
        ((errors++))
    else
        log_success "CAP_SETPCAP 权限已回收"
    fi
    
    # 尝试执行需要特权的操作，应该失败
    if mount -t tmpfs tmpfs /tmp/test_mount 2>/dev/null; then
        log_error "仍然可以执行 mount 操作，权限回收可能失败"
        umount /tmp/test_mount 2>/dev/null || true
        ((errors++))
    else
        log_success "无法执行 mount 操作，权限回收成功"
    fi
    
    return $errors
}

# 主函数
main() {
    log_info "=== 权限回收脚本 ==="
    
    # 显示当前权限
    show_current_capabilities
    
    # 检查是否需要回收权限
    if ! check_need_drop; then
        log_info "无需回收权限，退出"
        return 0
    fi
    
    # 尝试不同的权限回收方法
    local success=false
    
    # 方法1: capsh
    if command -v capsh &> /dev/null; then
        local capsh_cmd=$(drop_with_capsh)
        if [[ -n "$capsh_cmd" ]]; then
            log_info "可以使用命令回收权限: $capsh_cmd"
            success=true
        fi
    fi
    
    # 方法2: prctl
    local dropper_bin=$(create_prctl_dropper)
    if [[ -n "$dropper_bin" && -x "$dropper_bin" ]]; then
        log_info "执行 prctl 权限回收..."
        "$dropper_bin"
        success=true
    fi
    
    # 方法3: securebits
    set_securebits
    
    # 验证结果
    if $success; then
        verify_drop_result
        log_success "权限回收流程完成"
    else
        log_warning "权限回收可能不完整，请手动检查"
    fi
    
    # 显示最终权限状态
    echo ""
    log_info "最终权限状态:"
    show_current_capabilities
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
