#!/bin/bash

# Linux Analytics - 临时存储区设置脚本
# 适用于Codespace环境，将容器数据配置到临时存储区

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_step() {
    echo -e "${BLUE}[步骤]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

# 检查环境
check_environment() {
    print_step "检查Codespace环境..."
    
    # 检查是否在Codespace中
    if [ -z "$CODESPACE_NAME" ]; then
        print_warning "未检测到Codespace环境变量，但继续执行"
    else
        print_success "检测到Codespace环境: $CODESPACE_NAME"
    fi
    
    # 检查临时存储区
    if [ -d "/tmp" ]; then
        local tmp_size=$(df -h /tmp | awk 'NR==2 {print $2}')
        local tmp_used=$(df -h /tmp | awk 'NR==2 {print $5}')
        print_success "临时存储区可用: ${tmp_size} (已使用: ${tmp_used})"
    else
        print_error "临时存储区不可用"
        exit 1
    fi
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        print_success "Docker已安装"
    else
        print_error "Docker未安装"
        exit 1
    fi
}

# 创建临时存储目录结构
setup_temp_directories() {
    print_step "设置临时存储目录结构..."
    
    # 创建容器数据目录
    sudo mkdir -p /tmp/containers
    sudo mkdir -p /tmp/docker-data
    sudo mkdir -p /tmp/app-data
    sudo mkdir -p /tmp/app-logs
    
    # 设置权限
    sudo chmod 755 /tmp/containers
    sudo chmod 755 /tmp/docker-data
    sudo chmod 755 /tmp/app-data
    sudo chmod 755 /tmp/app-logs
    
    # 设置所有者
    sudo chown -R $USER:$USER /tmp/containers
    sudo chown -R $USER:$USER /tmp/app-data
    sudo chown -R $USER:$USER /tmp/app-logs
    
    print_success "临时存储目录结构已创建"
}

# 配置Docker使用临时存储
configure_docker_temp_storage() {
    print_step "配置Docker使用临时存储..."
    
    # 创建Docker配置目录
    sudo mkdir -p /etc/docker
    
    # 备份原有配置
    if [ -f "/etc/docker/daemon.json" ]; then
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
        print_info "已备份原有Docker配置"
    fi
    
    # 创建新的Docker配置
    cat << EOF | sudo tee /etc/docker/daemon.json
{
  "data-root": "/tmp/docker-data",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-runtime": "runc",
  "runtimes": {
    "runc": {
      "path": "runc"
    }
  }
}
EOF
    
    print_success "Docker配置已更新为使用临时存储"
}

# 更新应用配置
update_app_config() {
    print_step "更新应用配置使用临时存储..."
    
    # 创建符号链接将应用数据指向临时存储
    if [ -d "backend/data" ]; then
        mv backend/data backend/data.backup 2>/dev/null || true
    fi
    ln -sf /tmp/app-data backend/data
    
    if [ -d "logs" ]; then
        mv logs logs.backup 2>/dev/null || true
    fi
    ln -sf /tmp/app-logs logs
    
    print_success "应用配置已更新"
}

# 显示存储信息
show_storage_info() {
    print_step "显示存储配置信息..."
    
    echo ""
    print_info "=== 存储配置概览 ==="
    echo ""
    
    # 显示各分区使用情况
    echo "磁盘使用情况:"
    df -h | grep -E "(Filesystem|/tmp|/workspaces|overlay)"
    
    echo ""
    echo "临时存储目录:"
    ls -la /tmp/ | grep -E "(containers|docker-data|app-data|app-logs)"
    
    echo ""
    echo "应用数据链接:"
    ls -la backend/data logs 2>/dev/null || echo "应用数据目录尚未创建"
    
    echo ""
    print_info "=== 配置说明 ==="
    echo "• 用户容器数据: /tmp/containers/"
    echo "• Docker数据: /tmp/docker-data/"
    echo "• 应用数据: /tmp/app-data/"
    echo "• 应用日志: /tmp/app-logs/"
    echo "• 临时存储总容量: $(df -h /tmp | awk 'NR==2 {print $2}')"
    echo "• 临时存储已使用: $(df -h /tmp | awk 'NR==2 {print $5}')"
    
    echo ""
    print_warning "注意: 临时存储在系统重启后会丢失所有数据"
    print_info "这适合Codespace这种临时开发环境"
}

# 重启Docker服务
restart_docker() {
    print_step "重启Docker服务以应用新配置..."
    
    # 在Codespace中，Docker通常作为服务运行
    if sudo systemctl is-active --quiet docker; then
        sudo systemctl restart docker
        sleep 5
        
        if sudo systemctl is-active --quiet docker; then
            print_success "Docker服务重启成功"
        else
            print_error "Docker服务重启失败"
            exit 1
        fi
    else
        print_warning "Docker服务未运行或无法通过systemctl管理"
        print_info "请手动重启Docker服务"
    fi
}

# 验证配置
verify_setup() {
    print_step "验证临时存储配置..."
    
    # 检查Docker数据目录
    if docker info | grep -q "/tmp/docker-data"; then
        print_success "Docker已配置使用临时存储"
    else
        print_warning "Docker可能未使用临时存储，请检查配置"
    fi
    
    # 检查目录权限
    if [ -w "/tmp/containers" ]; then
        print_success "容器目录可写"
    else
        print_error "容器目录不可写"
    fi
    
    # 测试创建容器目录
    test_dir="/tmp/containers/test-$(date +%s)"
    if mkdir -p "$test_dir" && rmdir "$test_dir"; then
        print_success "临时存储功能正常"
    else
        print_error "临时存储功能异常"
    fi
}

# 主函数
main() {
    echo ""
    print_info "=== Linux Analytics 临时存储配置 ==="
    print_info "适用于Codespace环境的容器数据临时存储配置"
    echo ""
    
    check_environment
    setup_temp_directories
    configure_docker_temp_storage
    update_app_config
    
    # 询问是否重启Docker
    echo ""
    read -p "是否重启Docker服务以应用配置? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_docker
    else
        print_warning "请手动重启Docker服务: sudo systemctl restart docker"
    fi
    
    verify_setup
    show_storage_info
    
    echo ""
    print_success "临时存储配置完成！"
    print_info "现在可以启动应用，所有容器数据将存储在临时区"
    echo ""
}

# 执行主函数
main "$@"
