> 独角数卡(自动售货系统)是一款采用业界流行的laravel框架，安全及稳定性提升。开源站长自动化售货解决方案、高效、稳定、快速！为了方便大家轻松的完成搭建，写了一个基于docker-compose的环境搭建脚本。

## 1. cloudfare 绑定域名

- 假设 主站域名为     www.domain.com
- 假设 epusdt域名    pay.domain.com
- 假设 服务器ip      127.0.0.1
- 绑定两个 A 记录 同时点亮小云朵

## 2. 申请个 telegram 机器人

- 根据下面的对话框获得 机器人token
- 1000000000:AAHy18129aHDH9jasd912Hd912jja8nxHEE

```textile

@我的命令
  /start

@BotFather回复
  I can help you create and manage Telegram bots.

@我的命令
  /newbot

@BotFather回复
  Alright, a new bot. How are we going to call it? 
  Please choose a name for your bot.

@我的命令
  jxaha发卡

@BotFather回复
  Good. Now let's choose a username for your bot. It must end in `bot`. 
  Like this, for example: TetrisBot or tetris_bot.

@me
  jxahaFakaBot

@BotFather回复

  1000000000:AAHy18129aHDH9jasd912Hd912jja8nxHEE

```

## 3. 获取你的telegram user id

> @qunid_bot 获取自己的 user id (一串数字)

## 4. 下载 安装脚本
```shell
mkdir /root/install-dujiaoka
cd /root/install-dujiaoka
wget https://raw.githubusercontent.com/laosiji-io/dujiaoka-docker/master/install.sh
```

## 5. 生成配置文件
```shell
bash install.sh config
```

> 会在当前目录生成一个 config.env 的配置文件

```shell

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

```

### 6. 修改配置文件 config.env

> 主要修改下面的几个地方

```shell
- DUJIAOKA_DOMAIN="www.domain.com"
- DUJIANKA_ADMIN="admin"
- EPUSDT_DOMAIN="pay.domain.com"
- TG_BOT_TOKEN="上面第2步获取的telegram机器人token"
- TG_USER_ID="上面第3步获取的telegram用户id(非机器人id)"
- EPUSDT_API_AUTH_TOKEN="自己随机一段字符串"
```

> 这里我是在 https://1password.com/password-generator/ 随机生成的32位


## epusdt 支付后台设置

```textfile
商户id填写:
  上面配置的 EPUSDT_API_AUTH_TOKEN="uhtK1KgCdqpvMoQ0aLj3P7b179Mu846t" 的值

商户密钥填写:
  https://这里替换成设置的pay域名/api/v1/order/create-transaction
```

