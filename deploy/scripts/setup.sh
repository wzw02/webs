#!/bin/bash
# 环境初始化脚本

set -e

DEPLOY_DIR="/opt/web-calculator"

echo "开始初始化部署环境..."

# 1. 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "安装Docker..."
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# 2. 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "安装Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# 3. 创建部署目录
echo "创建部署目录: $DEPLOY_DIR"
sudo mkdir -p $DEPLOY_DIR
sudo mkdir -p $DEPLOY_DIR/nginx/conf.d

# 4. 设置目录权限
echo "设置目录权限..."
sudo chown -R $USER:$USER $DEPLOY_DIR
chmod +x $DEPLOY_DIR/scripts/*

# 5. 创建环境文件
if [ ! -f "$DEPLOY_DIR/.env" ]; then
    echo "创建环境文件..."
    cat > $DEPLOY_DIR/.env << EOF
# 蓝绿部署环境变量
BLUE_TAG=ghcr.io/user/repo:latest
GREEN_TAG=ghcr.io/user/repo:latest

# 网络设置
NETWORK_NAME=webcalc_network
EOF
    echo "⚠️ 请更新 $DEPLOY_DIR/.env 文件中的镜像标签"
fi

# 6. 创建初始nginx配置
if [ ! -f "$DEPLOY_DIR/nginx/conf.d/default.conf" ]; then
    echo "创建nginx配置..."
    mkdir -p $DEPLOY_DIR/nginx/conf.d
    cat > $DEPLOY_DIR/nginx/conf.d/default.conf << EOF
upstream webcalc_upstream {
    server app_blue:5000 max_fails=1 fail_timeout=5s;
    # server app_green:5001 max_fails=1 fail_timeout=5s backup;
}

server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://webcalc_upstream;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    location /health {
        proxy_pass http://webcalc_upstream/health;
        access_log off;
    }
}
EOF
fi

echo "✅ 环境初始化完成！"
echo ""
echo "下一步操作："
echo "1. 编辑 $DEPLOY_DIR/.env 文件，设置正确的镜像标签"
echo "2. 运行部署脚本: ./scripts/deploy <image_tag> <color>"
echo "3. 切换流量: ./scripts/switch_traffic <color>"