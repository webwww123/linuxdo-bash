#!/bin/bash

# Linux Analytics - 停止服务脚本
# 三合一架构 - Docker Compose 部署

set -e

echo "🛑 停止 Linux Analytics 三合一平台..."
echo ""

# 检查是否有运行的服务
if ! docker compose ps --services --filter "status=running" | grep -q .; then
    echo "ℹ️  没有运行中的服务"
    exit 0
fi

# 显示当前运行的服务
echo "📊 当前运行的服务："
docker compose ps

echo ""
echo "🔄 停止所有服务..."
docker compose down

echo ""
echo "✅ 所有服务已停止"
echo ""
echo "📝 其他管理命令："
echo "   启动服务:     ./start.sh"
echo "   查看日志:     docker compose logs"
echo "   完全清理:     docker compose down -v"
echo ""
