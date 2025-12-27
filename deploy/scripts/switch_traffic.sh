#!/bin/bash
# 手动流量切换脚本

set -e

DEPLOY_DIR="/opt/web-calculator"

if [ $# -ne 1 ]; then
    echo "使用方法: $0 <color>"
    echo "示例: $0 green"
    exit 1
fi

TARGET_COLOR=$1

if [[ ! "$TARGET_COLOR" =~ ^(blue|green)$ ]]; then
    echo "错误: 颜色必须是 'blue' 或 'green'"
    exit 1
fi

# 更新nginx配置
sed -i "s/server web-calculator-\(blue\|green\):5000;/server web-calculator-${TARGET_COLOR}:5000;/" \
    "$DEPLOY_DIR/nginx/conf.d/web-calculator.conf"

# 重启nginx
docker restart nginx-proxy

# 更新当前颜色
echo "$TARGET_COLOR" > "$DEPLOY_DIR/current_color"

echo "✅ 流量已切换到 $TARGET_COLOR 服务"