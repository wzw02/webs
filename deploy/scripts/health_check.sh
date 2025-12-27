#!/bin/bash
# 健康检查脚本

set -e

DEPLOY_DIR="/opt/web-calculator"
LOG_FILE="$DEPLOY_DIR/health_check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_service() {
    local color=$1
    local port=$([ "$color" = "blue" ] && echo "8080" || echo "8081")

    log "检查 $color 服务 (端口: $port)..."

    # 检查容器是否运行
    if ! docker ps | grep -q "web-calculator-$color"; then
        log "❌ 容器 web-calculator-$color 未运行"
        return 1
    fi

    # 检查健康状态
    if docker ps | grep "web-calculator-$color" | grep -q "healthy"; then
        log "✅ 容器 web-calculator-$color 健康"
        return 0
    else
        log "⚠️  容器 web-calculator-$color 不健康"
        return 1
    fi
}

# 获取当前颜色
if [ -f "$DEPLOY_DIR/current_color" ]; then
    CURRENT_COLOR=$(cat "$DEPLOY_DIR/current_color")
    log "当前运行颜色: $CURRENT_COLOR"

    # 检查当前颜色服务
    if check_service "$CURRENT_COLOR"; then
        log "✅ 健康检查通过"
        exit 0
    else
        log "❌ 健康检查失败"
        exit 1
    fi
else
    log "⚠️  未找到当前颜色记录"
    exit 1
fi