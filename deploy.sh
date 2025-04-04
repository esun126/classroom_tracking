#!/bin/bash

# 学生课堂行为统计系统自动部署脚本
# 适用于阿里云ECS服务器（CentOS/Ubuntu）
# 使用前需要设置以下环境变量

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 配置信息 - 请在运行前设置这些值
DOMAIN_NAME="YOUR_DOMAIN" # 您的域名，如 example.com
ADMIN_EMAIL="YOUR_EMAIL" # 管理员邮箱，用于SSL证书
ALIYUN_ACCESS_KEY="YOUR_ALIYUN_ACCESS_KEY" # 阿里云AccessKey
ALIYUN_SECRET_KEY="YOUR_ALIYUN_SECRET_KEY" # 阿里云SecretKey
ALIYUN_REGION="cn-hangzhou" # 阿里云区域

# 系统检测
echo -e "${YELLOW}[INFO] 正在检测系统环境...${NC}"
if [ -f /etc/redhat-release ]; then
    # CentOS/RHEL系统
    OS_TYPE="centos"
    echo -e "${GREEN}[OK] 检测到CentOS/RHEL系统${NC}"
elif [ -f /etc/lsb-release ]; then
    # Ubuntu系统
    OS_TYPE="ubuntu"
    echo -e "${GREEN}[OK] 检测到Ubuntu系统${NC}"
else
    echo -e "${RED}[ERROR] 不支持的操作系统${NC}"
    exit 1
fi

# 检查必要变量
if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" = "YOUR_DOMAIN" ]; then
    echo -e "${RED}[ERROR] 请设置您的域名 (DOMAIN_NAME)${NC}"
    exit 1
fi

if [ -z "$ADMIN_EMAIL" ] || [ "$ADMIN_EMAIL" = "YOUR_EMAIL" ]; then
    echo -e "${RED}[ERROR] 请设置管理员邮箱 (ADMIN_EMAIL)${NC}"
    exit 1
fi

# 安装基础软件包
echo -e "${YELLOW}[INFO] 正在安装必要的软件包...${NC}"
if [ "$OS_TYPE" = "centos" ]; then
    # CentOS系统
    sudo yum update -y
    sudo yum install -y epel-release
    sudo yum install -y nginx certbot python3-certbot-nginx git nodejs npm
else
    # Ubuntu系统
    sudo apt update
    sudo apt install -y nginx certbot python3-certbot-nginx git nodejs npm
fi
echo -e "${GREEN}[OK] 基础软件包安装完成${NC}"

# 配置Nginx
echo -e "${YELLOW}[INFO] 正在配置Nginx...${NC}"
cat > /tmp/classroom-behavior-tracker.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
    
    root /var/www/classroom-behavior-tracker;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location ~ /.well-known {
        allow all;
    }
}
EOF

sudo mv /tmp/classroom-behavior-tracker.conf /etc/nginx/conf.d/
sudo mkdir -p /var/www/classroom-behavior-tracker
echo -e "${GREEN}[OK] Nginx配置完成${NC}"

# 创建应用程序目录
echo -e "${YELLOW}[INFO] 正在创建应用程序文件...${NC}"

# 下载index.html文件
echo -e "${YELLOW}[INFO] 正在从GitHub下载应用文件...${NC}"
curl -s https://raw.githubusercontent.com/esun126/teacher-tracking-sheet/main/index.html > /var/www/classroom-behavior-tracker/index.html

# 如果无法从GitHub下载，则使用本地创建的文件
if [ ! -s /var/www/classroom-behavior-tracker/index.html ]; then
    echo -e "${YELLOW}[INFO] 从GitHub下载失败，创建本地文件...${NC}"
    # 这里插入之前的index.html内容
    cat > /var/www/classroom-behavior-tracker/index.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<!-- 此处粘贴完整的index.html内容 -->
</html>
EOF
fi

echo -e "${GREEN}[OK] 应用程序文件创建完成${NC}"

# 设置文件权限
sudo chown -R nginx:nginx /var/www/classroom-behavior-tracker
sudo chmod -R 755 /var/www/classroom-behavior-tracker

# 配置HTTPS
echo -e "${YELLOW}[INFO] 正在配置HTTPS证书...${NC}"
sudo certbot --nginx -d ${DOMAIN_NAME} -d www.${DOMAIN_NAME} --non-interactive --agree-tos -m ${ADMIN_EMAIL}
echo -e "${GREEN}[OK] HTTPS配置完成${NC}"

# 启动Nginx
echo -e "${YELLOW}[INFO] 正在启动Nginx服务...${NC}"
sudo systemctl enable nginx
sudo systemctl restart nginx
echo -e "${GREEN}[OK] Nginx服务启动完成${NC}"

# 创建备份脚本
cat > /var/www/classroom-behavior-tracker/backup.sh << 'EOF'
#!/bin/bash

# 创建备份目录
BACKUP_DIR="/var/backups/classroom-behavior-tracker"
mkdir -p $BACKUP_DIR

# 备份文件名（使用日期）
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="$BACKUP_DIR/backup-$DATE.tar.gz"

# 压缩网站目录
tar -czf $BACKUP_FILE /var/www/classroom-behavior-tracker

# 保留最近30天的备份
find $BACKUP_DIR -name "backup-*.tar.gz" -mtime +30 -delete
EOF

sudo chmod +x /var/www/classroom-behavior-tracker/backup.sh

# 添加定时任务进行自动备份
echo "0 3 * * * /var/www/classroom-behavior-tracker/backup.sh" | sudo tee /etc/cron.d/classroom-backup

echo -e "${GREEN}[OK] 备份脚本配置完成${NC}"

# 安装完成信息
echo
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}      学生课堂行为统计系统安装完成!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo 
echo -e "${YELLOW}网站地址: https://${DOMAIN_NAME}${NC}"
echo
echo -e "${YELLOW}默认用户凭证:${NC}"
echo -e "${YELLOW}教师账号:${NC}"
echo -e "  语文老师: username=chinese_teacher, password=123456"
echo -e "  数学老师: username=math_teacher, password=123456"
echo -e "  英语老师: username=english_teacher, password=123456"
echo
echo -e "  管理员: username=admin, password=admin123"
echo
echo -e "${RED}警告: 请立即修改默认密码!${NC}"
echo -e "${GREEN}==================================================${NC}"
