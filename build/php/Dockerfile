FROM php:7.4-fpm

RUN apt-get update -y

RUN apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev \
        cron \
        git \
        lsof \
        procps \
        net-tools

RUN pecl install -o -f redis && \
    rm -rf /tmp/pear && \
    docker-php-ext-enable redis

RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install -j$(nproc) gd
RUN docker-php-ext-install -j$(nproc) mysqli
RUN docker-php-ext-install -j$(nproc) pdo_mysql
RUN docker-php-ext-install -j$(nproc) bcmath
RUN docker-php-ext-install -j$(nproc) pcntl
RUN docker-php-ext-install -j$(nproc) zip

RUN rm -r /var/lib/apt/lists/*

COPY composer /usr/local/bin/composer
RUN chmod +x /usr/local/bin/composer

WORKDIR /workdir/websites/dujiaoka

CMD ["php-fpm", "-R"]
