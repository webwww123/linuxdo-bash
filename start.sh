#!/bin/bash

# Linux Analytics - 快速启动脚本
# 三合一架构 - Docker Compose 部署

set -e

echo "🚀 启动 Linux Analytics 三合一平台..."
echo ""

# 检查Docker是否运行
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker"
    exit 1
fi

# 检查Docker Compose是否可用
if ! command -v docker compose >/dev/null 2>&1; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

echo "✅ Docker 环境检查通过"
echo ""

# 构建并启动所有服务
echo "🔨 构建并启动所有服务..."
docker compose up --build -d

echo ""
echo "⏳ 等待服务启动..."
sleep 5

# 检查服务状态
echo ""
echo "📊 服务状态："
docker compose ps

echo ""
echo "🎉 启动完成！"
echo ""
echo "📱 访问地址："
echo "   主应用:     http://localhost:8080"
echo "   监控面板:   http://localhost:8080/grafana"
echo "   WebSSH:     http://localhost:8080/webssh"
echo ""
echo "📝 管理命令："
echo "   查看日志:   docker compose logs -f"
echo "   停止服务:   docker compose down"
echo "   重启服务:   docker compose restart"
echo ""
