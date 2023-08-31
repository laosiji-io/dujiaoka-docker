#!/bin/bash

SHELL_RUN_DIR="$(pwd)"
TOKEN_CONFIG="tokenpay.conf"

config() {
    # 如果当前目录存在 config.env
    if [ -f "${SHELL_RUN_DIR}/${TOKEN_CONFIG}" ]; then
        echo "${TOKEN_CONFIG} 配置文件已存在, 请直接编辑替换里面的参数."
        return 1
    fi

    cat <<EOF > ${SHELL_RUN_DIR}/${TOKEN_CONFIG}
# TokenPay 容器名称
CONTAINER_NAME="itokenpay"

# tokenpay 数据存放位置
TOKENPAY_DATA_DIR="/opt/docker-data/tokenpay"

# api token 用户对接
API_TOKEN="dsbUfQURQor4gqgFsFhdja67vP8Bir"

# 网站 url
WEBSITE_URL="https://tokenpay.laosiji.io"

# trongrid查询的 api key 
# 申请地址 https://www.trongrid.io/dashboard/keys
TRON_PRO_API_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# 收款地址 trx usdt-trc20 地址
TRON_ADDRESS="TTWAM8EKEnByPDiGJ2keS6Rk5g9vJ1NG7Y"

# 收款地址 eth 地址
EVM_ADDRESS="0x6133f3cDE38Ac541A92319bb5e65E0d666Dc3902"

# Telegram 用户 id 
# 获取方式 @EShopFakaBot 发送 /me 获取用户ID
TG_ADMIN_USER_ID=10000001

# Telegram 机器人 token 
# 获取方式 @BotFather 申请
TG_BOT_TOKEN="xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 归集功能, 建议先关闭, 后续再研究
COLLECTION_ENABLE="false"

# 容器映射用, 建议不要动
DB_SAVE_FILE="dbsave/TokenPay.db"
EOF
    echo "生成 ${TOKEN_CONFIG} 配置文件成功, 请先修改再执行安装.";
}

replaceConfig() {

    cp ${SHELL_RUN_DIR}/build/TokenPay/EVMChains.Example.json      ${TOKENPAY_DATA_DIR}/conf/EVMChains.json
    cp ${SHELL_RUN_DIR}/build/TokenPay/appsettings.Example.json    ${TOKENPAY_DATA_DIR}/conf/appsettings.json

    if [ "$(uname)" == "Linux" ]; then
        sed -i "s|\"TRON-PRO-API-KEY\": \"[a-zA-Z0-9\-]*\"|\"TRON-PRO-API-KEY\": \"${TRON_PRO_API_KEY}\"|g"         ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i "s|\"TRON\": \[ \"[a-zA-Z0-9\-]*\" \]|\"TRON\": \[ \"${TRON_ADDRESS}\" \]|g"                         ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i "s|\"EVM\": \[ \"[a-zA-Z0-9\-]*\" \]|\"EVM\": \[ \"${EVM_ADDRESS}\" \]|g"                            ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i "s|\"Enable\": [a-zA-Z0-9\-]*,|\"Enable\": ${COLLECTION_ENABLE},|g"                                  ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i "s|\"Address\": \"[a-zA-Z0-9\-]*\"|\"Address\": \"${TRON_ADDRESS}\"|g"                               ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i "s|\"AdminUserId\": [0-9]*,|\"AdminUserId\": ${TG_ADMIN_USER_ID},|g"                                 ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i "s|\"BotToken\": \"[a-zA-Z0-9\-\:]*\"|\"BotToken\": \"${TG_BOT_TOKEN}\"|g"                           ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        
        sed -i "s|\"WebSiteUrl\": \"http://token-pay.xxxxx.com\"|\"WebSiteUrl\": \"${WEBSITE_URL}\"|g"              ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i "s/\"ApiToken\": \"666666\"/\"ApiToken\": \"${API_TOKEN}\"/g"                                        ${TOKENPAY_DATA_DIR}/conf/appsettings.json         
        sed -i "s|DataDirectory\|TokenPay.db;|DataDirectory\|${DB_SAVE_FILE};|g"                                    ${TOKENPAY_DATA_DIR}/conf/appsettings.json
    fi

    if [ "$(uname)" == "Darwin" ]; then
        sed -i ".bak" "s|\"TRON-PRO-API-KEY\": \"[a-zA-Z0-9\-]*\"|\"TRON-PRO-API-KEY\": \"${TRON_PRO_API_KEY}\"|g"  ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i ".bak" "s|\"TRON\": \[ \"[a-zA-Z0-9\-]*\" \]|\"TRON\": \[ \"${TRON_ADDRESS}\" \]|g"                  ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i ".bak" "s|\"EVM\": \[ \"[a-zA-Z0-9\-]*\" \]|\"EVM\": \[ \"${EVM_ADDRESS}\" \]|g"                     ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i ".bak" "s|\"Enable\": [a-zA-Z0-9\-]*,|\"Enable\": ${COLLECTION_ENABLE},|g"                           ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i ".bak" "s|\"Address\": \"[a-zA-Z0-9\-]*\"|\"Address\": \"${TRON_ADDRESS}\"|g"                        ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i ".bak" "s|\"AdminUserId\": [0-9]*,|\"AdminUserId\": ${TG_ADMIN_USER_ID},|g"                          ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i ".bak" "s|\"BotToken\": \"[a-zA-Z0-9\-\:]*\"|\"BotToken\": \"${TG_BOT_TOKEN}\"|g"                    ${TOKENPAY_DATA_DIR}/conf/appsettings.json

        sed -i ".bak" "s|\"WebSiteUrl\": \"http://token-pay.xxxxx.com\"|\"WebSiteUrl\": \"${WEBSITE_URL}\"|g"       ${TOKENPAY_DATA_DIR}/conf/appsettings.json
        sed -i ".bak" "s/\"ApiToken\": \"666666\"/\"ApiToken\": \"${API_TOKEN}\"/g"                                 ${TOKENPAY_DATA_DIR}/conf/appsettings.json         
        sed -i ".bak" "s|DataDirectory\|TokenPay.db;|DataDirectory\|${DB_SAVE_FILE};|g"                             ${TOKENPAY_DATA_DIR}/conf/appsettings.json

        rm ${TOKENPAY_DATA_DIR}/conf/appsettings.json.bak
    fi

}

buildTokenPayImage() {

    # 如果是linux安装下可能未安装的
    if [ "$(uname)" == "Linux" ]; then
        apt-get update -qq >/dev/null
        apt-get install -y wget curl git >/dev/null
    fi

    # 下载 TokenPay 源代码
    cd ${SHELL_RUN_DIR}
    git clone https://github.com/LightCountry/TokenPay.git

    # 构建镜像
    rm -rf ${SHELL_RUN_DIR}/build
    mkdir -p ${SHELL_RUN_DIR}/build

    mv ${SHELL_RUN_DIR}/TokenPay/src/TokenPay   ${SHELL_RUN_DIR}/build/TokenPay
    mv ${SHELL_RUN_DIR}/TokenPay/src/Dockerfile ${SHELL_RUN_DIR}/build/Dockerfile
    rm -rf ${SHELL_RUN_DIR}/TokenPay

    cd ${SHELL_RUN_DIR}/build
    docker build -t localhost/tokenpay:latest .

}

stop() {

    if [ "$(docker ps -a | grep ${CONTAINER_NAME})" ]; then
        docker rm -f ${CONTAINER_NAME}
    fi
}

start() {

    stop

    docker run -d --name ${CONTAINER_NAME} \
    -v ${TOKENPAY_DATA_DIR}/conf/appsettings.json:/app/appsettings.json:ro \
    -v ${TOKENPAY_DATA_DIR}/conf/EVMChains.json:/app/EVMChains.json:ro \
    -v ${TOKENPAY_DATA_DIR}/data:/app/dbsave \
    -p 5052:80 \
    localhost/tokenpay:latest
}

install() {
    # tmp_dir $pwd

    if [ ! -f "${SHELL_RUN_DIR}/${TOKEN_CONFIG}" ]; then
        echo "${TOKEN_CONFIG} 配置文件 不存在, 请先创建修改后再执行安装."
        return 1
    fi

    source ${SHELL_RUN_DIR}/${TOKEN_CONFIG}

    if [ "$(uname)" == "Darwin" ]; then
          TOKENPAY_DATA_DIR="/tmp/docker-data/tokenpay"
    fi

    # 创建基本文件夹
    mkdir -p ${TOKENPAY_DATA_DIR}            # /opt/docker-data/tokenpay
    mkdir -p ${TOKENPAY_DATA_DIR}/data       # /opt/docker-data/tokenpay/data
    mkdir -p ${TOKENPAY_DATA_DIR}/conf       # /opt/docker-data/tokenpay/data

    cp ${SHELL_RUN_DIR}/${TOKEN_CONFIG} ${TOKENPAY_DATA_DIR}/conf/${TOKEN_CONFIG}

    CONFIG_FILE="${TOKENPAY_DATA_DIR}/conf/${TOKEN_CONFIG}"

    buildTokenPayImage

    replaceConfig

    start

}

case "$1" in
    config)
        config
        ;;
    install)
        install
        ;;
    start)
        start
        ;;
    *)
        echo "Usage: "
        echo ""
        echo "bash $0 { config | install | uninstall }"
        echo ""
        exit 1
esac
