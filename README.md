# Greenbone Vulnerability Management (GVM) Bash Script
This installs Greenbone Vulnerability Management (GVM) for Debian/Ubuntu services. This does NOT work for Docker. Please bare that in mind it works for VMs and bare metal deployments. For documentation on how to install GVM 21.04, please follow Greenbone's process [here](https://greenbone.github.io/docs/gvm-21.04/index.html).

## Installation Configurements
First set your environment variables that are to be used in the bash script by modifying the following variables:
- `GVM_INSTALL_PREFIX`: Path to the GVM user directory (default = /opt/gvm)
- `GVM_VERSIONS`: The GVM version to install (default = 21.04)
- `GVM_ADMIN_PWD`: The initial admin password. (please change the password...BIG security risk) (default = admin)

## Installation and Testing Procedure
- For installation purposes, go to the directory and run `./build-gvm-ami.sh` in your VM or server.
- For testing purposes, I currently use Packer (HCL2) to create the image in AWS which will then build the AMI once successful. Please change the settings to what you want. To build in your own account in AWS, go ahead and first setup by installing `awscli` and then execute `aws configure` (where it will ask for you to enter your `secret key` and `secret access key`). Once this is done, run `packer build aws_ubuntu_ami.json.pkr.hcl` and Packer will begin to build the AMI in your environment.

## Requirements
- Installation works on these distros:
  - Debian 10
  - Ubuntu 20.04
- Have `sudo` installed since you will need to switch between `gvm` and `root` users for the installation process.
- When installing the NVTs, SCAP, and CERT data. This will be the biggest batch of data that will need to be stored so you will need up to 10-15 GiB of data.
- When the bash script is setting up your NVTs, GVMD_DATA, SCAP, and CERT, it can take 1 hour and 40 minutes to download them. The SLOWEST beign SCAP. 

## Important
My bash script does not install `gsa` (allows one to interface with the website of OpenVAS Scanner). If you would like to have it installed with the other modules that support the web interface, please look toward my acknolwedgements with the link. What I did was add a tool that Greenbone provides called `gvm-tools` for user `gvm`.
- This tool allows one to interact without the need of GSA and do scans through API actions using `xml` code. Here is their documentation on how to use [gvm-tools](https://docs.greenbone.net/GSM-Manual/gos-5/en/gmp.html)
- As you start to dive deeper into the GVM, the API documenation of what can be used is [here](https://docs.greenbone.net/API/GMP/gmp-20.08.html#command_create_config). This allows users to enter commands that allows either to create alerts, create configs, create credentials, etc. You name it. It's very handy and this is that I will implement as the MAIN scanner. 
- An important issue that has conflicted with Debian 10/Ubuntu 20.04 services is whenever you scan a target, OpenVAS Scanner will give you 0.0 Severity Log. To fix this issue, please follow this [link](https://community.greenbone.net/t/scan-severity-0-0-log/9554/3). (Since GSA is not installed we cannot interact with the "Custom Config" so I will see about creating a custom config on my side for this to work.)

## Support
If anyone wants to help please let me know in GitHub. I will be glad to have support on my work since this will be open for ALL for FREE!

## To-Dos
- [ ] Going to create python scripts that will be incorporating the full scans into my bash script so this can be ran separately when you want to scan a target using API actions.
- [ ] Will further look into creating targets and setup of the GVM scanner internally using `gvm-tools` APIs

## Acknowledgements
Great inspiration of this script comes from [Jarthianur](https://github.com/Jarthianur/gvm-install-script) for his work on the GVM script. I modified the code with modifications to be shared for all and will add several sections that would help others.

