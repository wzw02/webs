#!/bin/bash
# 蓝绿部署脚本 - root用户版本

set -e  # 遇到错误时退出

# 配置 - root用户不需要sudo
DEPLOY_DIR="/opt/web-calculator"
NGINX_CONF_DIR="$DEPLOY_DIR/nginx/conf.d"
BACKUP_DIR="$DEPLOY_DIR/backups"
LOG_FILE="$DEPLOY_DIR/deploy.log"

# 创建日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 参数检查
if [ $# -ne 2 ]; then
    log "❌ 错误: 需要2个参数"
    log "使用方法: $0 <image_tag> <color>"
    log "示例: $0 ghcr.io/wkk08/web-calculator-ci-cd:sha blue"
    exit 1
fi

IMAGE_TAG=$1
NEW_COLOR=$2

# 验证颜色参数
if [[ ! "$NEW_COLOR" =~ ^(blue|green)$ ]]; then
    log "❌ 错误: 颜色参数必须是 'blue' 或 'green'"
    exit 1
fi

log "========================================="
log "🚀 开始蓝绿部署 (root用户)"
log "镜像标签: $IMAGE_TAG"
log "新部署颜色: $NEW_COLOR"
log "部署目录: $DEPLOY_DIR"
log "========================================="

# 1. 检查当前颜色
if [ -f "$DEPLOY_DIR/current_color" ]; then
    CURRENT_COLOR=$(cat "$DEPLOY_DIR/current_color")
    log "当前运行颜色: $CURRENT_COLOR"

    if [ "$CURRENT_COLOR" = "$NEW_COLOR" ]; then
        log "⚠️ 警告: 新颜色与当前颜色相同，将覆盖部署"
        OLD_COLOR=$(if [ "$CURRENT_COLOR" = "blue" ]; then echo "green"; else echo "blue"; fi)
    else
        OLD_COLOR="$CURRENT_COLOR"
    fi
else
    log "首次部署，当前无运行颜色"
    CURRENT_COLOR="none"
    OLD_COLOR="none"
fi

# 2. 创建必要的目录（root用户有权限）
mkdir -p "$DEPLOY_DIR" "$NGINX_CONF_DIR" "$BACKUP_DIR"

# 3. 拉取新镜像
log "🔍 拉取新镜像: $IMAGE_TAG"
if ! docker pull "$IMAGE_TAG"; then
    log "❌ 错误: 无法拉取镜像 $IMAGE_TAG"
    exit 1
fi
log "✅ 镜像拉取成功"



# 4. 创建新的docker-compose配置
log "📝 生成docker-compose配置"
cat > "$DEPLOY_DIR/docker-compose-${NEW_COLOR}.yml" <<EOF
version: '3.8'
services:
  web-calculator-${NEW_COLOR}:
    image: ${IMAGE_TAG}
    container_name: web-calculator-${NEW_COLOR}
    restart: always
    ports:
      - "${NEW_COLOR == 'blue' ? '8080' : '8081'}:5000"
    environment:
      - APP_COLOR=${NEW_COLOR}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - web-calculator-net

  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - $NGINX_CONF_DIR:/etc/nginx/conf.d
      - $DEPLOY_DIR/nginx/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      web-calculator-${NEW_COLOR}:
        condition: service_healthy
    restart: always
    networks:
      - web-calculator-net

networks:
  web-calculator-net:
    driver: bridge
EOF
log "✅ 生成 docker-compose-${NEW_COLOR}.yml"

# 5. 创建nginx配置文件
log "📝 生成nginx配置文件"
cat > "$NGINX_CONF_DIR/web-calculator.conf" <<EOF
upstream web-calculator-backend {
    server web-calculator-${NEW_COLOR}:5000;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://web-calculator-backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    location /health {
        proxy_pass http://web-calculator-backend/health;
        access_log off;
    }

    location = /favicon.ico {
        access_log off;
        log_not_found off;
    }
}
EOF

# 6. 创建nginx主配置（如果需要）
if [ ! -f "$DEPLOY_DIR/nginx/nginx.conf" ]; then
    cat > "$DEPLOY_DIR/nginx/nginx.conf" <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss;

    include /etc/nginx/conf.d/*.conf;
}
EOF
fi

# 7. 停止并移除旧容器（如果存在且与新颜色不同）
if [ "$OLD_COLOR" != "none" ] && [ "$OLD_COLOR" != "$NEW_COLOR" ]; then
    log "🗑️  停止旧容器: web-calculator-$OLD_COLOR"
    docker stop "web-calculator-$OLD_COLOR" 2>/dev/null || true
    docker rm "web-calculator-$OLD_COLOR" 2>/dev/null || true

    # 备份旧配置
    if [ -f "$DEPLOY_DIR/docker-compose-${OLD_COLOR}.yml" ]; then
        cp "$DEPLOY_DIR/docker-compose-${OLD_COLOR}.yml" \
           "$BACKUP_DIR/docker-compose-${OLD_COLOR}-$(date +%Y%m%d_%H%M%S).yml"
    fi
fi

# 8. 启动新容器
log "🚀 启动新容器: web-calculator-$NEW_COLOR"
cd "$DEPLOY_DIR"
docker-compose -f "docker-compose-${NEW_COLOR}.yml" up -d

# 9. 等待健康检查
log "⏳ 等待容器健康检查..."
MAX_RETRIES=12
RETRY_COUNT=0
SERVICE_HEALTHY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker ps | grep "web-calculator-$NEW_COLOR" | grep -q "(healthy)"; then
        log "✅ 容器健康检查通过"
        SERVICE_HEALTHY=true
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    log "尝试 $RETRY_COUNT/$MAX_RETRIES: 容器尚未就绪，等待5秒..."
    sleep 5

    # 检查容器日志以防出错
    if docker logs "web-calculator-$NEW_COLOR" 2>&1 | tail -5 | grep -q "error\|Error\|ERROR\|failed"; then
        log "⚠️  容器日志中发现错误，停止部署"
        docker logs "web-calculator-$NEW_COLOR" | tail -20 >> "$LOG_FILE"
        break
    fi
done

if [ "$SERVICE_HEALTHY" = false ]; then
    log "❌ 错误: 容器健康检查失败"
    log "容器日志最后20行:"
    docker logs "web-calculator-$NEW_COLOR" 2>&1 | tail -20 >> "$LOG_FILE"
    docker logs "web-calculator-$NEW_COLOR" 2>&1 | tail -20

    # 回滚：如果之前有旧容器，尝试恢复
    if [ "$OLD_COLOR" != "none" ] && [ "$OLD_COLOR" != "$NEW_COLOR" ]; then
        log "🔄 尝试回滚到旧颜色: $OLD_COLOR"
        echo "$OLD_COLOR" > "$DEPLOY_DIR/current_color"
        docker-compose -f "docker-compose-${OLD_COLOR}.yml" up -d 2>/dev/null || true
    fi
    exit 1
fi

# 10. 更新当前颜色记录
echo "$NEW_COLOR" > "$DEPLOY_DIR/current_color"

# 11. 重启nginx以应用新配置
log "🔄 重启nginx代理"
docker restart nginx-proxy 2>/dev/null || true

# 12. 最终验证
log "🔍 最终验证..."
sleep 3

if curl -f -s -o /dev/null -w "%{http_code}" http://localhost/health | grep -q "200"; then
    log "🎉 部署成功！"
    log "当前运行颜色: $NEW_COLOR"
    log "服务URL: http://localhost"
    log "API健康检查: http://localhost/health"
    log "========================================="

    # 显示容器状态
    log "📊 当前容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "web-calculator|nginx"

    # 清理旧的备份文件（保留最近5个）
    ls -t "$BACKUP_DIR/"*.yml 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
else
    log "⚠️  警告: 最终健康检查失败，但容器已启动"
    log "请手动检查: curl http://localhost/health"
    exit 1
fi