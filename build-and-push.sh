#!/bin/bash

# Linux Analytics Docker构建和推送脚本

set -e

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
    echo -e "${BLUE}[构建] ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}[构建] ${1}${NC}"
}

print_error() {
    echo -e "${RED}[构建] ${1}${NC}"
}

print_header() {
    echo
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  Linux Analytics Docker构建${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

# 配置变量
DOCKER_USERNAME="${DOCKER_USERNAME:-15162104132}"
IMAGE_NAME="${IMAGE_NAME:-grafana-analytics}"
VERSION="${VERSION:-latest}"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"

# 检查Docker
check_docker() {
    print_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker未运行"
        exit 1
    fi
    
    print_success "Docker环境检查通过"
}

# 检查登录状态
check_docker_login() {
    print_step "检查Docker Hub登录状态..."
    
    if ! docker info | grep -q "Username"; then
        print_message "请先登录Docker Hub:" $YELLOW
        print_message "docker login" $CYAN
        exit 1
    fi
    
    print_success "Docker Hub已登录"
}

# 构建镜像
build_image() {
    print_step "开始构建Docker镜像..."
    print_message "镜像名称: ${FULL_IMAGE_NAME}" $CYAN
    
    # 构建镜像
    docker build \
        --tag "${FULL_IMAGE_NAME}" \
        --tag "${DOCKER_USERNAME}/${IMAGE_NAME}:latest" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
        .
    
    print_success "镜像构建完成"
}

# 测试镜像
test_image() {
    print_step "测试镜像..."
    
    # 启动测试容器
    CONTAINER_ID=$(docker run -d \
        --name analytics-test \
        -p 13001:3001 \
        -p 13002:3002 \
        -p 18080:8080 \
        "${FULL_IMAGE_NAME}")
    
    print_message "测试容器ID: ${CONTAINER_ID}" $CYAN
    
    # 等待服务启动
    print_step "等待服务启动..."
    sleep 15
    
    # 检查健康状态
    if docker exec "${CONTAINER_ID}" curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
        print_success "健康检查通过"
    else
        print_error "健康检查失败"
        docker logs "${CONTAINER_ID}"
        docker rm -f "${CONTAINER_ID}"
        exit 1
    fi
    
    # 清理测试容器
    docker rm -f "${CONTAINER_ID}"
    print_success "镜像测试通过"
}

# 推送镜像
push_image() {
    print_step "推送镜像到Docker Hub..."
    
    # 推送版本标签
    docker push "${FULL_IMAGE_NAME}"
    
    # 推送latest标签
    if [ "${VERSION}" != "latest" ]; then
        docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
    fi
    
    print_success "镜像推送完成"
}

# 显示使用说明
show_usage() {
    echo
    print_message "🎉 构建和推送完成！" $GREEN
    echo
    print_message "📱 使用方法:" $CYAN
    echo
    print_message "1. 直接运行:" $BLUE
    echo "   docker run -d \\"
    echo "     --name grafana-analytics \\"
    echo "     --restart unless-stopped \\"
    echo "     -p 3001:3001 \\"
    echo "     -p 3002:3002 \\"
    echo "     -p 5173:5173 \\"
    echo "     -p 8080:8080 \\"
    echo "     -v /var/run/docker.sock:/var/run/docker.sock \\"
    echo "     -v analytics-data:/app/backend/data \\"
    echo "     ${FULL_IMAGE_NAME}"
    echo
    print_message "2. 使用docker-compose:" $BLUE
    echo "   在docker-compose.yml中使用: ${FULL_IMAGE_NAME}"
    echo
    print_message "📋 访问地址:" $CYAN
    print_message "   主应用: http://localhost:3001" $BLUE
    print_message "   WebSSH: http://localhost:3002" $BLUE
    print_message "   前端开发: http://localhost:5173" $BLUE
    print_message "   Grafana监控: http://localhost:8080" $BLUE
    echo
}

# 主函数
main() {
    print_header
    
    # 解析参数
    SKIP_TEST=false
    SKIP_PUSH=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-test)
                SKIP_TEST=true
                shift
                ;;
            --skip-push)
                SKIP_PUSH=true
                shift
                ;;
            --version)
                VERSION="$2"
                FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
                shift 2
                ;;
            --username)
                DOCKER_USERNAME="$2"
                FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
                shift 2
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --skip-test     跳过镜像测试"
                echo "  --skip-push     跳过推送到Docker Hub"
                echo "  --version TAG   指定版本标签 (默认: latest)"
                echo "  --username USER 指定Docker Hub用户名"
                echo "  --help, -h      显示帮助信息"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 执行构建流程
    check_docker
    
    if [ "$SKIP_PUSH" = false ]; then
        check_docker_login
    fi
    
    build_image
    
    if [ "$SKIP_TEST" = false ]; then
        test_image
    fi
    
    if [ "$SKIP_PUSH" = false ]; then
        push_image
    fi
    
    show_usage
}

main "$@"
