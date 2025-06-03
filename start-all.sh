#!/bin/bash

# linux自习室 - 一键启动脚本
# 启动所有必要的服务：前端、后端API、WebSSH服务器

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${2}${1}${NC}"
}

print_header() {
    echo
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  linux自习室 - 一键启动${NC}"
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

# 检查依赖
check_dependencies() {
    print_step "检查系统依赖..."
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js 未安装，请先安装 Node.js"
        exit 1
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        print_error "npm 未安装，请先安装 npm"
        exit 1
    fi
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        print_error "Docker 未运行，请启动 Docker 服务"
        exit 1
    fi
    
    print_success "所有依赖检查通过"
}

# 安装依赖包
install_dependencies() {
    print_step "安装项目依赖..."
    
    # 安装根目录依赖
    if [ -f "package.json" ]; then
        print_message "安装根目录依赖..." $YELLOW
        npm install
    fi
    
    # 安装后端依赖
    if [ -d "backend" ] && [ -f "backend/package.json" ]; then
        print_message "安装后端依赖..." $YELLOW
        cd backend
        npm install
        cd ..
    fi
    
    # 安装前端依赖
    if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
        print_message "安装前端依赖..." $YELLOW
        cd frontend
        npm install
        cd ..
    fi
    
    print_success "依赖安装完成"
}

# 构建Docker镜像
build_docker_image() {
    print_step "构建Docker镜像..."
    
    if [ -f "docker/Dockerfile.ubuntu" ]; then
        print_message "构建Ubuntu容器镜像..." $YELLOW
        docker build -t linux-ubuntu:latest -f docker/Dockerfile.ubuntu .
        print_success "Docker镜像构建完成"
    else
        print_warning "未找到Docker文件，跳过镜像构建"
    fi
}

# 创建必要的目录
create_directories() {
    print_step "创建必要的目录..."
    
    mkdir -p backend/data
    mkdir -p logs
    
    print_success "目录创建完成"
}

# 清理旧的进程和容器
cleanup() {
    print_step "清理旧的进程和容器..."
    
    # 停止可能运行的Node.js进程
    pkill -f "node.*server.js" 2>/dev/null || true
    pkill -f "node.*webssh-server.js" 2>/dev/null || true
    pkill -f "npm.*start" 2>/dev/null || true
    pkill -f "npm.*dev" 2>/dev/null || true
    
    # 清理Docker容器
    docker stop $(docker ps -q --filter "name=linux-") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=linux-") 2>/dev/null || true
    
    print_success "清理完成"
}

# 启动服务
start_services() {
    print_step "启动所有服务..."
    
    # 创建日志目录
    mkdir -p logs
    
    # 启动后端API服务器
    print_message "启动后端API服务器 (端口 3001)..." $YELLOW
    cd backend
    nohup npm start > ../logs/backend.log 2>&1 &
    BACKEND_PID=$!
    cd ..
    
    # 等待后端启动
    sleep 3
    
    # 启动WebSSH服务器
    print_message "启动WebSSH服务器 (端口 3002)..." $YELLOW
    cd backend
    nohup node webssh-server.js > ../logs/webssh.log 2>&1 &
    WEBSSH_PID=$!
    cd ..
    
    # 等待WebSSH启动
    sleep 2
    
    # 启动前端开发服务器
    print_message "启动前端开发服务器 (端口 5173)..." $YELLOW
    cd frontend
    nohup npm run dev > ../logs/frontend.log 2>&1 &
    FRONTEND_PID=$!
    cd ..

    # 等待前端启动
    sleep 2

    # 启动Grafana监控界面
    print_message "启动Grafana监控界面 (端口 8080)..." $YELLOW
    cd backend
    nohup npm run start:grafana > ../logs/grafana.log 2>&1 &
    GRAFANA_PID=$!
    cd ..

    # 保存PID到文件
    echo $BACKEND_PID > logs/backend.pid
    echo $WEBSSH_PID > logs/webssh.pid
    echo $FRONTEND_PID > logs/frontend.pid
    echo $GRAFANA_PID > logs/grafana.pid
    
    print_success "所有服务启动完成"
}

# 检查服务状态
check_services() {
    print_step "检查服务状态..."
    
    sleep 5  # 等待服务完全启动
    
    # 检查后端API
    if curl -s http://localhost:3001/api/health > /dev/null; then
        print_success "后端API服务器 (3001) - 运行正常"
    else
        print_error "后端API服务器 (3001) - 启动失败"
    fi
    
    # 检查WebSSH
    if curl -s http://localhost:3002 > /dev/null; then
        print_success "WebSSH服务器 (3002) - 运行正常"
    else
        print_error "WebSSH服务器 (3002) - 启动失败"
    fi
    
    # 检查前端
    if curl -s http://localhost:5173 > /dev/null; then
        print_success "前端开发服务器 (5173) - 运行正常"
    else
        print_error "前端开发服务器 (5173) - 启动失败"
    fi
}

# 显示访问信息
show_access_info() {
    echo
    print_message "🎉 linux自习室启动成功！" $GREEN
    echo
    print_message "📱 访问地址:" $CYAN
    print_message "   前端应用: http://localhost:5173" $BLUE
    print_message "   后端API: http://localhost:3001" $BLUE
    print_message "   WebSSH:  http://localhost:3002" $BLUE
    echo
    print_message "📋 功能特性:" $CYAN
    print_message "   🐳 一人一个独立容器" $BLUE
    print_message "   🛡️ 完全安全隔离" $BLUE
    print_message "   💻 现代化终端体验" $BLUE
    print_message "   💬 实时聊天功能" $BLUE
    print_message "   📊 用户状态监控" $BLUE
    echo
    print_message "🔧 管理命令:" $CYAN
    print_message "   停止服务: ./stop-all.sh" $BLUE
    print_message "   查看日志: tail -f logs/*.log" $BLUE
    print_message "   重启服务: ./stop-all.sh && ./start-all.sh" $BLUE
    echo
    print_message "📝 日志文件:" $CYAN
    print_message "   后端日志: logs/backend.log" $BLUE
    print_message "   WebSSH日志: logs/webssh.log" $BLUE
    print_message "   前端日志: logs/frontend.log" $BLUE
    echo
}

# 主函数
main() {
    print_header
    
    # 解析命令行参数
    SKIP_DEPS=false
    SKIP_BUILD=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --skip-deps   跳过依赖安装"
                echo "  --skip-build  跳过Docker镜像构建"
                echo "  --help, -h    显示帮助信息"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 执行启动流程
    check_dependencies
    
    if [ "$SKIP_DEPS" = false ]; then
        install_dependencies
    else
        print_warning "跳过依赖安装"
    fi
    
    if [ "$SKIP_BUILD" = false ]; then
        build_docker_image
    else
        print_warning "跳过Docker镜像构建"
    fi
    
    create_directories
    cleanup
    start_services
    check_services
    show_access_info
    
    print_message "按 Ctrl+C 停止所有服务" $YELLOW
    
    # 等待用户中断
    trap 'echo; print_message "正在停止服务..." $YELLOW; ./stop-all.sh 2>/dev/null || true; exit 0' INT
    
    # 保持脚本运行
    while true; do
        sleep 1
    done
}

# 运行主函数
main "$@"
