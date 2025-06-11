#!/bin/bash

# Linux Analytics - 临时存储监控脚本
# 监控临时存储区的使用情况

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印函数
print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  临时存储监控 - $(date)${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 获取磁盘使用情况
get_disk_usage() {
    print_section "磁盘使用情况"
    
    echo "总体磁盘使用:"
    df -h | grep -E "(Filesystem|/tmp|/workspaces|overlay|/dev/root)"
    
    echo ""
    echo "临时存储详情:"
    local tmp_total=$(df -h /tmp | awk 'NR==2 {print $2}')
    local tmp_used=$(df -h /tmp | awk 'NR==2 {print $3}')
    local tmp_avail=$(df -h /tmp | awk 'NR==2 {print $4}')
    local tmp_percent=$(df -h /tmp | awk 'NR==2 {print $5}' | sed 's/%//')
    
    echo "  总容量: $tmp_total"
    echo "  已使用: $tmp_used"
    echo "  可用空间: $tmp_avail"
    echo "  使用率: $tmp_percent%"
    
    # 使用率警告
    if [ "$tmp_percent" -gt 80 ]; then
        print_error "临时存储使用率过高 ($tmp_percent%)"
    elif [ "$tmp_percent" -gt 60 ]; then
        print_warning "临时存储使用率较高 ($tmp_percent%)"
    else
        print_info "临时存储使用率正常 ($tmp_percent%)"
    fi
}

# 检查容器数据目录
check_container_directories() {
    print_section "容器数据目录"
    
    if [ -d "/tmp/containers" ]; then
        local container_count=$(find /tmp/containers -maxdepth 1 -type d | wc -l)
        container_count=$((container_count - 1)) # 减去根目录
        
        echo "容器数据目录: /tmp/containers"
        echo "用户容器数量: $container_count"
        
        if [ $container_count -gt 0 ]; then
            echo ""
            echo "用户容器列表:"
            ls -la /tmp/containers/ | grep -v "^total" | tail -n +2
            
            echo ""
            echo "各用户容器大小:"
            du -sh /tmp/containers/* 2>/dev/null | head -10
        else
            print_info "当前没有用户容器"
        fi
    else
        print_warning "容器数据目录不存在: /tmp/containers"
    fi
}

# 检查应用数据
check_app_data() {
    print_section "应用数据"
    
    echo "应用数据目录:"
    for dir in "/tmp/app-data" "/tmp/app-logs" "/tmp/docker-data"; do
        if [ -d "$dir" ]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "  $dir: $size"
        else
            echo "  $dir: 不存在"
        fi
    done
    
    # 检查符号链接
    echo ""
    echo "应用符号链接:"
    if [ -L "backend/data" ]; then
        echo "  backend/data -> $(readlink backend/data)"
    else
        echo "  backend/data: 不是符号链接"
    fi
    
    if [ -L "logs" ]; then
        echo "  logs -> $(readlink logs)"
    else
        echo "  logs: 不是符号链接"
    fi
}

# 检查Docker状态
check_docker_status() {
    print_section "Docker状态"
    
    if command -v docker &> /dev/null; then
        echo "Docker版本:"
        docker --version
        
        echo ""
        echo "Docker信息:"
        docker info | grep -E "(Storage Driver|Docker Root Dir|Data Space|Metadata Space)" || true
        
        echo ""
        echo "Docker磁盘使用:"
        docker system df
        
        echo ""
        echo "运行中的容器:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}"
        
    else
        print_error "Docker未安装或不可用"
    fi
}

# 检查内存使用
check_memory_usage() {
    print_section "内存使用情况"
    
    echo "系统内存:"
    free -h
    
    echo ""
    echo "进程内存使用 (前10):"
    ps aux --sort=-%mem | head -11
}

# 清理建议
cleanup_suggestions() {
    print_section "清理建议"
    
    # 检查大文件
    echo "临时存储中的大文件 (>100MB):"
    find /tmp -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -5 || echo "  没有发现大文件"
    
    echo ""
    echo "可执行的清理操作:"
    echo "  1. 清理Docker缓存: docker system prune -f"
    echo "  2. 清理构建缓存: docker builder prune -f"
    echo "  3. 清理未使用的镜像: docker image prune -f"
    echo "  4. 清理停止的容器: docker container prune -f"
    echo "  5. 清理旧的容器数据: rm -rf /tmp/containers/unused-*"
    
    # 自动清理建议
    local tmp_percent=$(df /tmp | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$tmp_percent" -gt 70 ]; then
        echo ""
        print_warning "建议立即执行清理操作"
        echo "快速清理命令: docker system prune -f && docker builder prune -f"
    fi
}

# 实时监控模式
monitor_mode() {
    print_section "实时监控模式"
    print_info "按 Ctrl+C 退出监控"
    
    while true; do
        clear
        print_header
        get_disk_usage
        check_memory_usage
        
        echo ""
        echo "下次更新: $(date -d '+30 seconds')"
        sleep 30
    done
}

# 显示帮助
show_help() {
    echo "Linux Analytics 临时存储监控脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -m, --monitor  实时监控模式"
    echo "  -c, --clean    显示清理建议"
    echo "  -q, --quick    快速检查"
    echo ""
    echo "示例:"
    echo "  $0              # 完整检查"
    echo "  $0 -m           # 实时监控"
    echo "  $0 -q           # 快速检查"
    echo "  $0 -c           # 清理建议"
}

# 快速检查
quick_check() {
    print_header
    get_disk_usage
    check_container_directories
    
    local tmp_percent=$(df /tmp | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$tmp_percent" -gt 80 ]; then
        cleanup_suggestions
    fi
}

# 完整检查
full_check() {
    print_header
    get_disk_usage
    check_container_directories
    check_app_data
    check_docker_status
    check_memory_usage
    cleanup_suggestions
}

# 主函数
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -m|--monitor)
            monitor_mode
            ;;
        -c|--clean)
            print_header
            cleanup_suggestions
            ;;
        -q|--quick)
            quick_check
            ;;
        "")
            full_check
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 -h 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
