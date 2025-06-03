#!/bin/bash

# Linux容器管理系统 - 快速重启脚本

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${2}${1}${NC}"
}

print_header() {
    echo
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  Linux容器管理系统 - 快速重启${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}[步骤] ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}[成功] ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}[警告] ${1}${NC}"
}

print_error() {
    echo -e "${RED}[错误] ${1}${NC}"
}

# 主函数
main() {
    print_header
    
    # 解析命令行参数
    SKIP_DEPS=true  # 重启时默认跳过依赖安装
    SKIP_BUILD=true # 重启时默认跳过Docker构建
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                SKIP_DEPS=false
                SKIP_BUILD=false
                shift
                ;;
            --with-deps)
                SKIP_DEPS=false
                shift
                ;;
            --with-build)
                SKIP_BUILD=false
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --full        完整重启（包含依赖安装和Docker构建）"
                echo "  --with-deps   重启时重新安装依赖"
                echo "  --with-build  重启时重新构建Docker镜像"
                echo "  --help, -h    显示帮助信息"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    print_step "开始重启Linux容器管理系统..."
    
    # 停止所有服务
    print_message "正在停止所有服务..." $YELLOW
    if [ -f "./stop-all.sh" ]; then
        ./stop-all.sh
    else
        print_error "找不到 stop-all.sh 脚本"
        exit 1
    fi
    
    print_success "服务停止完成"
    
    # 等待一下确保所有进程完全停止
    print_message "等待进程完全停止..." $YELLOW
    sleep 3
    
    # 启动所有服务
    print_message "正在启动所有服务..." $YELLOW
    if [ -f "./start-all.sh" ]; then
        START_ARGS=""
        if [ "$SKIP_DEPS" = true ]; then
            START_ARGS="$START_ARGS --skip-deps"
        fi
        if [ "$SKIP_BUILD" = true ]; then
            START_ARGS="$START_ARGS --skip-build"
        fi
        
        ./start-all.sh $START_ARGS
    else
        print_error "找不到 start-all.sh 脚本"
        exit 1
    fi
}

# 运行主函数
main "$@"
