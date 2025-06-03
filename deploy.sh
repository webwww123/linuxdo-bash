#!/bin/bash

# LinuxDo自习室 - 一键部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置变量
DOCKER_IMAGE="${DOCKER_IMAGE:-your-dockerhub-username/linuxdo-webssh:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-linuxdo-webssh}"
API_PORT="${API_PORT:-3001}"
WEBSSH_PORT="${WEBSSH_PORT:-3002}"

print_message() {
    echo -e "${2}${1}${NC}"
}

print_step() {
    echo -e "${BLUE}[部署] ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}[部署] ${1}${NC}"
}

print_error() {
    echo -e "${RED}[部署] ${1}${NC}"
}

print_header() {
    echo
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  LinuxDo自习室 一键部署${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

# 检查Docker
check_docker() {
    print_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        echo "安装指南: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker未运行，请启动Docker服务"
        exit 1
    fi
    
    print_success "Docker环境检查通过"
}

# 检查端口
check_ports() {
    print_step "检查端口占用..."
    
    if netstat -tlnp 2>/dev/null | grep -q ":${API_PORT} "; then
        print_error "端口 ${API_PORT} 已被占用"
        exit 1
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":${WEBSSH_PORT} "; then
        print_error "端口 ${WEBSSH_PORT} 已被占用"
        exit 1
    fi
    
    print_success "端口检查通过"
}

# 清理旧容器
cleanup_old() {
    print_step "清理旧容器..."
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_message "发现旧容器，正在清理..." $YELLOW
        docker stop "${CONTAINER_NAME}" 2>/dev/null || true
        docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        print_success "旧容器已清理"
    else
        print_success "无需清理"
    fi
}

# 拉取镜像
pull_image() {
    print_step "拉取Docker镜像..."
    print_message "镜像: ${DOCKER_IMAGE}" $CYAN
    
    docker pull "${DOCKER_IMAGE}"
    print_success "镜像拉取完成"
}

# 部署容器
deploy_container() {
    print_step "部署容器..."
    
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        -p "${API_PORT}:3001" \
        -p "${WEBSSH_PORT}:3002" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v linuxdo-data:/app/backend/data \
        -v linuxdo-logs:/app/logs \
        "${DOCKER_IMAGE}"
    
    print_success "容器部署完成"
}

# 等待服务启动
wait_for_services() {
    print_step "等待服务启动..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:${API_PORT}/api/health" > /dev/null 2>&1; then
            print_success "服务启动成功"
            return 0
        fi
        
        print_message "等待服务启动... (${attempt}/${max_attempts})" $YELLOW
        sleep 2
        ((attempt++))
    done
    
    print_error "服务启动超时，请检查日志"
    docker logs "${CONTAINER_NAME}"
    exit 1
}

# 显示部署结果
show_result() {
    echo
    print_message "🎉 LinuxDo自习室部署成功！" $GREEN
    echo
    print_message "📱 访问地址:" $CYAN
    print_message "   主应用: http://localhost:${API_PORT}" $BLUE
    print_message "   WebSSH: http://localhost:${WEBSSH_PORT}" $BLUE
    echo
    print_message "🔧 管理命令:" $CYAN
    print_message "   查看日志: docker logs ${CONTAINER_NAME}" $BLUE
    print_message "   进入容器: docker exec -it ${CONTAINER_NAME} bash" $BLUE
    print_message "   重启服务: docker restart ${CONTAINER_NAME}" $BLUE
    print_message "   停止服务: docker stop ${CONTAINER_NAME}" $BLUE
    echo
    print_message "📋 功能特性:" $CYAN
    print_message "   🐳 一人一个独立容器" $BLUE
    print_message "   🛡️ 完全安全隔离" $BLUE
    print_message "   💻 现代化终端体验" $BLUE
    print_message "   💬 实时聊天功能" $BLUE
    echo
}

# 主函数
main() {
    print_header
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image)
                DOCKER_IMAGE="$2"
                shift 2
                ;;
            --name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            --api-port)
                API_PORT="$2"
                shift 2
                ;;
            --webssh-port)
                WEBSSH_PORT="$2"
                shift 2
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --image IMAGE       指定Docker镜像"
                echo "  --name NAME         指定容器名称"
                echo "  --api-port PORT     指定API端口 (默认: 3001)"
                echo "  --webssh-port PORT  指定WebSSH端口 (默认: 3002)"
                echo "  --help, -h          显示帮助信息"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 执行部署流程
    check_docker
    check_ports
    cleanup_old
    pull_image
    deploy_container
    wait_for_services
    show_result
}

main "$@"
