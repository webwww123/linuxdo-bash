#!/bin/bash

# Linux Analytics 服务重启脚本

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

# 主函数
main() {
    echo "🔄 重启 Linux Analytics 服务"
    echo "=============================="
    echo
    
    # 停止服务
    log_info "停止现有服务..."
    if [ -f "./stop-services.sh" ]; then
        ./stop-services.sh --containers
    else
        log_warning "stop-services.sh 不存在，使用简单停止方法..."
        pkill -f "node.*server.js" 2>/dev/null || true
        pkill -f "node.*webssh-server.js" 2>/dev/null || true
        pkill -f "cloudflared" 2>/dev/null || true
        docker ps --filter "name=linux-" --format "{{.ID}}" | xargs -r docker stop 2>/dev/null || true
        docker ps -a --filter "name=linux-" --format "{{.ID}}" | xargs -r docker rm 2>/dev/null || true
    fi
    
    echo
    log_info "等待服务完全停止..."
    sleep 3
    
    # 重新启动服务
    log_info "重新启动服务..."
    if [ -f "./deploy.sh" ]; then
        ./deploy.sh
    else
        log_error "deploy.sh 不存在，无法自动重启"
        log_info "请手动运行部署脚本"
        exit 1
    fi
}

# 运行主函数
main "$@"
