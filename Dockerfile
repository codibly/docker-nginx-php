FROM php:8.3.1-fpm

MAINTAINER Codibly <office@codibly.com>

WORKDIR /opt/app/

ENV USER_LOGIN    www-data
ENV USER_HOME_DIR /home/$USER_LOGIN
ENV APP_DIR       /opt/app

############ PHP-FPM ############

# CREATE WWW-DATA HOME DIRECTORY
RUN set -x \
    && mkdir /home/www-data \
    && chown -R www-data:www-data /home/www-data \
    && usermod -u 1000 --shell /bin/bash -d /home/www-data www-data \
    && groupmod -g 1000 www-data

# INSTALL ESSENTIALS LIBS TO COMPILE PHP EXTENSTIONS
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
        # for zip ext
        zlib1g-dev libzip-dev\
        # for pg_pgsql ext
        libpq-dev \
        # for soap and xml related ext
        libxml2-dev \
        # for xslt ext
        libxslt-dev \
        # for gd ext
        libjpeg-dev libpng-dev \
        # for intl ext
        libicu-dev openssl \
        # for mbstring ext
        libonig-dev \
        # openssl
        libssl-dev \
        # htop for resource monitoring
        htop \
        # for pkill
        procps \
        vim iputils-ping curl \
        # for controlling system processes
        supervisor \
        cron \
        gettext-base \
        # for merging PDF docs
        ghostscript \
        # for docs generator (mkdocs)
        python3-pip \
        python3-setuptools \
        && pip install mkdocs --break-system-packages

# INSTALL PHP EXTENSIONS VIA docker-php-ext-install SCRIPT
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/install-php-extensions
RUN install-php-extensions \
  bcmath \
  calendar \
  ctype \
  dba \
  dom \
  exif \
  fileinfo \
  ftp \
  gettext \
  gd \
  iconv \
  intl \
  mbstring \
  opcache \
  pcntl \
  pdo \
  pdo_mysql \
  posix \
  session \
  simplexml \
  soap \
  sockets \
  xsl \
  zip

COPY scripts/xoff.sh /usr/bin/xoff
COPY scripts/xon.sh /usr/bin/xon

# INSTALL XDEBUG
RUN set -x \
    && pecl install xdebug-3.3.1 \
    && bash -c 'echo -e "\n[xdebug]\nzend_extension=xdebug.so\nxdebug.mode=debug\nxdebug.start_with_request=yes\nxdebug.client_port=9003\nxdebug.client_host=" >> /usr/local/etc/php/conf.d/xdebug.ini' \
    # add global functions to turn xdebug on/off
    && chmod +x /usr/bin/xoff \
    && chmod +x /usr/bin/xon \
    # turn off xdebug by default
    && mv /usr/local/etc/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/xdebug.off  \
    && echo 'PS1="[\$(test -e /usr/local/etc/php/conf.d/xdebug.off && echo XOFF || echo XON)] $HC$FYEL[ $FBLE${debian_chroot:+($debian_chroot)}\u$FYEL: $FBLE\w $FYEL]\\$ $RS"' | tee /etc/bash.bashrc /etc/skel/.bashrc

# INSTALL COMPOSER
ENV COMPOSER_HOME /usr/local/composer
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN set -x \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/bin --filename=composer \
    && rm composer-setup.php \
    && bash -c 'echo -e "{ \"config\" : { \"bin-dir\" : \"/usr/local/bin\" } }\n" > /usr/local/composer/composer.json' \
    && echo "export COMPOSER_HOME=/usr/local/composer" >> /etc/bash.bashrc

############ NGINX ############

## INSTALL NGINX (based on the official nginx image)
RUN set -x \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 gnupg2 ca-certificates debian-archive-keyring \
  && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
  && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian bookworm nginx" | tee /etc/apt/sources.list.d/nginx.list \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y nginx \
  && apt-get clean \
  && apt-get autoremove \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && sed -i "s/^user .*/user www-data;/" /etc/nginx/nginx.conf

# install dockerize - useful tool to check if other sevices are ready to use (eg. db, queue)
RUN set -x \
    && DOCKERIZE_VERSION=v0.7.0; \
       curl https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz -L --output dockerize.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize.tar.gz \
    && rm dockerize.tar.gz

############# CONFIGURE ############
#  TWEAK PHP CONFIG
RUN set -x \
    && mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini \
    && rm /usr/local/etc/php-fpm.d/* \
    && sed -i "s|;error_log = log/php-fpm.log|error_log = /proc/self/fd/2|" /usr/local/etc/php-fpm.conf \
    && sed -i "s|memory_limit.*|memory_limit = 8192M|" $PHP_INI_DIR/php.ini \
    && sed -i "s|max_execution_time.*|max_execution_time = 3000|" $PHP_INI_DIR/php.ini \
    && sed -i "s|upload_max_filesize.*|upload_max_filesize = 32M|" $PHP_INI_DIR/php.ini \
    && sed -i "s|post_max_size.*|post_max_size = 48M|" $PHP_INI_DIR/php.ini \
    && sed -i "s|;date.timezone = *|date.timezone = UTC|" $PHP_INI_DIR/php.ini \
    && cp $PHP_INI_DIR/php.ini $PHP_INI_DIR/php-cli.ini

# COPY HTTP POOL CONFIGURATION
COPY conf.d/php-fpm-www.conf /usr/local/etc/php-fpm.d/www.conf

# COPY HTTP SERVER CONFIGURATION
COPY conf.d/nginx-default.conf /etc/nginx/conf.d/default.conf

# COPY SUPERVISOR INFRASTRUCTURE CONFIGURATION
COPY conf.d/supervisor-infrastracture.conf /etc/supervisor/conf.d/infrastructure.conf

RUN set -x \
   && bash -c 'echo "alias sf=bin/console" >> ~/.bashrc'

EXPOSE 8080

STOPSIGNAL SIGTERM

COPY healthcheck.sh /healthcheck.sh
HEALTHCHECK CMD (/healthcheck.sh nginx && /healthcheck.sh php_fpm) || exit 1

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
