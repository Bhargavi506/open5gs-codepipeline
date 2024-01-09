#################   ran VPC  ###############

resource "aws_vpc" "ran_vpc" {
  cidr_block = "190.2.0.0/16"

  tags = {
    Name = "ran_vpc"
  }
}

# create ran subnet
resource "aws_subnet" "ran_subnet" {
  vpc_id            = aws_vpc.ran_vpc.id
  cidr_block        = "190.2.0.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "ran_subnet"
  }
}

# create Internet gateway for ran vpc
resource "aws_internet_gateway" "ran_IGW" {
    depends_on = [ aws_vpc.ran_vpc ]
    vpc_id = aws_vpc.ran_vpc.id

    tags = {
        Name = "ran_IGW"
    }
}

# create public route table for ran
resource "aws_route_table" "ran_rt" {
    vpc_id = "${aws_vpc.ran_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.ran_IGW.id}"
    }

    tags = {
        Name = "ran_rt"
    }
}

# public route table association for ran vpc
resource "aws_route_table_association" "ran_ass" {
    # The subnet ID to create an association.
    subnet_id = aws_subnet.ran_subnet.id

    # The ID of the routing table to associate with.
    route_table_id = aws_route_table.ran_rt.id
}

################### create ran node security group ########################
resource "aws_security_group" "ran_SG" {
    name        = "ran_node__SG"
    description = "Allow all traffic"
    vpc_id      = aws_vpc.ran_vpc.id
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
        Name = "ran_node__SG"
    }
}

######################## ran node key_pair ########################
variable "ran_key_pair_name" { # This should be a resource not variable i guess
    type = string
    default = "ran-kp"  
}
# To get private key
resource "tls_private_key" "rsa1" {
    algorithm = "RSA"
    rsa_bits  = 4096
}
# create a new key pair(public key + private key)
resource "aws_key_pair" "ran_kp" {
    key_name   = var.ran_key_pair_name
    public_key = tls_private_key.rsa1.public_key_openssh # You can create a local file also to ssh in ur local machine

    # Create file to store private key in machine
    provisioner "local-exec" {
        command = "echo '${tls_private_key.rsa1.private_key_pem}' > ./'${var.ran_key_pair_name}'.pem"
    } 
    provisioner "local-exec" {
        command = "chmod 400 ./'${var.ran_key_pair_name}'.pem"
    }
}

######################### Launch ran  EC2 instance #############################
resource "aws_instance" "ran_ec2" {
    ami           = "ami-0aa2b7722dc1b5612"
    instance_type = "t2.medium"
    subnet_id     = aws_subnet.ran_subnet.id
    vpc_security_group_ids = [ 
    aws_security_group.ran_SG.id
    ]
    key_name      = var.ran_key_pair_name

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
        private_key = file("./${var.ran_key_pair_name}.pem")
        host        = aws_instance.ran_ec2.public_ip
    }
    
    tags = {
        Name = "ran_ec2"
    }
}
#################################### Elastic IP for ran instance ############################
#resource "aws_eip" "ran-eip" {
#  instance = aws_instance.ran_ec2.id
#  #vpc      = true
#}
##################### To install microk8s on ran node ##########################
resource "null_resource" "install_onran" {
    depends_on = [ 
        aws_instance.ran_ec2,
        null_resource.install_oncore
    ]    
    provisioner "remote-exec" {
        inline = [
            "cloud-init status --wait",
            file("${path.module}/microk8s_install.sh"),
            "sleep 60",
            file("${path.module}/ueran_install.sh"),
        ]
    }
    connection {
        type        = "ssh"
        user        = "ubuntu"
        timeout     = "3m"
        private_key = file("./${var.ran_key_pair_name}.pem")
        host        = aws_instance.ran_ec2.public_ip
    }
}