#!/bin/bash

### 1. Intro
intro() {
  cat <<EOF

+--------------------------------------------------------------+
| ==========================  INFO  ========================== |
|                                                              |
|  This script will configure a production ready Caddy server. |
|                                                              |
|  It is assumed that you already have Caddy installed.        |
|  If you don't, you can  easily install it by running:        |
|                                                              |
|  1. wget getcaddy.com -O /tmp/install-caddy                  |
|  2. chmod +x /tmp/install-caddy                              |
|  3. /tmp/install-caddy                                       |
|                                                              |
|  Once you've done that you can re-run this script.           |
|                                                              |
+--------------------------------------------------------------+

EOF

  read -e -p "> Do you want to continue? [Y/n] " CONTINUE

  if [ "$CONTINUE" != "Y" ]; then
    printf "\nACTION: You answered 'No'. Aborting.\n\n"
    exit 1;
  fi
}

### 2. Check if Caddy is alredy installed. If not, exit.
check_caddy_installed() {
  if [ -x /usr/local/bin/caddy ]; then
    CADDY_VERSION=$(/usr/local/bin/caddy --version)
    printf "\n* $CADDY_VERSION is already installed. Continuing ...\n"
  else
    printf "\nINFO: Sorry, Caddy doesn't seem to be installed yet.
      Install Caddy and then re-run this script.
      Aborting.\n\n"
    exit 1;
  fi
}

### 3. Set up site name, site dir and log dir
site_setup() {
  printf "\nINFO: Please provide a fully qualified domain name (FQDN) for the site.
      The name will be used to set up your website and to generate the site's
      HTTPS certificate (if selected)\n\n"

  read -e -p "> FQDN: " FQDN

  WEBROOT="/var/www/caddy/$FQDN"
  LOGS="/var/log/caddy/$FQDN"
  CERT_PATH="/etc/ssl/certs"
  KEY_PATH="/etc/ssl/private"

  mkdir -p $WEBROOT && chown -R www-data:www-data /var/www/caddy
  mkdir -p $LOGS && chown -R www-data:www-data /var/log/caddy
}

### 4. Set HTTPS/HTTP, root and log file locations and create skeleton Caddyfile
caddyfile_setup() {
  read -e -p "> Use HTTPS? [Y/n] " HTTPS
  if [ $HTTPS == "Y" ]; then
    # Use Let's Encrypt for automatic ?
    read -e -p "> Use Let's Encrypt to generate a certificate? [Y/n] " LE
    if [ $LE == "Y" ]; then
      read -e -p "> Email for certificate signing: " LE_EMAIL
      printf "https://$FQDN
tls $LE_EMAIL" > $WEBROOT/Caddyfile
    elif  [ $LE == "n" ]; then
      printf "\nINFO: This script assumes your certificate and key are in:\n
      * $CERT_PATH
      * $KEY_PATH\n
      If they are not, please put them there and re-run the script.\n"
      printf "\nACTION: Please specify certificate and key file names:\n\n"
      read -e -p "> Certificate: " CERT_FILE
      chown root:root $CERT_PATH/$CERT_FILE
      chmod 0777 $CERT_PATH/$CERT_FILE
      read -e -p "> Private key: " KEY_FILE
      chown -R www-data:www-data $KEY_PATH
      chmod 0700 $KEY_PATH
      chmod 0600 $KEY_PATH/$KEY_FILE
      printf "https://$FQDN
tls $CERT_PATH/$CERT_FILE $KEY_PATH/$KEY_FILE" > $WEBROOT/Caddyfile
    fi
  elif [ $HTTPS == "n" ]; then
    printf "http://$FQDN
tls no" > $WEBROOT/Caddyfile
  fi

  printf "
root $WEBROOT
log $LOGS/access.log
errors $LOGS/error.log" >> $WEBROOT/Caddyfile
}

### 5. Create website root dir and basic index.html file
webpage_create() {
  printf "<h1>Caddy Server</h1>
<h2>Hey there!</h2>
<p>Congratulations, your Caddy server is up and running.</p>
<p>To update this page or change your Caddyfile you can go here:</p>
<ul>
  <li><pre>$WEBROOT</pre></li>
  <li><pre>$WEBROOT/Caddyfile</pre></li>
</ul>
" > $WEBROOT/index.html

  chown -R www-data:www-data /var/www/caddy
}

### 6. Ensure Caddy is allowed to run on privileged ports:
allow_privileged_ports() {
  sudo setcap cap_net_bind_service=+ep /usr/local/bin/caddy
}

### 7. Create Upstart script for Caddy
create_upstart_script () {
  sudo printf "description \"Caddy Server startup script\"
author \"Martin Lanner\"

start on runlevel [2345]
stop on runlevel [016]

# set max file descriptors (soft/hard)
limit nofile 4096 4096

setuid www-data
setgid www-data

respawn
respawn limit 10 5

script
    exec /usr/local/bin/caddy -conf=\"$WEBROOT/Caddyfile\"
end script
" > /etc/init/caddy.conf
}

### 8. Start Caddy server
start_caddy() {
  echo
  service caddy restart
  echo
}

## MAIN SCRIPT ##

intro #1
check_caddy_installed #2
site_setup #3
caddyfile_setup #4
webpage_create #5
allow_privileged_ports #6
create_upstart_script #7
start_caddy #8

