# Description=Job that runs the ospd-openvas daemon
# Documentation=man:gvm
# After=network.target networking.service redis-server@openvas.service

# Environment=PATH=$GVM_INSTALL_PREFIX/bin/ospd-scanner/bin:$GVM_INSTALL_PREFIX/bin:$GVM_INSTALL_PREFIX/sbin:$GVM_INSTALL_PREFIX/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# ExecStart=$GVM_INSTALL_PREFIX/bin/ospd-scanner/bin/ospd-openvas --config $GVM_INSTALL_PREFIX/etc/ospd-openvas.conf
# PrivateTmp=true



# After=postgresql.service ospd-openvas.service

# ExecReload=/bin/kill -HUP \$MAINPID
# KillMode=mixed
# Restart=on-failure
# RestartSec=2min