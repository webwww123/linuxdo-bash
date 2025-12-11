#!/bin/bash
# =========================================================
# Linux Study Room - 容器网络安全脚本
# =========================================================
# 功能:
#   1. 创建隔离 Docker 网络 (禁止容器互通)
#   2. 设置防火墙规则 (iptables)
#   3. 封锁危险端口和隧道协议
#   4. 带宽限制 100KB/s
# =========================================================

set -e

NETWORK_NAME="lsr-isolated"
SUBNET="172.28.0.0/16"

echo "🔒 Linux Study Room 容器安全配置"
echo "=================================="

# ----------------------
# 1. 创建隔离 Docker 网络
# ----------------------
create_isolated_network() {
    echo ""
    echo "📡 创建隔离网络: $NETWORK_NAME"
    
    # 检查网络是否存在
    if docker network inspect "$NETWORK_NAME" &>/dev/null; then
        echo "   ✅ 网络已存在"
    else
        # 创建网络，禁止容器间通信 (--internal 禁止外网, 这里不用)
        # --opt com.docker.network.bridge.enable_icc=false 禁止容器互通
        docker network create \
            --driver bridge \
            --subnet "$SUBNET" \
            --opt com.docker.network.bridge.enable_icc=false \
            "$NETWORK_NAME"
        echo "   ✅ 网络创建成功"
    fi
}

# ----------------------
# 2. 设置防火墙规则
# ----------------------
setup_firewall() {
    echo ""
    echo "🛡️ 设置防火墙规则"
    
    # 清除旧的 DOCKER-USER 规则 (保留默认的 RETURN)
    echo "   清除旧规则..."
    iptables -F DOCKER-USER 2>/dev/null || true
    iptables -A DOCKER-USER -j RETURN

    # 允许已建立的连接
    echo "   允许已建立的连接..."
    iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # ----------------------
    # 封锁端口 (跳板/隧道)
    # ----------------------
    echo "   封锁危险端口..."
    
    # SSH 端口 (防止反向 SSH 隧道)
    iptables -I DOCKER-USER -p tcp --dport 22 -j DROP
    iptables -I DOCKER-USER -p tcp --sport 22 -j DROP
    
    # RDP 端口
    iptables -I DOCKER-USER -p tcp --dport 3389 -j DROP
    
    # 常见代理端口
    iptables -I DOCKER-USER -p tcp --dport 1080 -j DROP   # SOCKS5
    iptables -I DOCKER-USER -p tcp --dport 8080 -j DROP   # HTTP Proxy
    iptables -I DOCKER-USER -p tcp --dport 3128 -j DROP   # Squid
    iptables -I DOCKER-USER -p tcp --dport 8118 -j DROP   # Privoxy
    
    # VPN 端口
    iptables -I DOCKER-USER -p tcp --dport 1194 -j DROP   # OpenVPN
    iptables -I DOCKER-USER -p udp --dport 1194 -j DROP   # OpenVPN UDP
    iptables -I DOCKER-USER -p udp --dport 51820 -j DROP  # WireGuard
    iptables -I DOCKER-USER -p tcp --dport 1723 -j DROP   # PPTP
    
    # 隧道端口
    iptables -I DOCKER-USER -p tcp --dport 4443 -j DROP   # 常见隧道
    iptables -I DOCKER-USER -p tcp --dport 8443 -j DROP   # 替代 HTTPS
    
    # ngrok 和类似服务
    iptables -I DOCKER-USER -p tcp --dport 4040 -j DROP   # ngrok
    
    # Tor 网络
    iptables -I DOCKER-USER -p tcp --dport 9001 -j DROP   # Tor
    iptables -I DOCKER-USER -p tcp --dport 9050 -j DROP   # Tor SOCKS
    
    # ----------------------
    # 允许白名单端口
    # ----------------------
    echo "   设置白名单端口..."
    iptables -I DOCKER-USER -p tcp --dport 80 -j ACCEPT   # HTTP
    iptables -I DOCKER-USER -p tcp --dport 443 -j ACCEPT  # HTTPS
    iptables -I DOCKER-USER -p udp --dport 53 -j ACCEPT   # DNS
    iptables -I DOCKER-USER -p tcp --dport 53 -j ACCEPT   # DNS TCP
    
    # 允许 ICMP (ping)
    iptables -I DOCKER-USER -p icmp -j ACCEPT
    
    echo "   ✅ 防火墙规则设置完成"
}

# ----------------------
# 3. 带宽限制
# ----------------------
setup_bandwidth_limit() {
    echo ""
    echo "📊 设置带宽限制 (100KB/s = 800kbit/s)"
    
    # 获取 Docker 网桥接口
    BRIDGE_IF=$(docker network inspect "$NETWORK_NAME" -f '{{.Options}}' 2>/dev/null | grep -oP 'com.docker.network.bridge.name:\K[^}]+' || echo "br-$(docker network inspect $NETWORK_NAME -f '{{.Id}}' | cut -c1-12)")
    
    if [ -z "$BRIDGE_IF" ]; then
        echo "   ⚠️ 无法获取网桥接口，跳过带宽限制"
        return
    fi
    
    # 清除旧的 qdisc
    tc qdisc del dev "$BRIDGE_IF" root 2>/dev/null || true
    
    # 添加 tbf (Token Bucket Filter) 限速
    # rate: 800kbit = 100KB/s
    # burst: 突发允许 32KB
    # latency: 最大延迟 400ms
    tc qdisc add dev "$BRIDGE_IF" root tbf rate 800kbit burst 32kbit latency 400ms
    
    echo "   ✅ 带宽限制设置完成: $BRIDGE_IF"
}

# ----------------------
# 4. 保存规则
# ----------------------
save_rules() {
    echo ""
    echo "💾 保存规则..."
    
    # 尝试保存 iptables 规则
    if command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        iptables-save > /etc/iptables.rules 2>/dev/null || \
        echo "   ⚠️ 无法持久化 iptables 规则，重启后需重新运行此脚本"
    fi
    
    echo "   ✅ 完成"
}

# ----------------------
# 显示状态
# ----------------------
show_status() {
    echo ""
    echo "📋 当前状态"
    echo "============"
    echo ""
    echo "Docker 网络:"
    docker network ls | grep -E "(NETWORK|$NETWORK_NAME)"
    echo ""
    echo "DOCKER-USER 规则 (前 10 条):"
    iptables -L DOCKER-USER -n -v --line-numbers 2>/dev/null | head -15 || echo "   无法读取"
}

# ----------------------
# 主程序
# ----------------------
main() {
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        echo "❌ 请使用 root 权限运行此脚本"
        echo "   sudo $0"
        exit 1
    fi
    
    create_isolated_network
    setup_firewall
    setup_bandwidth_limit
    save_rules
    show_status
    
    echo ""
    echo "✅ 安全配置完成!"
    echo ""
    echo "📝 注意事项:"
    echo "   1. 容器需要使用网络: --network $NETWORK_NAME"
    echo "   2. 防火墙规则在重启后可能丢失，建议设置开机脚本"
    echo "   3. 带宽限制为 100KB/s"
}

main "$@"
