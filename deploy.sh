#!/bin/bash

# Linux Analytics 无特权硬件伪装系统自动部署脚本
# 作者: Linux Analytics Team
# 版本: 1.0.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装，请先安装 $1"
        exit 1
    fi
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "此脚本仅支持 Linux 系统"
        exit 1
    fi
    
    # 检查必要命令
    check_command "docker"
    check_command "node"
    check_command "npm"
    check_command "git"
    check_command "gcc"
    
    # 检查 Node.js 版本
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 16 ]; then
        log_error "Node.js 版本过低，需要 16.0 或更高版本"
        exit 1
    fi
    
    # 检查 Docker 版本
    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [ "$(echo "$DOCKER_VERSION < 20.10" | bc -l)" -eq 1 ]; then
        log_error "Docker 版本过低，需要 20.10 或更高版本"
        exit 1
    fi
    
    log_success "系统要求检查通过"
}

# 配置 Docker 权限
setup_docker_permissions() {
    log_info "配置 Docker 权限..."
    
    # 检查 Docker 服务状态
    if ! systemctl is-active --quiet docker; then
        log_warning "Docker 服务未运行，正在启动..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # 配置 Docker socket 权限
    if [ -S /var/run/docker.sock ]; then
        sudo chmod 666 /var/run/docker.sock
        log_success "Docker socket 权限配置完成"
    else
        log_error "Docker socket 不存在"
        exit 1
    fi
    
    # 将用户添加到 docker 组（可选）
    if ! groups $USER | grep -q docker; then
        log_info "将用户添加到 docker 组..."
        sudo usermod -aG docker $USER
        log_warning "请重新登录以使 docker 组权限生效"
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装项目依赖..."
    
    # 后端依赖
    cd backend
    if [ ! -d "node_modules" ]; then
        log_info "安装后端依赖..."
        npm install
    else
        log_info "后端依赖已存在，跳过安装"
    fi
    
    # 前端依赖
    cd ../frontend
    if [ ! -d "node_modules" ]; then
        log_info "安装前端依赖..."
        npm install
        log_info "构建前端..."
        npm run build
    else
        log_info "前端依赖已存在，跳过安装"
    fi
    
    cd ..
    log_success "依赖安装完成"
}

# 编译硬件伪装库
compile_hardware_spoof() {
    log_info "编译硬件伪装库..."
    
    if [ ! -f "docker/hardware_spoof.so" ] || [ "docker/hardware_spoof.c" -nt "docker/hardware_spoof.so" ]; then
        gcc -shared -fPIC -ldl docker/hardware_spoof.c -o docker/hardware_spoof.so
        if [ $? -eq 0 ]; then
            log_success "硬件伪装库编译成功"
        else
            log_error "硬件伪装库编译失败"
            exit 1
        fi
    else
        log_info "硬件伪装库已是最新版本"
    fi
}

# 构建 Docker 镜像
build_docker_image() {
    log_info "构建 Docker 镜像..."
    
    # 检查镜像是否存在
    if docker images | grep -q "linux-ubuntu.*latest"; then
        log_warning "Docker 镜像已存在，是否重新构建？(y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "跳过镜像构建"
            return
        fi
    fi
    
    docker build -f docker/Dockerfile.ubuntu -t linux-ubuntu:latest .
    if [ $? -eq 0 ]; then
        log_success "Docker 镜像构建成功"
    else
        log_error "Docker 镜像构建失败"
        exit 1
    fi
}

# 设置数据目录
setup_data_directory() {
    log_info "设置数据目录..."
    
    DATA_DIR="/tmp/app-data"
    
    # 创建数据目录
    if [ ! -d "$DATA_DIR" ]; then
        mkdir -p "$DATA_DIR"
    fi
    
    # 设置权限
    chmod 777 "$DATA_DIR"
    
    # 创建数据库文件
    if [ ! -f "$DATA_DIR/users.db" ]; then
        touch "$DATA_DIR/users.db"
    fi
    chmod 666 "$DATA_DIR/users.db"
    
    log_success "数据目录设置完成"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用..."
    
    PORTS=(8080 3002)
    for port in "${PORTS[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warning "端口 $port 被占用"
            log_info "占用进程信息:"
            netstat -tlnp 2>/dev/null | grep ":$port "
            log_warning "请手动处理端口冲突或使用 -f 参数强制终止占用进程"
        fi
    done
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 设置环境变量
    export DOCKER_HOST="unix:///var/run/docker.sock"
    export PORT=8080
    
    # 启动 WebSSH 服务
    log_info "启动 WebSSH 服务..."
    cd backend
    nohup node webssh-server.js > ../logs/webssh.log 2>&1 &
    WEBSSH_PID=$!
    echo $WEBSSH_PID > ../logs/webssh.pid
    
    # 等待 WebSSH 服务启动
    sleep 2
    if kill -0 $WEBSSH_PID 2>/dev/null; then
        log_success "WebSSH 服务启动成功 (PID: $WEBSSH_PID)"
    else
        log_error "WebSSH 服务启动失败"
        exit 1
    fi
    
    # 启动主服务
    log_info "启动主服务..."
    nohup node server.js > ../logs/server.log 2>&1 &
    SERVER_PID=$!
    echo $SERVER_PID > ../logs/server.pid
    
    # 等待主服务启动
    sleep 3
    if kill -0 $SERVER_PID 2>/dev/null; then
        log_success "主服务启动成功 (PID: $SERVER_PID)"
    else
        log_error "主服务启动失败"
        cat ../logs/server.log
        exit 1
    fi
    
    cd ..
}

# 启动 Cloudflare 隧道
start_cloudflare_tunnel() {
    log_info "启动 Cloudflare 隧道..."
    
    if command -v cloudflared &> /dev/null; then
        nohup cloudflared tunnel --url http://localhost:8080 > logs/cloudflare.log 2>&1 &
        CLOUDFLARE_PID=$!
        echo $CLOUDFLARE_PID > logs/cloudflare.pid
        
        # 等待隧道建立
        log_info "等待 Cloudflare 隧道建立..."
        sleep 10
        
        # 提取隧道 URL
        if [ -f "logs/cloudflare.log" ]; then
            TUNNEL_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' logs/cloudflare.log | head -1)
            if [ -n "$TUNNEL_URL" ]; then
                log_success "Cloudflare 隧道已建立"
                log_success "访问地址: $TUNNEL_URL"
                echo "$TUNNEL_URL" > logs/tunnel_url.txt
            else
                log_warning "无法获取隧道 URL，请检查日志文件"
            fi
        fi
    else
        log_warning "cloudflared 未安装，跳过 Cloudflare 隧道"
        log_info "本地访问地址: http://localhost:8080"
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查服务状态
    if curl -s http://localhost:8080 > /dev/null; then
        log_success "主服务运行正常"
    else
        log_error "主服务无法访问"
        return 1
    fi
    
    if curl -s http://localhost:3002 > /dev/null; then
        log_success "WebSSH 服务运行正常"
    else
        log_error "WebSSH 服务无法访问"
        return 1
    fi
    
    # 检查 Docker 镜像
    if docker images | grep -q "linux-ubuntu.*latest"; then
        log_success "Docker 镜像存在"
    else
        log_error "Docker 镜像不存在"
        return 1
    fi
    
    log_success "部署验证通过"
}

# 显示部署信息
show_deployment_info() {
    echo
    log_success "🎉 Linux Analytics 部署完成！"
    echo
    echo "📋 服务信息:"
    echo "  - 主服务: http://localhost:8080"
    echo "  - WebSSH: http://localhost:3002"
    
    if [ -f "logs/tunnel_url.txt" ]; then
        TUNNEL_URL=$(cat logs/tunnel_url.txt)
        echo "  - 外网访问: $TUNNEL_URL"
    fi
    
    echo
    echo "📁 重要文件:"
    echo "  - 日志目录: ./logs/"
    echo "  - 数据目录: /tmp/app-data/"
    echo "  - PID 文件: ./logs/*.pid"
    
    echo
    echo "🔧 管理命令:"
    echo "  - 查看日志: tail -f logs/server.log"
    echo "  - 停止服务: ./stop.sh"
    echo "  - 重启服务: ./restart.sh"
    
    echo
    echo "🧪 测试命令:"
    echo "  登录系统后运行以下命令验证硬件伪装:"
    echo "  - lscpu"
    echo "  - nproc"
    echo "  - htop"
    echo "  - free -h"
    echo "  - nvidia-smi"
    echo "  - neofetch"
}

# 创建日志目录
mkdir -p logs

# 主函数
main() {
    echo "🚀 Linux Analytics 无特权硬件伪装系统部署脚本"
    echo "=================================================="
    echo
    
    # 解析命令行参数
    FORCE_KILL=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                FORCE_KILL=true
                shift
                ;;
            -h|--help)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  -f, --force    强制终止占用端口的进程"
                echo "  -h, --help     显示帮助信息"
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                exit 1
                ;;
        esac
    done
    
    # 如果指定了强制参数，终止占用端口的进程
    if [ "$FORCE_KILL" = true ]; then
        log_warning "强制终止占用端口的进程..."
        pkill -f "node.*server.js" || true
        pkill -f "node.*webssh-server.js" || true
        pkill -f "cloudflared" || true
        sleep 2
    fi
    
    # 执行部署步骤
    check_requirements
    setup_docker_permissions
    install_dependencies
    compile_hardware_spoof
    build_docker_image
    setup_data_directory
    check_ports
    start_services
    start_cloudflare_tunnel
    
    if verify_deployment; then
        show_deployment_info
    else
        log_error "部署验证失败，请检查日志文件"
        exit 1
    fi
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"
