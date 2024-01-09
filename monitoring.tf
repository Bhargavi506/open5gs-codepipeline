############    Monitoing VPC  ############

resource "aws_vpc" "monitoring_vpc" {
  cidr_block = "190.3.0.0/16"

  tags = {
    Name = "monitoring_vpc"
  }
}

# create monitoring subnet
resource "aws_subnet" "monitoring_subnet" {
  vpc_id            = aws_vpc.monitoring_vpc.id
  cidr_block        = "190.3.0.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring_subnet"
  }
}

# create Internet gateway for monitoring vpc
resource "aws_internet_gateway" "monitoring_IGW" {
    depends_on = [ aws_vpc.monitoring_vpc ]
    vpc_id = aws_vpc.monitoring_vpc.id

    tags = {
        Name = "monitoring_IGW"
    }
}

# create public route table for monitoring
resource "aws_route_table" "monitoring_rt" {
    vpc_id = "${aws_vpc.monitoring_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.monitoring_IGW.id}"
    }

    tags = {
        Name = "monitoring_rt"
    }
}
# public route table association for monitoringe vpc
resource "aws_route_table_association" "monitoring_ass" {
    # The subnet ID to create an association.
    subnet_id = aws_subnet.monitoring_subnet.id

    # The ID of the routing table to associate with.
    route_table_id = aws_route_table.monitoring_rt.id
}

# create monitoring node security group
resource "aws_security_group" "monitoring_SG" {
    name        = "monitoring_node__SG"
    description = "Allow all traffic"
    vpc_id      = aws_vpc.monitoring_vpc.id
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
        Name = "monitoring_node__SG"
    }
}

##########################  monitoring node key pair  ##############################
variable "monitoring_key_pair_name" { # This should be a resource not variable i guess
    type = string
    default = "monitoring-kp"  
}
# To get private key
resource "tls_private_key" "rsa2" {
    algorithm = "RSA"
    rsa_bits  = 4096
}
# create a new key pair(public key + private key)
resource "aws_key_pair" "monitoring_kp" {
    key_name   = var.monitoring_key_pair_name
    public_key = tls_private_key.rsa2.public_key_openssh # You can create a local file also to ssh in ur local machine

    # Create file to store private key in machine
    provisioner "local-exec" {
        command = "echo '${tls_private_key.rsa2.private_key_pem}' > ./'${var.monitoring_key_pair_name}'.pem"
    } 
    provisioner "local-exec" {
        command = "chmod 400 ./'${var.monitoring_key_pair_name}'.pem"
    }
}

#################################### Launch monitoring EC2 instance ###############################
resource "aws_instance" "monitoring_ec2" {
    ami           = "ami-0aa2b7722dc1b5612"
    instance_type = "t2.medium"
    subnet_id     = aws_subnet.monitoring_subnet.id
    vpc_security_group_ids = [ 
    aws_security_group.monitoring_SG.id
    ]
    key_name      = var.monitoring_key_pair_name
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
        private_key = file("./${var.monitoring_key_pair_name}.pem")
        host        = aws_instance.monitoring_ec2.public_ip
    }    
    tags = {
        Name = "monitoring_ec2"
    }
}
#################################### Elastic IP for ran instance ############################
#resource "aws_eip" "monitoring-eip" {
 # instance = aws_instance.monitoring_ec2.id
  #vpc      = true
#}
############# To install microk8s on monitoring node  ##################
resource "null_resource" "install_onmonitoring" {
    depends_on = [ 
        aws_instance.monitoring_ec2,
        null_resource.install_onran
    ]    
    provisioner "remote-exec" {
        inline = [
            "cloud-init status --wait",
            file("${path.module}/microk8s_install.sh"),
            "sleep 60",
            file("${path.module}/prometheus_install.sh"),
            file("${path.module}/grafana_install.sh"),
        ]
    }
    connection {
        type        = "ssh"
        user        = "ubuntu"
        timeout     = "3m"
        private_key = file("./${var.monitoring_key_pair_name}.pem")
        host        = aws_instance.monitoring_ec2.public_ip
    }
}

