#!/usr/bin/env bash

function isServiceAvailable() {
    all_services="$(service --status-all 2> >(log))"
    if [[ ${all_services} =~ ${1} ]]; then
        echo 1
    else
        echo 0
    fi
}

use_php7=$4
vagrant_dir="/vagrant"

source "${vagrant_dir}/scripts/output_functions.sh"

status "Upgrading environment (recurring)"
incrementNestingLevel


status "Deleting obsolete repository"
sudo rm -f /etc/apt/sources.list.d/ondrej-php-7_0-trusty.list


function install_php73 () {
    status "Installing PHP 7.3"

    apt-get update

    # Setup PHP
    apt-get install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php7.list

    # Install PHP 7.3
    apt-get install -y php7.3 php7.3-common php7.3-curl php7.3-cli php7.3-mysql php7.3-gd php7.3-intl php7.3-xsl php7.3-bcmath php7.3-mbstring php7.3-soap php7.3-zip libapache2-mod-php7.3

    # Install XDebug
    apt-get install -y php7.3-dev
    cd /usr/lib
    rm -rf xdebug73
    git clone git://github.com/xdebug/xdebug.git xdebug73
    cd xdebug73
    phpize
    ./configure --enable-xdebug --with-php-config=php-config7.3
    make
    make install
    ## Configure XDebug to allow remote connections from the host
    mkdir -p /etc/php/7.3/cli/conf.d
    touch /etc/php/7.3/cli/conf.d/20-xdebug.ini
    echo 'zend_extension=/usr/lib/xdebug73/modules/xdebug.so
    xdebug.max_nesting_level=200
    xdebug.remote_enable=1
    xdebug.remote_host=192.168.10.1
    xdebug.idekey=phpstorm' > /etc/php/7.3/cli/conf.d/20-xdebug.ini
    echo "date.timezone = America/Chicago" >> /etc/php/7.3/cli/php.ini
    rm -rf /etc/php/7.3/apache2
    ln -s /etc/php/7.3/cli /etc/php/7.3/apache2
    status "Restarting Apache"
    service apache2 restart 2> >(logError) > >(log)
}

function install_php72 () {
    status "Installing PHP 7.2"

    apt-get update

    # Setup PHP
    apt-get install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php7.list
    apt-get update

    # Install PHP 7.2
    apt-get install -y php7.2 php7.2-common php7.2-curl php7.2-cli php7.2-mysql php7.2-gd php7.2-intl php7.2-xsl php7.2-bcmath php7.2-mbstring php7.2-soap php7.2-zip libapache2-mod-php7.2

    # Install XDebug
    apt-get install -y php7.2-dev
    cd /usr/lib
    rm -rf xdebug72
    git clone git://github.com/xdebug/xdebug.git xdebug72
    cd xdebug72
    phpize7.2
    ./configure --enable-xdebug --with-php-config=php-config7.2
    make
    make install
    ## Configure XDebug to allow remote connections from the host
    mkdir -p /etc/php/7.2/cli/conf.d
    touch /etc/php/7.2/cli/conf.d/20-xdebug.ini
    echo 'zend_extension=/usr/lib/xdebug72/modules/xdebug.so
    xdebug.max_nesting_level=200
    xdebug.remote_enable=1
    xdebug.remote_host=192.168.10.1
    xdebug.idekey=phpstorm' > /etc/php/7.2/cli/conf.d/20-xdebug.ini
    echo "date.timezone = America/Chicago" >> /etc/php/7.2/cli/php.ini
    rm -rf /etc/php/7.2/apache2
    ln -s /etc/php/7.2/cli /etc/php/7.2/apache2
    status "Restarting Apache"
    service apache2 restart 2> >(logError) > >(log)
}


if [[ ! -d "/etc/php/7.3" ]]; then
    install_php73
fi

if [[ ! -d "/etc/php/7.2" ]]; then
    install_php72
fi

is_varnish_installed="$(isServiceAvailable varnish)"
if [[ ${is_varnish_installed} -eq 0 ]]; then
    status "Installing Varnish"
    apt-get update 2> >(logError) > >(log)
    apt-get install -y varnish 2> >(logError) > >(log)
fi

if varnishd -V 2>&1 | grep -q '3.0.5' ; then
    status "Upgrading Varnish to v4.1"
    export DEBIAN_FRONTEND=noninteractive
    apt-get remove varnish -y 2> >(logError) > >(log)
    apt-get remove --auto-remove varnish -y 2> >(logError) > >(log)
    apt-get purge varnish -y 2> >(logError) > >(log)
    apt-get purge --auto-remove varnish -y 2> >(logError) > >(log)

    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish41/script.deb.sh | bash 2> >(logError) > >(log)
    apt-get install varnish -y  2> >(logError) > >(log)

    rm -f "${vagrant_dir}/etc/magento2_default_varnish.vcl"
    rm -f "/etc/varnish/default.vcl"
fi

is_redis_installed="$(isServiceAvailable redis)"
if [[ ${is_redis_installed} -eq 0 ]]; then
    status "Installing Redis"
    sudo apt -y install redis-server
fi


# TODO: Fix for a bug, should be removed in 3.0
#sed -i "/zend_extension=.*so/d" /etc/php/7.0/cli/conf.d/20-xdebug.ini
#echo "zend_extension=xdebug.so" >> /etc/php/7.0/cli/conf.d/20-xdebug.ini

status "Fixing potential issue with MySQL being down after VM power off"
service mysql restart 2> >(logError) > >(log)

decrementNestingLevel
