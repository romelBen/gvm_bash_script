#!/bin/bash

# Environment variable to be used for scans
export GVM="${GVM_CLI:-/opt/gvm/.local/bin/gvm-cli} --gmp-username admin --gmp-password admin --protocol GMP socket --sockpath ${GVM_SOCK:-/opt/gvm/var/run/gvmd.sock}"

if config=$(${GVM} --xml "<get_configs/>" \
	| xmllint --xpath "//config/name[text()='big_ole_scan_config']/../@id" - \
	| sed 's/id=//;' \
	| tr -d '" ')
then
	echo "${config}"
	exit 0
fi

comment "Creating custom scan config"

if ! config=$(${GVM} --xml "<get_configs/>" \
	| xmllint --xpath "//config/name[text()='Full and fast']/../@id" - \
	| sed 's/id=//;' \
	| tr -d '" ')
then
	die "Failed to identify base config"
fi

if ! config=$(${GVM} --xml "<create_config><copy>${config}</copy><name>big_ole_scan_config</name></create_config>" \
	| sed 's/^.*id="//;s/".*$//')
then
	die "Failed to create custom config"
fi

unset xml
for family in \
	"AIX Local Security Checks" \
	"Amazon Linux Local Security Checks" \
	"Brute force attacks" \
	"Buffer overflow" \
	"CISCO" \
	"CentOS Local Security Checks" \
	"Citrix Xenserver Local Security Checks" \
	"Compliance" \
	"Databases" \
	"Debian Local Security Checks" \
	"Default Accounts" \
	"Denial of Service" \
	"F5 Local Security Checks" \
	"FTP" \
	"Fedora Local Security Checks" \
	"FortiOS Local Security Checks" \
	"FreeBSD Local Security Checks" \
	"Gain a shell remotely" \
	"General" \
	"Gentoo Local Security Checks" \
	"HP-UX Local Security Checks" \
	"Huawei" \
	"Huawei EulerOS Local Security Checks" \
	"IT-Grundschutz" \
	"IT-Grundschutz-15" \
	"IT-Grundschutz-deprecated" \
	"JunOS Local Security Checks" \
	"Mac OS X Local Security Checks" \
	"Mageia Linux Local Security Checks" \
	"Malware" \
	"Mandrake Local Security Checks" \
	"Nmap NSE" \
	"Nmap NSE net" \
	"Oracle Linux Local Security Checks" \
	"Palo Alto PAN-OS Local Security Checks" \
	"Peer-To-Peer File Sharing" \
	"Policy" \
	"Port scanners" \
	"Privilege escalation" \
	"Product detection" \
	"RPC" \
	"Red Hat Local Security Checks" \
	"Remote file access" \
	"SMTP problems" \
	"SNMP" \
	"SSL and TLS" \
	"Service detection" \
	"Settings" \
	"Slackware Local Security Checks" \
	"Solaris Local Security Checks" \
	"SuSE Local Security Checks" \
	"Ubuntu Local Security Checks" \
	"Useless services" \
	"VMware Local Security Checks" \
	"Web Servers" \
	"Web application abuses" \
	"Windows" \
	"Windows : Microsoft Bulletins"
do
	xml="${xml}<family><name>${family}</name><all>1</all><growing>1</growing></family>"
done

if ! ${GVM} --xml "<modify_config config_id=\"${config}\"><family_selection><growing>1</growing>${xml}</family_selection></modify_config>"; then
    die "Failed to modify config"
fi

echo "${config}"
exit 0
