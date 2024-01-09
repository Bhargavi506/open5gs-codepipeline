provider "aws" {
    region = "us-east-1"
    #access_key ="AKIA4YOR5PXKTXRX3SFS"
    #secret_key = "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"
}
# backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-s3-bucket-open5gs-1333"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
# create core VPC
resource "aws_vpc" "core_vpc" {
  cidr_block = "190.1.0.0/16"

  tags = {
    Name = "core_vpc"
  }
}

# create core subnet
resource "aws_subnet" "core_subnet" {
  vpc_id            = aws_vpc.core_vpc.id
  cidr_block        = "190.1.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "core_subnet"
  }
}

# create Internet gateway for core vpc
resource "aws_internet_gateway" "core_IGW" {
    depends_on = [ aws_vpc.core_vpc ]
    vpc_id = aws_vpc.core_vpc.id

    tags = {
        Name = "core_IGW"
    }
}

# create public route table for core
resource "aws_route_table" "core_rt" {
    vpc_id = "${aws_vpc.core_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.core_IGW.id}"
    }

    tags = {
        Name = "core_rt"
    }
}

# public route table association for core vpc
resource "aws_route_table_association" "public_ass" {
    # The subnet ID to create an association.
    subnet_id = aws_subnet.core_subnet.id

    # The ID of the routing table to associate with.
    route_table_id = aws_route_table.core_rt.id
}

############################# create core node security group ###################
resource "aws_security_group" "core_SG" {
    name        = "core_node__SG"
    description = "Allow all traffic"
    vpc_id      = aws_vpc.core_vpc.id
    #this is going to allow traffic in
    ingress {
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "all traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }    
    # this is going to allow traffic out
    egress {
        description = "all traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
 
    tags = {
        Name = "core_node__SG"
    }
}

############################# core node key_pair  ###########################################
variable "core_key_pair_name" { # This should be a resource not variable i guess
    type = string
    default = "core-kp"  
}
# To get private key
resource "tls_private_key" "rsa" {
    algorithm = "RSA"
    rsa_bits  = 4096
}
# create a new key pair(public key + private key)
resource "aws_key_pair" "core_kp" {
    key_name   = var.core_key_pair_name
    public_key = tls_private_key.rsa.public_key_openssh # You can create a local file also to ssh in ur local machine

    # Create file to store private key in machine
    provisioner "local-exec" {
        command = "echo '${tls_private_key.rsa.private_key_pem}' > ./'${var.core_key_pair_name}'.pem"
    } 
    provisioner "local-exec" {
        command = "chmod 400 ./'${var.core_key_pair_name}'.pem"
    }
}

######################## Launch core EC2 instance  ################################
resource "aws_instance" "core_ec2" {
    ami           = "ami-0aa2b7722dc1b5612"
    instance_type = "t2.medium"
    subnet_id     = aws_subnet.core_subnet.id
    vpc_security_group_ids = [ 
    aws_security_group.core_SG.id
    ]
    key_name      = var.core_key_pair_name
    # root disks
    root_block_device {
        volume_size           = "20"
        volume_type           = "io1"
        iops                  = 200
        encrypted             = true
        delete_on_termination = true
    }
    connection {
        type        = "ssh"
        user        = "ubuntu"
        timeout     = "3m"
        private_key = file("./${var.core_key_pair_name}.pem")
        host        = aws_instance.core_ec2.public_ip
    }    
    tags = {
        Name = "core_ec2"
    }
}
#################################### Elastic IP for core instance ############################
#resource "aws_eip" "core-eip" {
#  instance = aws_instance.core_ec2.id
#  #vpc      = true
#}

#################### To install microk8s on core node #################################
resource "null_resource" "install_oncore" {
    depends_on = [ 
        aws_instance.core_ec2
    ]    
    provisioner "remote-exec" {
        inline = [
            "cloud-init status --wait",
            file("${path.module}/microk8s_install.sh"),
            #"sleep 60",
            file("${path.module}/Open5Gs_deploy.sh"),
        ]
    }
    connection {
        type        = "ssh"
        user        = "ubuntu"
        timeout     = "3m"
        private_key = file("./${var.core_key_pair_name}.pem")
        host        = aws_instance.core_ec2.public_ip
    }
}