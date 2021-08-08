# All generated input variables will be of 'string' type as this is how Packer JSON
# views them; you can change their type later on. Read the variables type
# constraints documentation
# https://www.packer.io/docs/templates/hcl_templates/variables#type-constraints for more info.

variable "ami_name" {
  type    = string
  default = "ubuntu-ami-test-build-{{isotime \"2006-01-02_150405\"}}"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# ### VPC and subnet information are for Infra environment ###
# variable "vpc" {
#   type    = string
#   default = ""
# }

# variable "subnet" {
#   type    = string
#   default = ""
# }

# The amazon-ami data block is generated from your amazon builder source_ami_filter; a data
# from this block can be referenced in source and locals blocks.
# Read the documentation for data blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/data
# Read the documentation for the Amazon AMI Data Source here:
# https://www.packer.io/docs/datasources/amazon/ami
data "amazon-ami" "ubuntu_image" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = "${var.aws_region}"
}

# Source blocks are generated from your builders. A build block runs provisioner
# and post-processors on a source. Read the documentation for source blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "amazon-ebs" "ubuntu_ami_builder" {
  ami_name                    = "${var.ami_name}"
  associate_public_ip_address = "true"
  # iam_instance_profile        = ""
  instance_type               = "t3a.medium"
  encrypt_boot                = "true"
  # vpc_id = "${var.vpc}"
  # subnet_id    = "${var.subnet}"
  region = "${var.aws_region}"
  launch_block_device_mappings {
    delete_on_termination = "true"
    device_name           = "/dev/sda1"
    volume_size           = "15"
    volume_type           = "gp2"
  }
  run_tags = {
    Environment = "development"
    Name        = "${var.ami_name}"
  }
  run_volume_tags = {
    Name = "${var.ami_name}"
  }
  snapshot_tags = {
    Name = "${var.ami_name}"
  }
  source_ami   = "${data.amazon-ami.ubuntu_image.id}"
  ssh_username = "ubuntu"
  tags = {
    Name = "${var.ami_name}"
  }
}

# The build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
build {
  sources = ["source.amazon-ebs.ubuntu_ami_builder"]

  provisioner "shell" {
    execute_command   = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    script            = "build-gvm-ami.sh"
  }
}
