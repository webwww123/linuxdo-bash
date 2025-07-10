#!/bin/bash

# 硬件伪装挂载脚本
echo "🔧 开始挂载伪造硬件信息..."

# 检查伪造文件是否存在
if [ ! -f /opt/fake_cpuinfo ]; then
    echo "❌ 错误: /opt/fake_cpuinfo 文件不存在"
    exit 1
fi

if [ ! -f /opt/fake_meminfo ]; then
    echo "❌ 错误: /opt/fake_meminfo 文件不存在"
    exit 1
fi

# 挂载伪造的 cpuinfo
echo "📋 挂载伪造的 CPU 信息..."
mount --bind /opt/fake_cpuinfo /proc/cpuinfo
if [ $? -eq 0 ]; then
    echo "✅ CPU 信息伪装成功"
else
    echo "❌ CPU 信息伪装失败"
fi

# 挂载伪造的 meminfo
echo "💾 挂载伪造的内存信息..."
mount --bind /opt/fake_meminfo /proc/meminfo
if [ $? -eq 0 ]; then
    echo "✅ 内存信息伪装成功"
else
    echo "❌ 内存信息伪装失败"
fi

echo "🎉 硬件伪装挂载完成！"

# 验证伪装效果
echo ""
echo "🔍 验证伪装效果："
echo "CPU 型号: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "CPU 核心数: $(grep -c '^processor' /proc/cpuinfo)"
echo "总内存: $(grep 'MemTotal' /proc/meminfo | awk '{print $2 " " $3}')"
echo ""
