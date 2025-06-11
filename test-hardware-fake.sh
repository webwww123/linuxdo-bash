#!/bin/bash

# 硬件伪装测试脚本
# 用于验证 OverlayFS + LD_PRELOAD 伪装效果

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  硬件伪装效果测试${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -e "${YELLOW}[测试]${NC} $1"
}

print_result() {
    local expected="$1"
    local actual="$2"
    local description="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}[通过]${NC} $description: $actual"
        return 0
    else
        echo -e "${RED}[失败]${NC} $description: $actual (期望: $expected)"
        return 1
    fi
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

# 测试CPU信息
test_cpu_info() {
    print_section "CPU信息测试"
    
    local errors=0
    
    # 测试 nproc
    print_test "测试 nproc 命令"
    local nproc_result=$(nproc)
    print_result "24" "$nproc_result" "CPU核心数 (nproc)" || ((errors++))
    
    # 测试 /proc/cpuinfo
    print_test "测试 /proc/cpuinfo"
    local cpuinfo_count=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "0")
    print_result "24" "$cpuinfo_count" "CPU核心数 (/proc/cpuinfo)" || ((errors++))
    
    # 测试 lscpu
    print_test "测试 lscpu 命令"
    if command -v lscpu &> /dev/null; then
        local lscpu_cores=$(lscpu | grep "^CPU(s):" | awk '{print $2}' || echo "0")
        print_result "24" "$lscpu_cores" "CPU核心数 (lscpu)" || ((errors++))
        
        # 显示CPU型号
        local cpu_model=$(lscpu | grep "Model name:" | cut -d: -f2 | xargs || echo "未知")
        print_info "CPU型号: $cpu_model"
    else
        echo -e "${YELLOW}[跳过]${NC} lscpu 命令不可用"
    fi
    
    return $errors
}

# 测试内存信息
test_memory_info() {
    print_section "内存信息测试"
    
    local errors=0
    
    # 测试 /proc/meminfo
    print_test "测试 /proc/meminfo"
    local mem_total_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local mem_total_gb=$((mem_total_kb / 1024 / 1024))
    
    if [[ $mem_total_gb -ge 60 && $mem_total_gb -le 68 ]]; then
        echo -e "${GREEN}[通过]${NC} 内存总量: ${mem_total_gb}GB"
    else
        echo -e "${RED}[失败]${NC} 内存总量: ${mem_total_gb}GB (期望: ~64GB)"
        ((errors++))
    fi
    
    # 测试 free 命令
    print_test "测试 free 命令"
    if command -v free &> /dev/null; then
        local free_total=$(free -g | grep "Mem:" | awk '{print $2}' || echo "0")
        if [[ $free_total -ge 60 && $free_total -le 68 ]]; then
            echo -e "${GREEN}[通过]${NC} 内存总量 (free): ${free_total}GB"
        else
            echo -e "${RED}[失败]${NC} 内存总量 (free): ${free_total}GB (期望: ~64GB)"
            ((errors++))
        fi
    else
        echo -e "${YELLOW}[跳过]${NC} free 命令不可用"
    fi
    
    return $errors
}

# 测试存储信息
test_storage_info() {
    print_section "存储信息测试"
    
    local errors=0
    
    # 测试 df 命令
    print_test "测试 df 命令"
    if command -v df &> /dev/null; then
        local df_size=$(df -h / | tail -1 | awk '{print $2}' | sed 's/[GT]//' || echo "0")
        local df_size_num=$(echo "$df_size" | sed 's/[^0-9.]//g')
        
        # 检查是否接近1TB (900GB-1100GB范围)
        if (( $(echo "$df_size_num > 900" | bc -l) )) && [[ "$df_size" == *"T"* || $df_size_num -gt 900 ]]; then
            echo -e "${GREEN}[通过]${NC} 存储容量: $df_size"
        else
            echo -e "${RED}[失败]${NC} 存储容量: $df_size (期望: ~1T)"
            ((errors++))
        fi
    else
        echo -e "${YELLOW}[跳过]${NC} df 命令不可用"
    fi
    
    return $errors
}

# 测试系统调用
test_system_calls() {
    print_section "系统调用测试"
    
    local errors=0
    
    # 检查 LD_PRELOAD 是否生效
    print_test "检查 LD_PRELOAD 钩子"
    if [[ "${FAKEHW_LOADED:-}" == "1" ]]; then
        echo -e "${GREEN}[通过]${NC} LD_PRELOAD 钩子已加载"
    else
        echo -e "${RED}[失败]${NC} LD_PRELOAD 钩子未加载"
        ((errors++))
    fi
    
    # 检查 /etc/ld.so.preload
    print_test "检查 ld.so.preload 配置"
    if grep -q "libfakehw.so" /etc/ld.so.preload 2>/dev/null; then
        echo -e "${GREEN}[通过]${NC} ld.so.preload 已配置"
    else
        echo -e "${RED}[失败]${NC} ld.so.preload 未配置"
        ((errors++))
    fi
    
    return $errors
}

# 测试文件系统覆盖
test_filesystem_overlay() {
    print_section "文件系统覆盖测试"
    
    local errors=0
    
    # 检查 /proc 挂载
    print_test "检查 /proc OverlayFS 挂载"
    if mount | grep -q "overlay.*on /proc"; then
        echo -e "${GREEN}[通过]${NC} /proc 已被 OverlayFS 覆盖"
    else
        echo -e "${RED}[失败]${NC} /proc 未被 OverlayFS 覆盖"
        ((errors++))
    fi
    
    # 检查伪造文件
    print_test "检查伪造文件"
    local fake_files=("/proc/cpuinfo" "/proc/meminfo" "/proc/stat")
    for file in "${fake_files[@]}"; do
        if [[ -r "$file" ]]; then
            echo -e "${GREEN}[通过]${NC} $file 可读"
        else
            echo -e "${RED}[失败]${NC} $file 不可读"
            ((errors++))
        fi
    done
    
    return $errors
}

# 综合测试 - 运行常用命令
test_common_commands() {
    print_section "常用命令测试"
    
    print_test "运行常用系统信息命令"
    
    # htop (如果可用)
    if command -v htop &> /dev/null; then
        print_info "htop 可用 - 建议手动运行查看效果"
    fi
    
    # neofetch (如果可用)
    if command -v neofetch &> /dev/null; then
        print_info "neofetch 可用 - 运行效果:"
        echo "----------------------------------------"
        timeout 10s neofetch 2>/dev/null || echo "neofetch 运行超时或出错"
        echo "----------------------------------------"
    fi
    
    # 显示关键信息摘要
    print_info "系统信息摘要:"
    echo "  CPU核心: $(nproc)"
    echo "  内存总量: $(free -h | grep Mem | awk '{print $2}')"
    echo "  存储容量: $(df -h / | tail -1 | awk '{print $2}')"
}

# 主测试函数
main() {
    print_header
    
    local total_errors=0
    
    # 运行各项测试
    test_cpu_info || total_errors=$((total_errors + $?))
    test_memory_info || total_errors=$((total_errors + $?))
    test_storage_info || total_errors=$((total_errors + $?))
    test_system_calls || total_errors=$((total_errors + $?))
    test_filesystem_overlay || total_errors=$((total_errors + $?))
    test_common_commands
    
    # 显示测试结果
    print_section "测试结果"
    if [[ $total_errors -eq 0 ]]; then
        echo -e "${GREEN}[成功]${NC} 所有测试通过！硬件伪装效果良好。"
    else
        echo -e "${RED}[失败]${NC} 发现 $total_errors 个问题，硬件伪装可能不完整。"
    fi
    
    print_section "建议测试命令"
    echo "手动运行以下命令验证效果："
    echo "  lscpu"
    echo "  free -h"
    echo "  df -h"
    echo "  htop"
    echo "  neofetch"
    echo "  cat /proc/cpuinfo | head -20"
    echo "  cat /proc/meminfo | head -10"
    
    return $total_errors
}

# 执行测试
main "$@"
