#!/usr/bin/env bash

###################################################################################################
################################## GVM Installation Process #######################################
###################################################################################################
set -Ee
sudo bash -c "echo 'User $USER is sudo enabled.'"

# This function will create create three separate logs echoing either INFO, WARN, or ERROR
function log() {
  local TIME=$(date +"%T")
  case $1 in
  -i)
      echo -en "\033[0;32m[INFO ]\033[0m"
      shift
      ;;
  -w)
      echo -en "\033[0;33m[WARN ]\033[0m"
      shift
      ;;
  -e)
      echo -en "\033[0;31m[ERROR]\033[0m"
      shift
      ;;
  esac
  local ROUTINE=''
  if [ -n "${FUNCNAME[1]}" ]; then
      ROUTINE="->${FUNCNAME[1]}"
  fi
  echo " ${TIME} ${PROMPT}${ROUTINE}:: $*"
}

# This function will create logs for the services of the environment.
function require() {
  local error=0
  for v in $*; do
      if [ -z "${!v}" ]; then
          log -e Env. $v is not set!
          error=1
      fi
  done
  return $error
}

# This function will help execute users as either user or fn in our AMI (aka. root and gvm)
function exec_as() {
  local user="$1"
  local fn="$2"
  shift; shift
  local env=()
  for e in "$@"; do
      env+=( "$e=${!e}" )
  done
  sudo "${env[@]}" -u "$user" bash -c "$(declare -f $fn); $fn"
}

trap "log -e 'Installation failed!'" ERR

# Here are the environment variables that will be used in our build.
export DEBIAN_FRONTEND=noninteractive
export AS_ROOT="bash -c"
export AS_GVM="sudo -u gvm bash -c"

export GVM_INSTALL_PREFIX="/opt/gvm"
export GVM_VERSION="stable"
export GVM_ADMIN_PWD="admin"

require GVM_INSTALL_PREFIX
require GVM_VERSION
require GVM_ADMIN_PWD

# This environment variable is necessary for configuring the GVM scanners library.
export PKG_CONFIG_PATH="$GVM_INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

# This function will prepare our AMI before the mother-of-all-updates in the next function.
function update_system() {
  set -e
  # These 4 repositories are a precaution since Ubuntu can have issues when installing the packages.
  add-apt-repository main
  add-apt-repository universe
  add-apt-repository restricted
  add-apt-repository multiverse
  apt-get update
  apt-get upgrade -yq
  apt-get dist-upgrade -yq
  apt-get autoremove -yq
  apt-get update
}

# This function installs all the dependencies needed for the OpenVAS Scanner
function install_deps() {
  set -e
  apt-get install -yq \
    bison cmake curl doxygen fakeroot gcc g++ build-essential \
    gcc-mingw-w64 gettext git gnupg gnutls-bin \
    graphviz heimdal-dev libgcrypt20-dev libglib2.0-dev \
    libgnutls28-dev libgpgme-dev libhiredis-dev \
    libical-dev libksba-dev libldap2-dev libmicrohttpd-dev \
    libpcap-dev libpopt-dev libradcli-dev libsnmp-dev \
    libsqlite3-dev libssh-gcrypt-dev libxml2-dev nmap nodejs npm \
    nsis perl-base pkg-config postgresql postgresql-contrib \
    postgresql-server-dev-all python3-defusedxml python3-lxml \
    python3-paramiko python3-pip python3-psutil python3-setuptools \
    python3-polib python3-dev redis redis-server rpm rsync smbclient \
    snmp socat software-properties-common sshpass \
    texlive-fonts-recommended texlive-latex-extra uuid-dev \
    vim virtualenv wget xmltoman xml-twig-tools xsltproc libnet1-dev libunistring-dev
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
  echo 'deb https://dl.yarnpkg.com/debian/ stable main' \
      | tee /etc/apt/sources.list.d/yarn.list
  apt-get update
  apt-get install -yq yarn
}

# This will import the Greenbone Signing Key to verify our builds
# function import_greenbone_gpg() {
#   curl -O https://www.greenbone.net/GBCommunitySigningKey.asc
#   gpg --import GBCommunitySigningKey.asc

#   echo -e "trust\n5\ny" > trust_key.cmd gpg --command-file trust_key.cmd --edit-key 9823FAA60ED1E580
# }

# This function will set up the gvm user for our system, the path, and the directory of our environment variable.
function setup_user() {
  set -e
  if [[ "$(id gvm 2>&1 | grep -o 'no such user')" == "no such user" ]]; then
      useradd -c "GVM/OpenVAS user" -d "$GVM_INSTALL_PREFIX" -m -s /bin/bash -U -G redis gvm
  else
      usermod -c "GVM/OpenVAS user" -d "$GVM_INSTALL_PREFIX" -m -s /bin/bash -aG redis gvm
  fi
  cat <<EOT >> /etc/profile.d/gvm.sh
export PATH=\"\$PATH:$GVM_INSTALL_PREFIX/bin:$GVM_INSTALL_PREFIX/sbin:$GVM_INSTALL_PREFIX/.local/bin\"
EOT
  chmod 755 /etc/profile.d/gvm.sh
  . /etc/profile.d/gvm.sh
  cat << EOF > /etc/ld.so.conf.d/gvm.conf
$GVM_INSTALL_PREFIX/lib
EOF
}

# This function will setup our system for redis since you will get a warning from the redis.sock.
# somaxconn, overcommit_memory, and THP need to be reconfigured into the system to remove these warnings.
function system_tweaks() {
  set -e
  sysctl -w net.core.somaxconn=1024
  sysctl vm.overcommit_memory=1
  # TODO: check for their existence
  if [ -z "$(grep -o 'net.core.somaxconn' /etc/sysctl.conf)"  ]; then
    echo 'net.core.somaxconn=1024'  >> /etc/sysctl.conf
  fi
  if [ -z "$(grep -o 'vm.overcommit_memory' /etc/sysctl.conf)"  ]; then
    echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
  fi
  cat << EOF > /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages (THP)
[Service]
Type=simple
ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now disable-thp
}

# This function will send git clones of gvm-libs, openvas, ospd, ospd-openvas, and gvmd to
# directory ~/src.
function clone_sources() {
    set -e
    cd ~/src
    git clone -b "$GVM_VERSION" https://github.com/greenbone/gvm-libs.git \
        || (cd gvm-libs; git pull --all; git checkout "$GVM_VERSION"; git pull; cd ..)
    git clone -b "$GVM_VERSION" https://github.com/greenbone/openvas.git \
        || (cd openvas; git pull --all; git checkout "$GVM_VERSION"; git pull; cd ..)
    git clone -b main --single-branch https://github.com/greenbone/openvas-smb.git \
        || (cd openvas-smb; git pull; cd ..)
    git clone -b "$GVM_VERSION" https://github.com/greenbone/gvmd.git \
        || (cd gvmd; git pull --all; git checkout "$GVM_VERSION"; git pull; cd ..)
    git clone -b "$GVM_VERSION" https://github.com/greenbone/ospd-openvas.git \
        || (cd ospd-openvas; git pull --all; git checkout "$GVM_VERSION"; git pull; cd ..)
    git clone -b "$GVM_VERSION" https://github.com/greenbone/ospd.git \
        || (cd ospd; git pull --all; git checkout "$GVM_VERSION"; git pull; cd ..)
} 

# # This function will use download the tar files to extract and confirm with the gpg key if the signature is correct.
# function clone_sources() {
#   set -e
#   cd ~/src

#   if [[ gpg --verify ~/src/gvm-libs-$GVM_INSTALL_PREFIX.tar.gz.asc ~/src/gvm-libs-$GVM_INSTALL_PREFIX.tar.gz | grep "Good signature from 'Greenbone Community Feed integrity key'" ]]; then
#     curl -f -L https://github.com/greenbone/gvm-libs/archive/refs/tags/v$GVM_INSTALL_PREFIX.tar.gz -o ~/src/gvm-libs-$GVM_INSTALL_PREFIX.tar.gz
#     curl -f -L https://github.com/greenbone/gvm-libs/releases/download/v$GVM_INSTALL_PREFIX/gvm-libs-$GVM_INSTALL_PREFIX.tar.gz.asc -o ~/src/gvm-libs-$GVM_INSTALL_PREFIX.tar.gz.asc
#   fi

# }

# This function will install gvm_libs
function install_gvm_libs() {
  set -e
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
  cd ~/src/gvm-libs
  mkdir -p build
  cd build
  rm -rf *
  cmake -DCMAKE_INSTALL_PREFIX="$GVM_INSTALL_PREFIX" \
        -DLOCALSTATEDIR="$GVM_INSTALL_PREFIX/var" \
        -DSYSCONFDIR="$GVM_INSTALL_PREFIX/etc" ..
  make -j$(nproc)
  make install
}

# This function will install openvas_smb
function install_openvas_smb() {
  set -e
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
  cd ~/src/openvas-smb
  mkdir -p build
  cd build
  rm -rf *
  cmake -DCMAKE_INSTALL_PREFIX="$GVM_INSTALL_PREFIX" ..
  make -j$(nproc)
  make install
}

# This function will install openvas
function install_openvas() {
  set -e
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
  cd ~/src/openvas
  mkdir -p build
  cd build
  rm -rf *
  cmake -DCMAKE_INSTALL_PREFIX="$GVM_INSTALL_PREFIX" \
        -DLOCALSTATEDIR="$GVM_INSTALL_PREFIX/var" \
        -DSYSCONFDIR="$GVM_INSTALL_PREFIX/etc" ..
  make -j$(nproc)
  make install
}

# This function will configure redis to openvas.
function config_redis() {
  set -e
  cp -f /etc/redis/redis.conf /etc/redis/redis.conf.orig
  cp -f "$GVM_INSTALL_PREFIX/src/openvas/config/redis-openvas.conf" /etc/redis/
  chown redis:redis /etc/redis/redis-openvas.conf
  echo 'db_address = /run/redis-openvas/redis.sock' > "$GVM_INSTALL_PREFIX/etc/openvas/openvas.conf"
  chown gvm:gvm "$GVM_INSTALL_PREFIX/etc/openvas/openvas.conf"
  systemctl enable --now redis-server@openvas.service
}

# This function will setup gvm in sudoers which will allow the user (gvm) to run commands of openvas
# without password.
function edit_sudoers() {
  set -e
  if [[ "$(grep -o '$GVM_INSTALL_PREFIX/sbin' /etc/sudoers || true)" == "" ]]; then
      sed -e "s|\(Defaults\s*secure_path.*\)\"|\1:$GVM_INSTALL_PREFIX/sbin\"|" -i /etc/sudoers
  fi
  echo "gvm ALL = NOPASSWD: $GVM_INSTALL_PREFIX/sbin/openvas" > /etc/sudoers.d/gvm
  echo "gvm ALL = NOPASSWD: $GVM_INSTALL_PREFIX/sbin/gsad" >> /etc/sudoers.d/gvm
  chmod 440 /etc/sudoers.d/gvm
}

# This function will install gvmd
function install_gvmd() {
  set -e
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
  cd ~/src/gvmd
  mkdir -p build
  cd build
  rm -rf *
  cmake -DCMAKE_INSTALL_PREFIX="$GVM_INSTALL_PREFIX" \
        -DSYSTEMD_SERVICE_DIR="$GVM_INSTALL_PREFIX" \
        -DLOCALSTATEDIR="$GVM_INSTALL_PREFIX/var" \
        -DSYSCONFDIR="$GVM_INSTALL_PREFIX/etc" ..
  make -j$(nproc)
  make install
}

# This function will setup postgres for gvmd
function setup_postgres() {
  set -e
  psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='gvm'" | grep -q 1 \
    || createuser -DRS gvm
  psql -lqt | cut -d '|' -f 1 | grep -qw gvmd \
    || createdb -O gvm gvmd
  psql gvmd -c 'create role dba with superuser noinherit;' \
    2>&1 | grep -e 'already exists' -e 'CREATE ROLE'
  psql gvmd -c 'grant dba to gvm;'
  psql gvmd -c 'create extension "uuid-ossp";' \
    2>&1 | grep -e 'already exists' -e 'CREATE EXTENSION'
  psql gvmd -c 'create extension "pgcrypto";' \
    2>&1 | grep -e 'already exists' -e 'CREATE EXTENSION'
}

function setup_gvmd() {
  set -e
  . /etc/profile.d/gvm.sh
  gvmd --migrate
  gvm-manage-certs -af
  gvmd --get-users | grep admin || gvmd --create-user=admin --password="$GVM_ADMIN_PWD"
  # set feed owner
  local admin_id="$(gvmd --get-users --verbose | grep admin | awk '{print $2}')"
  gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value "$admin_id"
}

# This function will install ospd-openvas wrapper on ospd
function install_ospd_openvas() {
  set -e
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
  cd ~/src
  if [ ! -d "$GVM_INSTALL_PREFIX/bin/ospd-scanner/" ]; then
    virtualenv --python python3 "$GVM_INSTALL_PREFIX/bin/ospd-scanner/"
  fi
  . "$GVM_INSTALL_PREFIX/bin/ospd-scanner/bin/activate"
  python3 -m pip install --upgrade pip
  cd ospd
  pip3 install .
  cd ../ospd-openvas/
  pip3 install .
}

# This function will install the gvm tools system-wide with user gvm
function install_gvm_tools() {
  python3 -m pip install gvm-tools
}

# This function will create a gvmd systemd service which will connect to ospd-openvas with postgres
function create_gvmd_service() {
  set -e
  cat << EOF > /etc/systemd/system/gvmd.service
[Unit]
Description=Open Vulnerability Assessment System Manager Daemon
Documentation=man:gvmd(8) https://www.greenbone.net
Wants=postgresql.service ospd-openvas.service
After=postgresql.service ospd-openvas.service network.target networking.service
[Service]
Type=forking
User=gvm
Group=gvm
PIDFile=/run/gvmd/gvmd.pid
RuntimeDirectory=gvmd
RuntimeDirectoryMode=2775
EnvironmentFile=$GVM_INSTALL_PREFIX/etc/default/gvmd
ExecStart=$GVM_INSTALL_PREFIX/sbin/gvmd --osp-vt-update=/run/ospd/ospd-openvas.sock -c /run/gvmd/gvmd.sock --listen-group=gvm
Restart=always
TimeoutStopSec=10
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now gvmd.service
  systemctl --no-pager status gvmd.service
}

# This function will create the systemd openvas service which will connect to the redis-server.
function create_openvas_service() {
  set -e
  cat << EOF > $GVM_INSTALL_PREFIX/etc/ospd-openvas.conf
[OSPD - openvas]
log_level = INFO
socket_mode = 0o770
unix_socket = /run/ospd/ospd-openvas.sock
pid_file = /run/ospd/ospd-openvas.pid
log_file = $GVM_INSTALL_PREFIX/var/log/gvm/ospd-openvas.log
lock_file_dir = $GVM_INSTALL_PREFIX/var/lib/openvas
EOF
  cat << EOF > /etc/systemd/system/ospd-openvas.service
[Unit]
Description=Job that runs the ospd-openvas daemon
Documentation=man:gvm
After=network.target networking.service redis-server@openvas.service
Wants=redis-server@openvas.service
[Service]
Environment=PATH=$GVM_INSTALL_PREFIX/bin/ospd-scanner/bin:$GVM_INSTALL_PREFIX/bin:$GVM_INSTALL_PREFIX/sbin:$GVM_INSTALL_PREFIX/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Type=forking
User=gvm
Group=gvm
RuntimeDirectory=ospd
RuntimeDirectoryMode=2775
PIDFile=/run/ospd/ospd-openvas.pid
ExecStart=$GVM_INSTALL_PREFIX/bin/ospd-scanner/bin/ospd-openvas --config $GVM_INSTALL_PREFIX/etc/ospd-openvas.conf
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now ospd-openvas.service
  systemctl --no-pager status ospd-openvas.service
}

# Setup the default scanner of ospd-openvas for the gvmd scans.
function set_default_scanner() {
  set -e
  . /etc/profile.d/gvm.sh
  local id="$(gvmd --get-scanners | grep -i openvas | cut -d ' ' -f1 | tr -d '\n')"
  gvmd --modify-scanner="$id" --scanner-host="/run/ospd/ospd-openvas.sock"
}

# This function will download the NVTs, upload the plugins to redis with openvas, and set a
# community security feed using rsync.
function install_nvt_feeds() {
  #### When greenbone-nvt-sync is run, you get the new feed and ospd-scanner stores it in Redis automatically
  #### (or you can do it manually running openvas -u). Then, gvmd asks ospd-scanner for the feed version
  #### (once each 10 seconds). In case there is a new feed, gvmd will get the new/modified NVT’s.
  set -e
  . /etc/profile.d/gvm.sh
  # IMPORTANT: You need to check if the directory /opt/gvm/var/lib/openvas/plugins/ contains nasl files
  # and it must have /opt/gvm/var/lib/openvas/plugins/plugin_feed_info.inc file
  echo "Syncing NVTs..."
  greenbone-nvt-sync > /dev/null
  sleep 5
  # IMPORTANT: To check for GVMD, SCAP, and CERT, look in directory /opt/gvm/var/lib/gvm/. You will see
  # the directories of the data of each resource: gvmd, scap, and cert.
  echo "Syncing GVMD data..."
  greenbone-feed-sync --type GVMD_DATA > /dev/null
  sleep 5
  ###### Re-enable for testing purposes. SCAP data takes a LONG time to download. Approximately 30-40 minutes.
  # echo "Syncing SCAP data..."
  # greenbone-feed-sync --type SCAP > /dev/null
  # sleep 5
  echo "Syncing CERT data..."
  greenbone-feed-sync --type CERT > /dev/null
  sudo openvas -u
  sleep 5
}

################# Functions for GVM installation ###########################
# WARNING: Do not move these functions unless you know what you are doing. #
log -i "Update system"
exec_as root update_system
log -i "Install dependencies"
exec_as root install_deps
log -i "Setup user"
exec_as root setup_user GVM_INSTALL_PREFIX
log -i "System tweaks"
exec_as root system_tweaks
log -i "Clone GVM sources"
export PKG_CONFIG_PATH
$AS_GVM "mkdir -p ~/src"
log -i "Clone gvm repos into src directory"
exec_as gvm clone_sources GVM_VERSION
# Create and change owner for gvm and ospd sockets.
$AS_ROOT "mkdir -p -m 750 /run/gvm /run/ospd /run/gvmd"
$AS_ROOT "chown -R gvm. /run/gvm /run/ospd /run/gvmd"
log -i "Install gvm-libs"
exec_as gvm install_gvm_libs PKG_CONFIG_PATH GVM_INSTALL_PREFIX
# log -i "Install openvas-smb"
# exec_as gvm install_openvas_smb PKG_CONFIG_PATH GVM_INSTALL_PREFIX
log -i "Install openvas"
exec_as gvm install_openvas PKG_CONFIG_PATH GVM_INSTALL_PREFIX
# Make ourselves root starting here.
$AS_ROOT ldconfig
log -i "Configure redis"
exec_as root config_redis GVM_INSTALL_PREFIX
log -i "Edit sudoers"
exec_as root edit_sudoers GVM_INSTALL_PREFIX
log -i "Install gvmd"
exec_as gvm install_gvmd PKG_CONFIG_PATH GVM_INSTALL_PREFIX
log -i "Setup postgresql"
exec_as postgres setup_postgres
log -i "Setup gvmd"
exec_as gvm setup_gvmd GVM_ADMIN_PWD
log -i "Install ospd-openvas"
exec_as gvm install_ospd_openvas PKG_CONFIG_PATH GVM_INSTALL_PREFIX
log -i "Install gvm-tools"
exec_as gvm install_gvm_tools
log -i "Setup OpenVAS services"
exec_as root create_openvas_service GVM_INSTALL_PREFIX
log -i "Setup GVMd services"
exec_as root create_gvmd_service GVM_INSTALL_PREFIX
log -i "Set OpenVAS default scanner"
exec_as gvm set_default_scanner GVM_INSTALL_PREFIX
log -i "Initiate download of NVTs, GVMD, SCAP, and CERT data into AMI. (This will take 40-50 minutes to complete.)"
exec_as gvm install_nvt_feeds

log -i "Installation of GVM Scanner successful!"
