#!/bin/bash

# Linux Analytics 服务停止脚本（直接部署版本）

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

# 停止服务函数
stop_service() {
    local service_name=$1
    local pid_file=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "停止 $service_name (PID: $pid)..."
            kill "$pid"
            
            # 等待进程结束
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                log_warning "$service_name 未能正常停止，强制终止..."
                kill -9 "$pid"
            fi
            
            log_success "$service_name 已停止"
        else
            log_warning "$service_name 进程不存在 (PID: $pid)"
        fi
        rm -f "$pid_file"
    else
        log_warning "$service_name PID 文件不存在"
    fi
}

# 主函数
main() {
    echo "🛑 停止 Linux Analytics 服务"
    echo "=============================="
    echo
    
    # 创建日志目录（如果不存在）
    mkdir -p logs
    
    # 停止各个服务
    stop_service "主服务" "logs/server.pid"
    stop_service "WebSSH 服务" "logs/webssh.pid"
    stop_service "Cloudflare 隧道" "logs/cloudflare.pid"
    
    # 额外清理：通过进程名终止
    log_info "清理残留进程..."
    
    # 终止可能的残留进程
    pkill -f "node.*server.js" 2>/dev/null && log_info "终止残留的主服务进程" || true
    pkill -f "node.*webssh-server.js" 2>/dev/null && log_info "终止残留的 WebSSH 进程" || true
    pkill -f "cloudflared.*tunnel" 2>/dev/null && log_info "终止残留的 Cloudflare 隧道进程" || true
    
    # 停止相关容器（可选）
    if [ "$1" = "--containers" ] || [ "$1" = "-c" ]; then
        log_info "停止相关 Docker 容器..."
        docker ps --filter "ancestor=linux-ubuntu:latest" --format "{{.ID}}" | xargs -r docker stop 2>/dev/null || true
        docker ps -a --filter "name=linux-" --format "{{.ID}}" | xargs -r docker rm 2>/dev/null || true
        log_success "Docker 容器已停止"
    fi
    
    # 清理临时文件
    log_info "清理临时文件..."
    rm -f logs/tunnel_url.txt
    
    echo
    log_success "✅ 所有服务已停止"
    
    if [ "$1" != "--containers" ] && [ "$1" != "-c" ]; then
        echo
        log_info "💡 提示:"
        echo "  - 如需同时停止 Docker 容器，请使用: $0 --containers"
        echo "  - 重新启动服务: ./deploy.sh"
        echo "  - 查看日志: tail -f logs/*.log"
    fi
}

# 运行主函数
main "$@"
