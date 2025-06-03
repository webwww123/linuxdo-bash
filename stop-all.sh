#!/bin/bash

# LinuxDo自习室 - 停止所有服务脚本

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
    echo -e "${CYAN}  LinuxDo自习室 - 停止服务${NC}"
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

# 停止通过PID文件记录的进程
stop_pid_services() {
    print_step "停止记录的服务进程..."
    
    # 停止后端服务
    if [ -f "logs/backend.pid" ]; then
        BACKEND_PID=$(cat logs/backend.pid)
        if kill -0 $BACKEND_PID 2>/dev/null; then
            kill $BACKEND_PID
            print_success "后端API服务器已停止 (PID: $BACKEND_PID)"
        else
            print_warning "后端API服务器进程不存在 (PID: $BACKEND_PID)"
        fi
        rm -f logs/backend.pid
    fi
    
    # 停止WebSSH服务
    if [ -f "logs/webssh.pid" ]; then
        WEBSSH_PID=$(cat logs/webssh.pid)
        if kill -0 $WEBSSH_PID 2>/dev/null; then
            kill $WEBSSH_PID
            print_success "WebSSH服务器已停止 (PID: $WEBSSH_PID)"
        else
            print_warning "WebSSH服务器进程不存在 (PID: $WEBSSH_PID)"
        fi
        rm -f logs/webssh.pid
    fi
    
    # 停止前端服务
    if [ -f "logs/frontend.pid" ]; then
        FRONTEND_PID=$(cat logs/frontend.pid)
        if kill -0 $FRONTEND_PID 2>/dev/null; then
            kill $FRONTEND_PID
            print_success "前端开发服务器已停止 (PID: $FRONTEND_PID)"
        else
            print_warning "前端开发服务器进程不存在 (PID: $FRONTEND_PID)"
        fi
        rm -f logs/frontend.pid
    fi

    # 停止Grafana服务
    if [ -f "logs/grafana.pid" ]; then
        GRAFANA_PID=$(cat logs/grafana.pid)
        if kill -0 $GRAFANA_PID 2>/dev/null; then
            kill $GRAFANA_PID
            print_success "Grafana监控服务器已停止 (PID: $GRAFANA_PID)"
        else
            print_warning "Grafana监控服务器进程不存在 (PID: $GRAFANA_PID)"
        fi
        rm -f logs/grafana.pid
    fi
}

# 强制停止所有相关进程
force_stop_processes() {
    print_step "强制停止所有相关进程..."
    
    # 停止Node.js进程
    KILLED_PROCESSES=0
    
    # 停止后端服务器
    if pkill -f "node.*server.js" 2>/dev/null; then
        print_success "强制停止后端服务器进程"
        KILLED_PROCESSES=$((KILLED_PROCESSES + 1))
    fi
    
    # 停止WebSSH服务器
    if pkill -f "node.*webssh-server.js" 2>/dev/null; then
        print_success "强制停止WebSSH服务器进程"
        KILLED_PROCESSES=$((KILLED_PROCESSES + 1))
    fi
    
    # 停止npm进程
    if pkill -f "npm.*start" 2>/dev/null; then
        print_success "强制停止npm start进程"
        KILLED_PROCESSES=$((KILLED_PROCESSES + 1))
    fi
    
    if pkill -f "npm.*dev" 2>/dev/null; then
        print_success "强制停止npm dev进程"
        KILLED_PROCESSES=$((KILLED_PROCESSES + 1))
    fi
    
    # 停止Vite进程
    if pkill -f "vite" 2>/dev/null; then
        print_success "强制停止Vite进程"
        KILLED_PROCESSES=$((KILLED_PROCESSES + 1))
    fi
    
    if [ $KILLED_PROCESSES -eq 0 ]; then
        print_warning "没有找到需要停止的进程"
    else
        print_success "强制停止了 $KILLED_PROCESSES 个进程"
    fi
}

# 停止Docker容器
stop_docker_containers() {
    print_step "停止Docker容器..."
    
    # 获取Linux相关容器
    CONTAINERS=$(docker ps -q --filter "name=linux-" 2>/dev/null || true)

    if [ -n "$CONTAINERS" ]; then
        print_message "停止Linux容器..." $YELLOW
        docker stop $CONTAINERS
        print_success "Docker容器已停止"

        # 可选：删除容器（注释掉以保持容器持久化）
        # print_message "删除Linux容器..." $YELLOW
        # docker rm $CONTAINERS
        # print_success "Docker容器已删除"
    else
        print_warning "没有找到运行中的Linux容器"
    fi
}

# 检查端口占用
check_ports() {
    print_step "检查端口占用情况..."
    
    PORTS=(3001 3002 5173 8080)
    
    for PORT in "${PORTS[@]}"; do
        if lsof -i :$PORT >/dev/null 2>&1; then
            print_warning "端口 $PORT 仍被占用"
            # 显示占用进程
            PROCESS=$(lsof -i :$PORT | tail -n 1 | awk '{print $2}')
            if [ -n "$PROCESS" ]; then
                print_message "  占用进程 PID: $PROCESS" $YELLOW
            fi
        else
            print_success "端口 $PORT 已释放"
        fi
    done
}

# 清理临时文件
cleanup_files() {
    print_step "清理临时文件..."
    
    # 清理PID文件
    rm -f logs/*.pid
    
    # 清理空的日志文件
    find logs -name "*.log" -size 0 -delete 2>/dev/null || true
    
    print_success "临时文件清理完成"
}

# 显示停止信息
show_stop_info() {
    echo
    print_message "🛑 LinuxDo自习室服务已停止" $GREEN
    echo
    print_message "📋 状态信息:" $CYAN
    print_message "   所有Node.js进程已停止" $BLUE
    print_message "   Docker容器已停止（但未删除）" $BLUE
    print_message "   端口已释放" $BLUE
    echo
    print_message "🔧 相关命令:" $CYAN
    print_message "   重新启动: ./start-all.sh" $BLUE
    print_message "   查看日志: tail -f logs/*.log" $BLUE
    print_message "   清理容器: docker rm \$(docker ps -aq --filter \"name=linuxdo-\")" $BLUE
    echo
}

# 主函数
main() {
    print_header
    
    # 解析命令行参数
    FORCE_KILL=false
    CLEAN_CONTAINERS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_KILL=true
                shift
                ;;
            --clean-containers)
                CLEAN_CONTAINERS=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --force             强制杀死所有相关进程"
                echo "  --clean-containers  同时删除Docker容器"
                echo "  --help, -h          显示帮助信息"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 执行停止流程
    stop_pid_services
    
    if [ "$FORCE_KILL" = true ]; then
        force_stop_processes
    fi
    
    stop_docker_containers
    
    if [ "$CLEAN_CONTAINERS" = true ]; then
        print_step "删除Docker容器..."
        docker rm $(docker ps -aq --filter "name=linux-") 2>/dev/null || true
        print_success "Docker容器已删除"
    fi
    
    # 等待进程完全停止
    sleep 2
    
    check_ports
    cleanup_files
    show_stop_info
}

# 运行主函数
main "$@"
