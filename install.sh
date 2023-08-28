#!/bin/bash

# 创建 config.env
createConfigEnv() {

    if [ -f "$(pwd)/config.env" ]; then
        echo "config.env exists." >&2
        return 1
    fi

    cat <<EOF > $(pwd)/config.env
SITE_DIR="dujiaoka" # 站点目录 会替换 nginx 中的 SITE_DIR_REPLACE

# 安装父级目录
# /opt/dujiaoka/dujiaoka-docker
DUJIAOKA_PARENT_DIR="/opt/dujiaoka"

# app name
DUJIAOKA_APP_NAME="发卡小站"
DUJIAOKA_DOMAIN="faka.domain.com"
DUJIANKA_ADMIN="admin"

# 数据库相关参数
# 数据库名 字母需要小写, 避免未知问题
MYSQL_PASSWORD="d123b456"
DB_NAME_DUJIAOKA="dujiaoka_db"
DB_NAME_EPUSDT="epusdt_db"

# 是否使用 ssl 证书
# 证书路径
ENABLE_SSL=false
SSL_CER_PATH="/tmp/ssl/domain.cer"
SSL_KEY_PATH="/tmp/ssl/domain.key"

# epusdt 相关配置
EPUSDT_DOMAIN_SCHEME="https"
EPUSDT_DOMAIN="pay.domain.com"
EPUSDT_API_AUTH_TOKEN="uhtK1KgCdqpvMoQ0aLj3P7b179Mu846t"

TG_BOT_TOKEN="1000000000:AAHy18129aHDH9jasd912Hd912jja8nxHEE"
TG_USER_ID="30251245412"
# epusdt 相关配置
EOF

    echo "config.env create success."

}

echoConfigInfo() {

    echo "################################################################################"

    echo "网站的域名:        ${DUJIAOKA_DOMAIN}"
    echo "网站的后台:        ${DUJIAOKA_DOMAIN}/${DUJIANKA_ADMIN}"
    echo "数据库密码:        ${MYSQL_PASSWORD}"
    echo "数据库名称:        ${DB_NAME_DUJIAOKA}"
    echo "epusdt的支付域名:  ${EPUSDT_DOMAIN}"
    echo "epusdt的商家id:    ${EPUSDT_API_AUTH_TOKEN}"
    echo "epusdt的商家密钥:  https://${EPUSDT_DOMAIN}/api/v1/order/create-transaction"

    echo "Telegram UserId:      ${TG_USER_ID}"
    echo "Telegram BotToken:    ${TG_BOT_TOKEN}"

    echo "################################################################################"

}

beforeDo() {

    source $(pwd)/config.env

    echoConfigInfo

    # 本地测试
    if [ "$(uname)" == "Darwin" ]; then
        source config.demo.env
    fi

    # /opt/dujiaoka
    # /tmp/dujiaoka
    if [ "$(uname)" == "Darwin" ]; then
        DUJIAOKA_PARENT_DIR="/tmp/djk/dujiaoka"
    fi

    # dir
    DUJIAOKA_DOCKER_DIR="${DUJIAOKA_PARENT_DIR}/dujiaoka-docker"
    DUJIAOKA_SITE_DIR="${DUJIAOKA_DOCKER_DIR}/workdir/websites/dujiaoka"

    # nginx conf
    DUJIAOKA_NGINX_CONF="${DUJIAOKA_DOCKER_DIR}/conf/nginx/sites-enabled/01-${DUJIAOKA_DOMAIN}.conf"
    EPUSDT_NGINX_CONF="${DUJIAOKA_DOCKER_DIR}/conf/nginx/sites-enabled/02-${EPUSDT_DOMAIN}.conf"

    # dujiaoka env
    DUJIAOKA_ENV="${DUJIAOKA_DOCKER_DIR}/conf/dujiaoka/.env"

    # epusdt
    EPUSDT_CONF="${DUJIAOKA_DOCKER_DIR}/conf/epusdt/.env"
}

# 移除容器函数
rmDockerContainer() {
    if [ "$(docker ps -a | grep djk01_nginx)" ]; then
        docker rm -f djk01_nginx
    fi
    if [ "$(docker ps -a | grep djk01_php)" ]; then
        docker rm -f djk01_php
    fi
    if [ "$(docker ps -a | grep djk01_mysql)" ]; then
        docker rm -f djk01_mysql
    fi
    if [ "$(docker ps -a | grep djk01_redis_dujiaoka)" ]; then
        docker rm -f djk01_redis_dujiaoka
    fi
    if [ "$(docker ps -a | grep djk01_redis_epusdt)" ]; then
        docker rm -f djk01_redis_epusdt
    fi
    if [ "$(docker ps -a | grep djk01_epusdt)" ]; then
        docker rm -f djk01_epusdt
    fi
}

# 启动 laravel worker 函数
startLaravelWorker() {
    cat <<EOF > /etc/supervisor/conf.d/dujiaoka.conf
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=docker exec djk01_php /usr/local/bin/php /workdir/websites/dujiaoka/artisan queue:work
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

# 移除 supervisor 的 laravel worker 服务
rmLaravelWorker() {
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

    # ps -ef | grep artisan | grep -v grep | awk '{print $2}' | xargs kill -9
}

check() {
    if [ "$(uname)" == "Linux" ]; then
        # 本脚本暂时只支持 ubuntu 和 debian
        if [ ! -x "$(command -v apt-get)" ]; then
            echo 'only support ubuntu and debian' >&2
            exit 1
        fi

        # 如果 docker 不存在, 退出脚本
        if [ ! -x "$(command -v docker)" ]; then
            echo 'Error: docker is not installed.' >&2
            exit 1
        fi

        # 如果 docker-compose 不存在, 退出脚本
        if [ ! -x "$(command -v docker-compose)" ]; then
            echo 'Error: docker-compose is not installed.' >&2
            exit 1
        fi

        echo "apt-get docker docker-compose check ok. continue after 3s..."
        sleep 3
        apt-get update
        apt-get install -y curl git supervisor

    fi
}

init() {

    beforeDo

    rmDockerContainer
    rmLaravelWorker

    # 如果不存在 ${DUJIAOKA_PARENT_DIR} 目录, 创建
    if [ ! -d "${DUJIAOKA_PARENT_DIR}" ]; then
        mkdir -p ${DUJIAOKA_PARENT_DIR}
    fi

    # 如果存在 ${DUJIAOKA_DOCKER_DIR} 目录, 删除
    if [ -d "${DUJIAOKA_DOCKER_DIR}" ]; then
        rm -rf ${DUJIAOKA_DOCKER_DIR}
    fi

}

downloadDujiaokaDocker() {
    # 下载 dujiaoka-docker
    cd ${DUJIAOKA_PARENT_DIR}
    git clone https://github.com/laosiji-io/dujiaoka-docker.git

}

copyConfig() {

    # 复制配置文件
    cp ${DUJIAOKA_DOCKER_DIR}/conf/nginx/00-default.conf    ${DUJIAOKA_DOCKER_DIR}/conf/nginx/sites-enabled/00-default.conf
    cp ${DUJIAOKA_DOCKER_DIR}/conf/nginx/01-dujiaoka.conf   ${DUJIAOKA_NGINX_CONF}
    cp ${DUJIAOKA_DOCKER_DIR}/conf/nginx/02-epusdt.conf     ${EPUSDT_NGINX_CONF}

    cp ${DUJIAOKA_DOCKER_DIR}/conf/dujiaoka/dujiaoka.env    ${DUJIAOKA_ENV}
    cp ${DUJIAOKA_DOCKER_DIR}/conf/epusdt/epusdt.env        ${EPUSDT_CONF}

    cp  ${DUJIAOKA_DOCKER_DIR}/docker-compose.demo.yml      ${DUJIAOKA_DOCKER_DIR}/docker-compose.yml

    # create_database.sql
    # CREATE DATABASE `DB_NAME_DUJIAOKA_REPLACE` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    # CREATE DATABASE `DB_NAME_EPUSDT_REPLACE` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    MYSQL_BUILD_SQL="${DUJIAOKA_DOCKER_DIR}/build/mysql/sql/create_database.sql"
    echo "CREATE DATABASE ${DB_NAME_DUJIAOKA} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"  > ${MYSQL_BUILD_SQL}
    echo "CREATE DATABASE ${DB_NAME_EPUSDT}   DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >> ${MYSQL_BUILD_SQL}

}

replaceNginxConfDujiaoka() {
    LISTEN_PORT_REPLACE=80
    SSL_CER_REPLACE=""
    SSL_KEY_REPLACE=""

    # 如果 ENABLE_SSL 为 true 判断 SSL_CER_PATH SSL_KEY_PATH 文件是否存在
    if [ $ENABLE_SSL = true ]; then
        if [ ! -f $SSL_CER_PATH ]; then
            echo "$SSL_CER_PATH not exists" >&2
            exit 1
        fi
        if [ ! -f $SSL_KEY_PATH ]; then
            echo "$SSL_KEY_PATH not exists" >&2
            exit 1
        fi

        echo "ssl exists. enabled 443 and ssl."

        mkdir -p ${DUJIAOKA_DOCKER_DIR}/workdir/ssl/${DUJIAOKA_DOMAIN}

        cp ${SSL_CER_PATH}  ${DUJIAOKA_DOCKER_DIR}/workdir/ssl/${DUJIAOKA_DOMAIN}/ssl.cer
        cp ${SSL_KEY_PATH}  ${DUJIAOKA_DOCKER_DIR}/workdir/ssl/${DUJIAOKA_DOMAIN}/ssl.key

        LISTEN_PORT_REPLACE="443 ssl"
        SSL_CER_REPLACE="ssl_certificate     /workdir/ssl/${DUJIAOKA_DOMAIN}/ssl.cer;"
        SSL_KEY_REPLACE="ssl_certificate_key /workdir/ssl/${DUJIAOKA_DOMAIN}/ssl.key;"

        echo ""                                             >> ${DUJIAOKA_NGINX_CONF}
        echo "server {"                                     >> ${DUJIAOKA_NGINX_CONF}
        echo "    listen 80;"                               >> ${DUJIAOKA_NGINX_CONF}
        echo "    listen [::]:80;"                          >> ${DUJIAOKA_NGINX_CONF}
        echo ""                                             >> ${DUJIAOKA_NGINX_CONF}
        echo "    server_name ${DUJIAOKA_DOMAIN};"          >> ${DUJIAOKA_NGINX_CONF}
        echo "    return 301 https://\$host\$request_uri;"  >> ${DUJIAOKA_NGINX_CONF}
        echo "}"                                            >> ${DUJIAOKA_NGINX_CONF}
    else
        echo "ssl does not exist. enabled 80."
    fi

    if [ "$(uname)" == "Darwin" ]; then
        sed -i ".bak" "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      ${DUJIAOKA_NGINX_CONF}
        sed -i ".bak" "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      ${DUJIAOKA_NGINX_CONF}
        sed -i ".bak" "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  ${DUJIAOKA_NGINX_CONF}
        sed -i ".bak" "s|DOMAIN_REPLACE|${DUJIAOKA_DOMAIN}|g"               ${DUJIAOKA_NGINX_CONF}
        sed -i ".bak" "s|SITE_DIR_REPLACE|${SITE_DIR}|g"                    ${DUJIAOKA_NGINX_CONF}

        rm -rf ${DUJIAOKA_NGINX_CONF}.bak

    else
        sed -i        "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      ${DUJIAOKA_NGINX_CONF}
        sed -i        "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      ${DUJIAOKA_NGINX_CONF}
        sed -i        "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  ${DUJIAOKA_NGINX_CONF}
        sed -i        "s|DOMAIN_REPLACE|${DUJIAOKA_DOMAIN}|g"               ${DUJIAOKA_NGINX_CONF}
        sed -i        "s|SITE_DIR_REPLACE|${SITE_DIR}|g"                    ${DUJIAOKA_NGINX_CONF}

    fi
}

replaceNginxConfEpusdt() {
    # EPUSDT_NGINX_CONF
    if [ "$(uname)" == "Darwin" ]; then
        sed -i ".bak" "s|EPUSDT_DOMAIN_REPLACE|${EPUSDT_DOMAIN}|g"        ${EPUSDT_NGINX_CONF}

        rm -rf ${EPUSDT_NGINX_CONF}.bak
    else
        sed -i        "s|EPUSDT_DOMAIN_REPLACE|${EPUSDT_DOMAIN}|g"        ${EPUSDT_NGINX_CONF}
    fi
    # EPUSDT_NGINX_CONF
}

replaceDockerComposeYml() {
    if [ "$(uname)" == "Darwin" ]; then

        # mac本地测试 使用 8081 4431
        sed -i ".bak" "s|80:80|8081:80|g"       ${DUJIAOKA_DOCKER_DIR}/docker-compose.yml
        sed -i ".bak" "s|443:443|4431:443|g"    ${DUJIAOKA_DOCKER_DIR}/docker-compose.yml

        sed -i ".bak" "s|MYSQL_PASSWORD_REPLACE|${MYSQL_PASSWORD}|g"     ${DUJIAOKA_DOCKER_DIR}/docker-compose.yml

        rm -rf ${DUJIAOKA_DOCKER_DIR}/docker-compose.yml.bak
    else
        sed -i        "s|MYSQL_PASSWORD_REPLACE|${MYSQL_PASSWORD}|g"     ${DUJIAOKA_DOCKER_DIR}/docker-compose.yml
    fi
}

replaceEnvDujiaokaConf() {

    if [ "$(uname)" == "Darwin" ]; then
        sed -i ".bak" "s|DUJIAOKA_APP_NAME_REPLACE|${DUJIAOKA_APP_NAME}|g"      ${DUJIAOKA_ENV}
        sed -i ".bak" "s|DUJIAOKA_DOMAIN_REPLACE|${DUJIAOKA_DOMAIN}|g"          ${DUJIAOKA_ENV}
        sed -i ".bak" "s|DB_NAME_DUJIAOKA_REPLACE|${DB_NAME_DUJIAOKA}|g"        ${DUJIAOKA_ENV}
        sed -i ".bak" "s|MYSQL_PASSWORD_REPLACE|${MYSQL_PASSWORD}|g"            ${DUJIAOKA_ENV}
        sed -i ".bak" "s|DUJIANKA_ADMIN_REPLACE|${DUJIANKA_ADMIN}|g"            ${DUJIAOKA_ENV}

        rm -rf ${DUJIAOKA_ENV}.bak
    else
        sed -i        "s|DUJIAOKA_APP_NAME_REPLACE|${DUJIAOKA_APP_NAME}|g"      ${DUJIAOKA_ENV}
        sed -i        "s|DUJIAOKA_DOMAIN_REPLACE|${DUJIAOKA_DOMAIN}|g"          ${DUJIAOKA_ENV}
        sed -i        "s|DB_NAME_DUJIAOKA_REPLACE|${DB_NAME_DUJIAOKA}|g"        ${DUJIAOKA_ENV}
        sed -i        "s|MYSQL_PASSWORD_REPLACE|${MYSQL_PASSWORD}|g"            ${DUJIAOKA_ENV}
        sed -i        "s|DUJIANKA_ADMIN_REPLACE|${DUJIANKA_ADMIN}|g"            ${DUJIAOKA_ENV}
    fi

}

replaceEnvEpusdtConf() {

    if [ "$(uname)" == "Darwin" ]; then
        sed -i ".bak" "s|EPUSDT_DOMAIN_REPLACE|${EPUSDT_DOMAIN}|g"                      ${EPUSDT_CONF}
        sed -i ".bak" "s|EPUSDT_DOMAIN_SCHEME_REPLACE|${EPUSDT_DOMAIN_SCHEME}|g"        ${EPUSDT_CONF}
        sed -i ".bak" "s|MYSQL_PASSWORD_REPLACE|${MYSQL_PASSWORD}|g"                    ${EPUSDT_CONF}
        sed -i ".bak" "s|DB_NAME_EPUSDT_REPLACE|${DB_NAME_EPUSDT}|g"                    ${EPUSDT_CONF}

        sed -i ".bak" "s|TG_BOT_TOKEN_REPLACE|${TG_BOT_TOKEN}|g"                        ${EPUSDT_CONF}
        sed -i ".bak" "s|TG_USER_ID_REPLACE|${TG_USER_ID}|g"                            ${EPUSDT_CONF}

        sed -i ".bak" "s|EPUSDT_API_AUTH_TOKEN_REPLACE|${EPUSDT_API_AUTH_TOKEN}|g"      ${EPUSDT_CONF}


        rm -rf ${EPUSDT_CONF}.bak
    else
        sed -i        "s|EPUSDT_DOMAIN_REPLACE|${EPUSDT_DOMAIN}|g"                      ${EPUSDT_CONF}
        sed -i        "s|EPUSDT_DOMAIN_SCHEME_REPLACE|${EPUSDT_DOMAIN_SCHEME}|g"        ${EPUSDT_CONF}
        sed -i        "s|MYSQL_PASSWORD_REPLACE|${MYSQL_PASSWORD}|g"                    ${EPUSDT_CONF}
        sed -i        "s|DB_NAME_EPUSDT_REPLACE|${DB_NAME_EPUSDT}|g"                    ${EPUSDT_CONF}


        sed -i        "s|TG_BOT_TOKEN_REPLACE|${TG_BOT_TOKEN}|g"                        ${EPUSDT_CONF}
        sed -i        "s|TG_USER_ID_REPLACE|${TG_USER_ID}|g"                            ${EPUSDT_CONF}

        sed -i        "s|EPUSDT_API_AUTH_TOKEN_REPLACE|${EPUSDT_API_AUTH_TOKEN}|g"      ${EPUSDT_CONF}
    fi

}

cloneDujiaokaCode() {
    # dujiaoka app
    cd ${DUJIAOKA_DOCKER_DIR}/workdir/websites

    # mkdir -p ${DUJIAOKA_DOCKER_DIR}/workdir/websites/dujiaoka
    git clone https://github.com/assimon/dujiaoka.git
    sleep 1

    rm -rf $DUJIAOKA_SITE_DIR/.env
    cp ${DUJIAOKA_ENV} ${DUJIAOKA_SITE_DIR}/.env
    # dujiaoka app
}

dockerComposeUp() {
    # docker-compose up
    cd ${DUJIAOKA_DOCKER_DIR}
    docker-compose up -d --build
    # 等待 MySQL 容器启动
    echo "Waiting for MySQL container to start..."
    sleep 3
    # until docker exec -i djk01_mysql mysqladmin ping --silent &> /dev/null; do
    until docker exec -i djk01_mysql mysql -uroot -p${MYSQL_PASSWORD} -e "SELECT 1;" &> /dev/null; do
        echo "MySQL container is not ready yet. Waiting..."
        sleep 1
    done
    # docker-compose up

    echo "create mysql success. continue after 3s..."
    sleep 3
}

installData() {
    # 安装依赖
    docker exec -it djk01_php /usr/local/bin/composer install

    # generate APP_KEY
    docker exec -it djk01_php php artisan key:generate

    echo 'install ok' > ${DUJIAOKA_SITE_DIR}/install.lock

    # docker exec djk01_mysql 导入  ${DUJIAOKA_SITE_DIR}/database/sql/install.sql
    docker exec -i djk01_mysql mysql -uroot -p${MYSQL_PASSWORD} ${DB_NAME_DUJIAOKA} < ${DUJIAOKA_SITE_DIR}/database/sql/install.sql

    curl https://raw.githubusercontent.com/assimon/epusdt/master/sql/v0.0.1.sql > ${DUJIAOKA_DOCKER_DIR}/epusdt_import.sql

    docker exec -i djk01_mysql mysql -uroot -p${MYSQL_PASSWORD} ${DB_NAME_EPUSDT} < ${DUJIAOKA_DOCKER_DIR}/epusdt_import.sql

    rm ${DUJIAOKA_DOCKER_DIR}/epusdt_import.sql
}

install() {
    check
    init
    downloadDujiaokaDocker
    copyConfig
    replaceNginxConfDujiaoka
    replaceNginxConfEpusdt
    replaceDockerComposeYml
    replaceEnvDujiaokaConf
    replaceEnvEpusdtConf
    cloneDujiaokaCode
    dockerComposeUp
    installData

    # 如果是 mac 安装就到此结束
    if [ "$(uname)" == "Darwin" ]; then
        echo "install success."
        exit 0
    fi

    rmLaravelWorker
    startLaravelWorker

    echo "install success."
}

uninstall() {
    rmDockerContainer

    if [ "$(uname)" == "Linux" ]; then
        rmLaravelWorker
    fi
    echo "uninstall success."
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

exit 0
