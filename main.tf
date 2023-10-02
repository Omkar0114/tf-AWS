terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

// initialize the aws credentials
provider "aws" {
    access_key = ""
    secret_key = ""
    region = "us-east-1"
}

// create a VPC in AWS CLoud
resource "aws_vpc" "dev_vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"

    tags = {
      Name: "dev"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.dev_vpc.id
}

resource "aws_route_table" "custom_route_table" {
    vpc_id = aws_vpc.dev_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
      Name: "route table"
    }

}

// Create public & subnets
resource "aws_subnet" "subnet1" {
    vpc_id = aws_vpc.dev_vpc.id
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
    tags = {
      Name: "public_subnet"
    }
}

resource "aws_route_table_association" "route_table_association" {
    subnet_id = aws_subnet.subnet1.id
    route_table_id = aws_route_table.custom_route_table.id
    }

resource "aws_security_group" "allow-traffic" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_traffic"
  }
}

# resource "aws_network_interface" "interface" {
#     subnet_id = aws_subnet.subnet1.id
#     security_groups = ["aws_security_group.allow-traffic.id"]
# }

// create ec2 instance
resource "aws_instance" "web_server" {
    ami = "ami-03a6eaae9938c858c"   //amazon-linux
    # vpc_security_group_ids = ["aws_security_group.allow-traffic.id"]
    subnet_id = aws_subnet.subnet1.id
    instance_type = "t2.micro"
    

    tags = {
        Name: "web_server"
    }

    user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo my frist web server using terraform > /var/www/html/index.html'
              EOF
}

output "public_ip" {
    description = "public ip"
    value = aws_instance.web_server.public_ip
}
