# gvm_bash_script
This installs Greenbone Vulnerability Management (GVM) as a bash script for Debian/Ubuntu services. This does NOT work for Docker. Please bare that in mind it works for VMs or bare metal deployments.

## Installation Configurements
First set your environment variables that are to be used in the bash script by modifying the following variables:
- `GVM_INSTALL_PREFIX`: Path to the GVM user directory (default = /var/opt/gvm)
- `GVM_VERSIONS`: The GVM version to install (default = 21.04)
- `GVM_ADMIN_PWD`: The initial admin password. (please change the password...BIG security risk) (default = admin)

## Requirements
- Installation works on these distros:
- - Debian 10
- - Ubuntu 20.04
- Have `sudo` installed since you will need to switch between `gvm` and `root` users for the installation process.
- When installing the NVTs, SCAP, and CERT data. This will be the biggest batch of data that will need to be stored so you will need up to 10-15 GiB of data.

## IMPORTANT
My bash script does not install `openvas-smb` (this module allows OpenVAS Scanner to scan Windows servers) and `gsa` (allows one to interface with the website of OpenVAS Scanner. If you would like to have it installed with the other modules please look toward my acknolwedgements for those services. What I did was add a tool that Greenbone provides called `gvm-tools`
- This tool allows one to interact without the need of `gsa` and do scans through API actions using `xml` code. Here is their documentation on how to use [gvm-tools](https://docs.greenbone.net/GSM-Manual/gos-5/en/gmp.html)
- Another important issue that has been appearing on Debian 10/Ubuntu 20.04 services is whenever you scan a target, OpenVAS Scanner will give you 0.0 Severity Log. To fix this issue, please follow this [link](https://community.greenbone.net/t/scan-severity-0-0-log/9554/3). (Since GSA is not installed we cannot interact with the "Custom Config" so I will see about creating a custom config on my side for this to work.)

## SUPPORT
If anyone wants to help please let me know in GitHub. I will be glad to have support on my work since this will be open for ALL for FREE! 

## Acknowledgements
Great inspiration of this script comes from [Jarthianur](https://github.com/Jarthianur/gvm-install-script) for his work on the GVM script. I modified the code with modifications to be shared for all and will add several sections that would help others.

