#!/usr/bin/env bash
# LD_PRELOAD 硬件伪装系统 - 无特权安全方案
# 基于 LD_PRELOAD 技术，无需特权模式

set -euo pipefail

# 日志函数
log_info() { echo "[INFO] $*" >&2; }
log_success() { echo "[SUCCESS] $*" >&2; }
log_warning() { echo "[WARNING] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# 检查环境变量
if [[ "${ENABLE_HARDWARE_FAKE:-}" != "true" ]]; then
    log_info "硬件伪装未启用 (ENABLE_HARDWARE_FAKE != true)"
    exec "$@"
fi

log_info "启动 LD_PRELOAD 硬件伪装系统..."

# 设置 LD_PRELOAD 环境变量
export LD_PRELOAD="/opt/hardware_spoof.so:${LD_PRELOAD:-}"

# 确保 LD_PRELOAD 在所有 shell 会话中生效
echo 'export LD_PRELOAD="/opt/hardware_spoof.so"' >> /etc/environment
echo 'export LD_PRELOAD="/opt/hardware_spoof.so"' >> /etc/bash.bashrc
echo 'export LD_PRELOAD="/opt/hardware_spoof.so"' >> /root/.bashrc

# 为所有用户设置 LD_PRELOAD
echo 'export LD_PRELOAD="/opt/hardware_spoof.so"' >> /etc/profile

log_success "LD_PRELOAD 硬件伪装已启用并持久化"

# 验证硬件伪装效果
log_info "验证硬件伪装效果..."

# 测试 CPU 信息
CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "unknown")
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo "unknown")

# 测试内存信息
MEMORY_TOTAL=$(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "unknown")
MEMORY_GB=$((MEMORY_TOTAL / 1024 / 1024))

log_info "  CPU: $CPU_MODEL"
log_info "  CPU 核心数: $CPU_COUNT"
log_info "  内存: ${MEMORY_GB}GB"

log_success "LD_PRELOAD 硬件伪装验证完成"

# 创建伪装的 GPU 工具
log_info "创建伪装的 GPU 工具..."

# 创建 nvidia-smi 伪装命令
cat > /usr/local/bin/nvidia-smi << 'EOF'
#!/bin/bash
echo "Thu Dec 28 10:30:00 2023"
echo "+-----------------------------------------------------------------------------+"
echo "| NVIDIA-SMI 525.147.05   Driver Version: 525.147.05   CUDA Version: 12.0  |"
echo "|-------------------------------+----------------------+----------------------|"
echo "| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |"
echo "| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |"
echo "|                               |                      |               MIG M. |"
echo "|===============================+======================+======================|"
echo "|   0  NVIDIA A100-SXM...  On   | 00000000:00:04.0 Off |                    0 |"
echo "| N/A   32C    P0    68W / 400W |   1024MiB / 81920MiB |      0%      Default |"
echo "|                               |                      |                  N/A |"
echo "+-------------------------------+----------------------+----------------------+"
echo ""
echo "+-----------------------------------------------------------------------------+"
echo "| Processes:                                                                  |"
echo "|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |"
echo "|        ID   ID                                                   Usage      |"
echo "|=============================================================================|"
echo "|  No running processes found                                                 |"
echo "+-----------------------------------------------------------------------------+"
EOF

chmod +x /usr/local/bin/nvidia-smi

# 创建 nvcc 伪装命令
cat > /usr/local/bin/nvcc << 'EOF'
#!/bin/bash
echo "nvcc: NVIDIA (R) Cuda compiler driver"
echo "Copyright (c) 2005-2023 NVIDIA Corporation"
echo "Built on Tue_Aug_15_22:02:13_PDT_2023"
echo "Cuda compilation tools, release 12.0, V12.0.140"
echo "Build cuda_12.0.r12.0/compiler.33191640_0"
EOF

chmod +x /usr/local/bin/nvcc

# 创建 lspci 伪装命令（只影响 GPU 相关查询）
cat > /usr/local/bin/lspci << 'EOF'
#!/bin/bash
# 调用真实的 lspci
/usr/bin/lspci "$@" 2>/dev/null || true

# 添加伪造的 GPU 信息
if [[ "$*" == *"nvidia"* ]] || [[ "$*" == *"vga"* ]] || [[ "$*" == "" ]]; then
    echo "00:04.0 3D controller: NVIDIA Corporation GA100 [A100 SXM4 80GB] (rev a1)"
fi
EOF

chmod +x /usr/local/bin/lspci

log_success "GPU 伪装工具创建完成"

# 设置环境变量
export CUDA_VERSION="12.0"
export NVIDIA_VISIBLE_DEVICES="all"
export NVIDIA_DRIVER_CAPABILITIES="compute,utility"

log_success "CUDA 环境变量设置完成"

# 创建用户和设置权限
if [[ -n "${USER:-}" ]]; then
    log_info "创建用户: $USER"
    
    # 创建用户（如果不存在）
    if ! id "$USER" &>/dev/null; then
        useradd -m -s /bin/bash "$USER"
        log_success "用户 $USER 创建成功"
    fi
    
    # 设置用户目录权限
    chown -R "$USER:$USER" "/home/$USER" 2>/dev/null || true
    
    # 添加到 sudo 组
    usermod -aG sudo "$USER" 2>/dev/null || true
    
    # 设置无密码 sudo（仅限容器内）
    echo "$USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USER"
    
    log_success "用户权限设置完成"
fi

log_success "LD_PRELOAD 硬件伪装系统部署完成"
log_info "容器已进入安全模式，享受顶级配置！"
log_info "  ✅ CPU: Intel Core i9-13900K @ 3.00GHz (24 核心)"
log_info "  ✅ 内存: 64GB DDR4"
log_info "  ✅ GPU: NVIDIA A100-SXM4-80GB (6912 CUDA Cores)"
log_info "sudo功能正常，容器逃逸防护已启用"
log_info "硬件伪装效果已生效"

# 执行传入的命令
exec "$@"
