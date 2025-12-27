#!/bin/bash
# 回滚脚本

set -e

DEPLOY_DIR="/opt/web-calculator"

echo "开始回滚操作..."

# 获取当前活跃颜色
if [ -f "$DEPLOY_DIR/current_color" ]; then
    CURRENT_COLOR=$(cat $DEPLOY_DIR/current_color)
else
    CURRENT_COLOR="blue"
fi

# 确定回滚颜色
if [ "$CURRENT_COLOR" = "blue" ]; then
    ROLLBACK_COLOR="green"
    echo "当前活跃颜色: blue，回滚到: green"
else
    ROLLBACK_COLOR="blue"
    echo "当前活跃颜色: green，回滚到: blue"
fi

# 切换流量到回滚颜色
echo "切换流量到 $ROLLBACK_COLOR..."
$DEPLOY_DIR/scripts/switch_traffic $ROLLBACK_COLOR

# 停止有问题的版本
echo "停止当前版本容器 ($CURRENT_COLOR)..."
if [ "$CURRENT_COLOR" = "blue" ]; then
    docker-compose -f $DEPLOY_DIR/docker-compose.yml stop app_blue || true
else
    docker-compose -f $DEPLOY_DIR/docker-compose.yml stop app_green || true
fi

echo "✅ 回滚完成！系统已恢复到 $ROLLBACK_COLOR 版本"
echo "如果需要重新部署失败版本，请手动检查问题后重新运行部署脚本"