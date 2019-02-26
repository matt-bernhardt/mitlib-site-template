#!/usr/bin/env bash
# Provision WordPress Stable

echo -e "\n========================================================="
echo -e "\nCreating MITlib local WordPress..."
composer --version
npm --version
grunt --version
composer update
npm install -g sass
echo -e "\n========================================================="

# fetch the first host as the primary domain. If none is available, generate a default using the site name
DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
WP_TYPE=`get_config_value 'wp_type' "single"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/nginx-error.log
touch ${VVV_PATH_TO_SITE}/log/nginx-access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-load.php" ]]; then
    echo "Downloading WordPress..."
	noroot wp core download --version="${WP_VERSION}"
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'SCRIPT_DEBUG', true );
PHP
fi

if ! $(noroot wp core is-installed); then
  echo "Installing WordPress Stable..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core ${INSTALL_COMMAND} --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="admin@local.test" --admin_password="password"
else
  echo "Updating WordPress Stable..."
  cd ${VVV_PATH_TO_SITE}/public_html
  noroot wp core update --version="${WP_VERSION}"
fi

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"

if [ -n "$(type -t is_utility_installed)" ] && [ "$(type -t is_utility_installed)" = function ] && `is_utility_installed core tls-ca`; then
    sed -i "s#{{TLS_CERT}}#ssl_certificate /vagrant/certificates/${VVV_SITE_NAME}/dev.crt;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}#ssl_certificate_key /vagrant/certificates/${VVV_SITE_NAME}/dev.key;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
else
    sed -i "s#{{TLS_CERT}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
fi

# Local customization
# Plugins
noroot wp plugin delete hello
noroot wp plugin install acf-image-crop-add-on
noroot wp plugin install acf-location-field-master
noroot wp plugin install advanced-custom-fields-pro --activate
noroot wp plugin install add-category-to-pages
noroot wp plugin install addthis
noroot wp plugin install advanced-post-types-order
noroot wp plugin install akismet
noroot wp plugin install antivirus
noroot wp plugin install black-studio-tinymce-widget
noroot wp plugin install category-template-hierarchy
noroot wp plugin install cf7-conditional-fields
noroot wp plugin install classic-editor
noroot wp plugin install cms-tree-page-view
noroot wp plugin install contact-form-7 --activate
noroot wp plugin install cpt-onomies
noroot wp plugin install custom-post-type-ui
noroot wp plugin install custom-sidebars
noroot wp plugin install https://github.com/MITLibraries/mitlib-plugin-canary/archive/master.zip --activate
noroot wp plugin install wordpress-importer --activate

# Contrib themes
noroot wp theme install twentytwelve --activate
noroot wp theme delete twentysixteen twentyseventeen twentynineteen

# Custom themes
noroot wp theme install https://github.com/MITLibraries/mitlib-courtyard/archive/1.3.0-beta1.zip
cd ${VVV_PATH_TO_SITE}/public_html/wp-content/themes/mitlib-courtyard/
pwd
noroot npm install
noroot grunt

noroot wp theme install https://github.com/MITLibraries/MITlibraries-parent/archive/master.zip
cd ${VVV_PATH_TO_SITE}/public_html/wp-content/themes/MITlibraries-parent/
pwd
noroot npm install
noroot grunt

noroot wp theme activate mitlib-courtyard

# Sample content
cd ${VVV_PATH_TO_SITE}
git clone https://github.com/WPTRT/theme-unit-test.git ~/theme-unit-test
noroot wp import ~/theme-unit-test/themeunittestdata.wordpress.xml --authors=create
