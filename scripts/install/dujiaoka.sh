#!/bin/bash

RUN_DIR=$(pwd)
CONFIG_NAME="config.env"

CONTAINER_NAME_PHP="ka01php7"
MYSQL_DB_NAME="dujiaoka_db7"
DUJIAOKA_AUTHOR="assimon"

DIR_DOCKER=
DIR_DATA=

if [ "$(uname)" == "Darwin" ]; then
    echo "仅支持在 Linux 上安装" >&2
    exit 1
fi

if [ ! -f "${RUN_DIR}/${CONFIG_NAME}" ]; then
    echo "请先运行下面的命令生成并修改 config.env"
    echo "bash $0 config"
    exit 1
fi

createConfigEnv () {
    if [ -f "${RUN_DIR}/${CONFIG_NAME}" ]; then
        echo "config.env exists."
        exit 1
    fi

    cat <<EOF > ${RUN_DIR}/${CONFIG_NAME}
DIR_DOCKER_PARENT="/opt/docker-app"
DIR_DATA_PARENT="/opt/docker-data"

# 后台登录地址 建议修改
ADMIN_DIR="admin"

# 网站域名
DOMAIN="faka.domain.com"

# 数据库密码
MYSQL_PASSWORD="db123456"

# 是否开启https (前端开启了后端也必须为true)
# 后台登录出现0err或者其他登录异常问题，而网站并没有开启HTTPS，把下面的true改为false即可
HTTPS_ENABLE="true"

# PHP版本 不要随意更改
PHP_VERSION="7.4"

EOF
    echo "成功创建config.env 配置文件";

    # echoInfo

}


createNginxConf() {

    mkdir -p ${DIR_DOCKER}/conf/nginx/sites-enabled

    cat <<EOF > ${DIR_DOCKER}/conf/nginx/sites-enabled/01-default.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name localhost;

    index index.html;
    root /app/wwwroot/public;

}
EOF

    cat <<EOF > ${DIR_DOCKER}/conf/nginx/sites-enabled/02-${DOMAIN}.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    index index.php index.html;

    error_log  /app/logs/nginx/01_${DOMAIN}_error.log;
    access_log /app/logs/nginx/01_${DOMAIN}_access.log;

    root /app/src/dujiaoka/public;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass ${CONTAINER_NAME_PHP}:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOF

}

createPhpFpmConf() {
    mkdir -p ${DIR_DOCKER}/conf/php

    cat <<EOF > ${DIR_DOCKER}/conf/php/php-fpm.conf
[global]

error_log = /app/logs/php/fpm-error.log
daemonize = no

[www]

access.log = /app/logs/php/fpm-access.log
access.format = "%R - %u %t \"%m %r%Q%q\" %s %f %{mili}d %{kilo}M %C%%"

user = root
group = root

listen = [::]:9000

pm = dynamic
;pm = static
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 10
pm.max_spare_servers = 30

clear_env = no

rlimit_files = 1048576
EOF
}

createPhpDockerfile() {

    mkdir -p ${DIR_DOCKER}/build/php/${PHP_VERSION}

    cat <<EOF > ${DIR_DOCKER}/build/php/${PHP_VERSION}/Dockerfile
FROM php:${PHP_VERSION}-fpm

RUN apt-get update -y
RUN apt-get install -y libfreetype6-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev

RUN pecl install -o -f redis && docker-php-ext-enable redis && rm -rf /tmp/pear

RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install -j\$(nproc) gd
RUN docker-php-ext-install -j\$(nproc) mysqli
RUN docker-php-ext-install -j\$(nproc) pdo_mysql
RUN docker-php-ext-install -j\$(nproc) bcmath
RUN docker-php-ext-install -j\$(nproc) pcntl
RUN docker-php-ext-install -j\$(nproc) zip

RUN rm -r /var/lib/apt/lists/*

COPY composer /usr/local/bin/composer

WORKDIR /app/src/dujiaoka

CMD ["php-fpm", "-R"]

EOF
    wget https://getcomposer.org/download/2.5.8/composer.phar -O ${DIR_DOCKER}/build/php/${PHP_VERSION}/composer

}

createDockerComposeYml() {

           MYSQL_PORT_MAPPING="    ports:"
    MYSQL_PORT_MAPPING_DETAIL="      - 33062:3306"

    cat <<EOF > ${DIR_DOCKER}/docker-compose.yml
version: '3'
networks:
  dujiaoka:
services:

  ${CONTAINER_NAME_NGINX}:
    container_name: ${CONTAINER_NAME_NGINX}
    image: nginx:1.18
    restart: unless-stopped
    volumes:
      - ${DIR_DOCKER}/conf/nginx/sites-enabled:/etc/nginx/conf.d
      - ${DIR_DATA}/wwwroot:/app/wwwroot
      - ${DIR_DATA}/php/${DUJIAOKA_AUTHOR}:/app/src
      - ${DIR_DATA}/logs:/app/logs
    networks:
      - dujiaoka
    ports:
      - 8181:80
    depends_on:
      - ${CONTAINER_NAME_PHP}

  ${CONTAINER_NAME_PHP}:
    container_name: ${CONTAINER_NAME_PHP}
    build: ./build/php/${PHP_VERSION}
    restart: unless-stopped
    volumes:
      - ${DIR_DOCKER}/conf/php/php-fpm.conf:/usr/local/etc/php-fpm.conf
      - ${DIR_DATA}/php/${DUJIAOKA_AUTHOR}:/app/src
      - ${DIR_DATA}/logs:/app/logs
    networks:
      - dujiaoka
    depends_on:
      - ${CONTAINER_NAME_MYSQL}
      - ${CONTAINER_NAME_REDIS}
    environment:
      - TZ=Asia/Shanghai

  ${CONTAINER_NAME_MYSQL}:
    container_name: ${CONTAINER_NAME_MYSQL}
    image: mysql:5.7
    restart: unless-stopped
    command: ['mysqld', '--character-set-server=utf8mb4', '--collation-server=utf8mb4_unicode_ci']
    volumes:
      - ${DIR_DATA}/mysql/data:/var/lib/mysql/
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD}
    networks:
      - dujiaoka
${MYSQL_PORT_MAPPING}
${MYSQL_PORT_MAPPING_DETAIL}

  ${CONTAINER_NAME_REDIS}:
    container_name: ${CONTAINER_NAME_REDIS}
    image: redis:6.0.9
    restart: unless-stopped
    volumes:
      - ${DIR_DATA}/redis/data:/data
    networks:
      - dujiaoka

EOF

}


init() {

    if [ "$(uname)" == "Linux" ]; then
        sudo apt-get update -qq >/dev/null
        sudo apt-get install -y curl git supervisor > /dev/null
    fi

    CONTAINER_NAME_NGINX="ka01nginx"
    CONTAINER_NAME_PHP="ka01php7"
    CONTAINER_NAME_MYSQL="ka01mysql"
    CONTAINER_NAME_REDIS="ka01redis"

    DIR_DOCKER="${DIR_DOCKER_PARENT}/${DOMAIN}"
    DIR_DATA="${DIR_DATA_PARENT}/${DOMAIN}"

    case "${PHP_VERSION}" in
        "8.1")
            CONTAINER_NAME_PHP="ka01php8"
            MYSQL_DB_NAME="dujiaoka_db8"
            DUJIAOKA_AUTHOR="laosiji-io"
            ;;
        *)
            CONTAINER_NAME_PHP="ka01php7"
            MYSQL_DB_NAME="dujiaoka_db7"
            DUJIAOKA_AUTHOR="assimon"
    esac



}

createDir() {
    mkdir -p ${DIR_DOCKER}                  # /opt/docker-app/faka.domain.com
    mkdir -p ${DIR_DOCKER}/build            # /opt/docker-app/faka.domain.com/build
    mkdir -p ${DIR_DOCKER}/build/php        # /opt/docker-app/faka.domain.com/build/php
    mkdir -p ${DIR_DOCKER}/conf             # /opt/docker-app/faka.domain.com/conf
    mkdir -p ${DIR_DOCKER}/conf/php         # /opt/docker-app/faka.domain.com/conf/php
    mkdir -p ${DIR_DOCKER}/conf/nginx       # /opt/docker-app/faka.domain.com/conf/nginx


    mkdir -p ${DIR_DATA}                    # /opt/docker-data/faka.domain.com
    mkdir -p ${DIR_DATA}/php                # /opt/docker-data/faka.domain.com/php
    mkdir -p ${DIR_DATA}/mysql              # /opt/docker-data/faka.domain.com/mysql
    mkdir -p ${DIR_DATA}/redis              # /opt/docker-data/faka.domain.com/redis

    mkdir -p ${DIR_DATA}/logs               # /opt/docker-data/faka.domain.com/logs
    mkdir -p ${DIR_DATA}/logs/php           # /opt/docker-data/faka.domain.com/logs/php
    mkdir -p ${DIR_DATA}/logs/nginx         # /opt/docker-data/faka.domain.com/logs/nginx
    mkdir -p ${DIR_DATA}/logs/mysql         # /opt/docker-data/faka.domain.com/logs/mysql

    mkdir -p ${DIR_DATA}/wwwroot/public
    echo '<!DOCTYPE html><html><head><title>nginx</title></head><body>nginx</body></html>' > ${DIR_DATA}/wwwroot/public/index.html
}

createDujiaokaEnv() {

    DUJIAOKA_DIR=${DIR_DATA}/php/${DUJIAOKA_AUTHOR}/dujiaoka

    cat <<EOF > ${DUJIAOKA_DIR}/.env
APP_NAME=${DOMAIN}
APP_ENV=local
APP_KEY=base64:X4PfWleNWy2ROwj3qwuYpbpkZLhkZmB4jyAB+doRRBs=
APP_DEBUG=false
APP_URL=${DOMAIN}

LOG_CHANNEL=stack

# 数据库配置
DB_CONNECTION=mysql
DB_HOST=${CONTAINER_NAME_MYSQL}
DB_PORT=3306
DB_DATABASE=${MYSQL_DB_NAME}
DB_USERNAME=root
DB_PASSWORD=${MYSQL_PASSWORD}

# redis配置
REDIS_HOST=${CONTAINER_NAME_REDIS}
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

# 缓存配置
# file为磁盘文件  redis为内存级别
# redis为内存需要安装好redis服务端并配置
CACHE_DRIVER=redis

# 异步消息队列
# sync为同步  redis为异步
# 使用redis异步需要安装好redis服务端并配置
QUEUE_CONNECTION=redis

# 后台语言
## zh_CN 简体中文
## zh_TW 繁体中文
## en    英文
DUJIAO_ADMIN_LANGUAGE=zh_CN

# 后台登录地址
ADMIN_ROUTE_PREFIX=${ADMIN_DIR}

# 是否开启https (前端开启了后端也必须为true)
# 后台登录出现0err或者其他登录异常问题，而网站并没有开启HTTPS，把下面的true改为false即可
ADMIN_HTTPS=${HTTPS_ENABLE}

# 支付额外配置
WECHAT_API_SERVER=

EOF

}

# 下载代码
downloadDujiaoka() {

    # 如果 dujiaoka 源码不存在 则 下载
    if [ -d "${DIR_DATA}/php/${DUJIAOKA_AUTHOR}/dujiaoka" ]; then
        echo "dujiaoka exists."
    else
        echo "dujiaoka not exists. download....."

        mkdir -p ${DIR_DATA}/php/${DUJIAOKA_AUTHOR}

        cd ${DIR_DATA}/php/${DUJIAOKA_AUTHOR}

        git clone https://github.com/${DUJIAOKA_AUTHOR}/dujiaoka.git
    fi

}

dockerComposeUp() {
    cd ${DIR_DOCKER}
    docker-compose up -d --build
}

installDujiaokaDependence() {

    # composer install
    docker exec -it ${CONTAINER_NAME_PHP} php /usr/local/bin/composer install

    # generate APP_KEY
    docker exec -it ${CONTAINER_NAME_PHP} php artisan key:generate

}

createDujiaokaDatabase() {
    # 等待 mysql 容器运行
    until docker exec -i ${CONTAINER_NAME_MYSQL} mysql -uroot -p${MYSQL_PASSWORD} -e "SELECT 1;" &> /dev/null; do
        echo "MySQL container is not ready yet. Waiting..."
        sleep 1
    done

    SQL_CHECK_SCHEMA="SELECT * FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '${MYSQL_DB_NAME}';"

    db_exists=$(docker exec -i ${CONTAINER_NAME_MYSQL} mysql -uroot -p${MYSQL_PASSWORD} -e "${SQL_CHECK_SCHEMA}")

    if [ -z "$db_exists" ]; then
        echo "database not found. creating...."
        sleep 1
        SQL_CREATE="CREATE DATABASE ${MYSQL_DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        until docker exec -i ${CONTAINER_NAME_MYSQL} mysql -uroot -p${MYSQL_PASSWORD} -e "${SQL_CREATE}" &> /dev/null; do
            echo "${MYSQL_DB_NAME} is not ready create. Waiting..."
            sleep 1
        done

        echo ""
        echo "${MYSQL_DB_NAME} create success!"
        echo ""

    else
        echo "database exists!"
    fi
}

importDujiaokaSQL() {

    DUJIAOKA_DIR=${DIR_DATA}/php/${DUJIAOKA_AUTHOR}/dujiaoka

    # SQL_CHECK_TABLE="SELECT * FROM information_schema.TABLES WHERE TABLE_NAME = 'admin_menu';"
    SQL_CHECK_TABLE="USE ${MYSQL_DB_NAME};SHOW tables;"
    tables_exists=$(docker exec -i ${CONTAINER_NAME_MYSQL} mysql -uroot -p${MYSQL_PASSWORD} -e "${SQL_CHECK_TABLE}" | grep admin_menu)
    if [ -z "$tables_exists" ]; then
        echo "tables not found. import..."
        sleep 1
        DUJIAOKA_SQL="${DUJIAOKA_DIR}/database/sql/install.sql"
        until docker exec -i ${CONTAINER_NAME_MYSQL} mysql -uroot -p${MYSQL_PASSWORD} ${MYSQL_DB_NAME} < ${DUJIAOKA_SQL} &> /dev/null; do
            echo "sql data is not import yet. Waiting..."
            sleep 1
        done
        echo ""
        echo "sql import success!"
        echo ""

    else
        echo "tables exists!"
    fi

    echo "install ok" > ${DUJIAOKA_DIR}/install.lock
}

startLaravelWorker() {
    # 排除 Darwin
    if [ "$(uname)" == "Darwin" ]; then
        return 0
    fi

    cat <<EOF > /etc/supervisor/conf.d/dujiaoka.conf
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=docker exec ${CONTAINER_NAME_PHP} /usr/local/bin/php /app/src/dujiaoka/artisan queue:work
autostart=true
autorestart=true
user=root
numprocs=1
redirect_stderr=true
startsecs=3
stopasgroup=true
killasgroup=true
stdout_logfile=/var/log/laravel-worker-out.log
stderr_logfile=/var/log/laravel-worker-err.log
EOF
    # 重启 supervisor
    supervisorctl reread
    supervisorctl update
    supervisorctl start laravel-worker:*
    supervisorctl status
}

removeLaravelWorker() {
    # 排除 Darwin
    if [ "$(uname)" == "Darwin" ]; then
        return 0
    fi

    # supervisor 移除 dujiaoka 服务 并重启
    if [ -f "/etc/supervisor/conf.d/dujiaoka.conf" ]; then
        rm /etc/supervisor/conf.d/dujiaoka.conf
        supervisorctl reread
        supervisorctl update
        supervisorctl status
    fi

    # 查找 artisan 进程 并删除
    php_artisan_id=`ps -ef | grep artisan | grep -v grep | awk '{print $2}'`
    # 如果 a 不为空
    if [ ! -z "$php_artisan_id" ]; then
        # kill -9 a
        kill -9 $php_artisan_id
    fi
}

rmContainer() {

    docker stop ${CONTAINER_NAME_NGINX} && docker rm -f ${CONTAINER_NAME_NGINX}
    docker stop ${CONTAINER_NAME_PHP}   && docker rm -f ${CONTAINER_NAME_PHP}
    docker stop ${CONTAINER_NAME_MYSQL} && docker rm -f ${CONTAINER_NAME_MYSQL}
    docker stop ${CONTAINER_NAME_REDIS} && docker rm -f ${CONTAINER_NAME_REDIS}
    rm -rf ${DIR_DOCKER}

}

install() {

    source ${RUN_DIR}/${CONFIG_NAME}

    init

    rmContainer
    removeLaravelWorker

    createDir
    createNginxConf
    createPhpFpmConf
    createPhpDockerfile
    createDockerComposeYml

    # 上面基本环境没啥问题
    downloadDujiaoka
    createDujiaokaEnv

    dockerComposeUp
    installDujiaokaDependence

    createDujiaokaDatabase
    importDujiaokaSQL
    startLaravelWorker

}



# 根据参数执行函数
case "$1" in
    config)
        createConfigEnv
        ;;
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        echo "Usage: "
        echo ""
        echo "bash $0 { config | install | uninstall }"
        echo ""
        exit 1
esac
