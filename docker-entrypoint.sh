#!/bin/bash
set -e

# Linux Analytics Docker启动脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_message() {
    echo -e "${2}${1}${NC}"
}

print_step() {
    echo -e "${BLUE}[Analytics] ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}[Analytics] ${1}${NC}"
}

print_error() {
    echo -e "${RED}[Analytics] ${1}${NC}"
}

print_header() {
    echo
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}    Linux Analytics Docker版${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

# 初始化环境
init_environment() {
    print_step "初始化运行环境..."

    # 创建必要的目录
    mkdir -p /app/backend/data
    mkdir -p /app/logs
    mkdir -p /var/log/supervisor

    # 检查Docker socket
    if [ -S /var/run/docker.sock ]; then
        print_success "Docker socket已挂载"
    else
        print_error "Docker socket未挂载，容器管理功能将不可用"
    fi

    print_success "环境初始化完成"
}

# 等待服务启动并检查状态
wait_and_check_services() {
    print_step "等待服务启动..."
    sleep 10

    local all_ok=true

    # 检查后端API
    if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
        print_success "后端API服务器 (3001) - 运行正常"
    else
        print_error "后端API服务器 (3001) - 启动失败"
        all_ok=false
    fi

    # 检查WebSSH
    if curl -s http://localhost:3002 > /dev/null 2>&1; then
        print_success "WebSSH服务器 (3002) - 运行正常"
    else
        print_error "WebSSH服务器 (3002) - 启动失败"
        all_ok=false
    fi

    # 检查前端
    if curl -s http://localhost:5173 > /dev/null 2>&1; then
        print_success "前端开发服务器 (5173) - 运行正常"
    else
        print_error "前端开发服务器 (5173) - 启动失败"
        all_ok=false
    fi

    if [ "$all_ok" = true ]; then
        show_success_info
    else
        print_error "部分服务启动失败，请检查日志"
    fi
}

# 显示成功信息
show_success_info() {
    echo
    print_message "🎉 Linux Analytics已成功启动！" $GREEN
    echo
    print_message "📱 访问地址:" $CYAN
    print_message "   主应用:    http://localhost:3001" $BLUE
    print_message "   前端开发:  http://localhost:5173" $BLUE
    print_message "   WebSSH:    http://localhost:3002" $BLUE
    echo
    print_message "🔧 功能特性:" $CYAN
    print_message "   🐳 一人一个独立容器" $BLUE
    print_message "   🛡️ 完全安全隔离" $BLUE
    print_message "   💻 现代化终端体验" $BLUE
    print_message "   💬 实时聊天功能" $BLUE
    echo
    print_message "📋 日志查看:" $CYAN
    print_message "   docker logs <container_name>" $BLUE
    print_message "   docker exec -it <container_name> tail -f /var/log/supervisor/*.log" $BLUE
    echo
}

# 主函数
main() {
    print_header

    case "${1:-start}" in
        start)
            init_environment

            print_step "启动所有服务..."
            print_message "使用Supervisor管理多个服务进程" $YELLOW

            # 启动supervisor来管理所有服务
            exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
            ;;
        bash)
            exec /bin/bash
            ;;
        logs)
            tail -f /var/log/supervisor/*.log
            ;;
        *)
            print_error "未知命令: $1"
            print_message "可用命令: start, bash, logs" $YELLOW
            exit 1
            ;;
    esac
}

main "$@"
