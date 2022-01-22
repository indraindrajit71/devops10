terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

## Configuring the AWS provider

provider "aws" {
  region = "us-east-1"
}

## Configuring the VPC

resource "aws_vpc" "my-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "MyVPC"
  }
}

## Configuring the Subnets

resource "aws_subnet" "my-subnet" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.6.0/24"

  tags = {
    Name = "MySubnet"
  }
}

## Configuring the InternetGateway

resource "aws_internet_gateway" "my-gw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "MyGateway"
  }
}

## Configuring the Route Table

resource "aws_route_table" "My-Route" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.my-gw.id
    
  }

  tags = {
    Name = "myownRoute"
  }
}

## RouteTable Association

resource "aws_route_table_association" "myrouteassociation" {
  subnet_id      = aws_subnet.my-subnet.id
  route_table_id = aws_route_table.My-Route.id
}

## Configuring SecurityGroup

resource "aws_security_group" "mySecurityGroup" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "TomcatPort from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "MySecurityGroup"
  }
}

## Configure NetworkInterface

resource "aws_network_interface" "myinterface" {
  subnet_id       = aws_subnet.my-subnet.id
  private_ips     = ["10.0.6.55"]
  security_groups = [aws_security_group.mySecurityGroup.id]

/*   attachment {
    instance     = aws_instance.test.id
    device_index = 1
  } */
}

## configuring Elastic/Public IP

resource "aws_eip" "MyElasticIP" {
  vpc                       = true
  network_interface         = aws_network_interface.myinterface.id
  associate_with_private_ip = "10.0.6.55"
  depends_on = [
    aws_internet_gateway.my-gw,aws_instance.webInstance
  ]
}

## Configuring AWS Ubuntu Instance

resource "aws_instance" "webInstance" {
  ami           = "ami-0e472ba40eb589f49"
  instance_type = "t2.micro"
  key_name = "jenkins"
  availability_zone = "us-east-1e"
  network_interface {
    network_interface_id = aws_network_interface.myinterface.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c "echo Hey Folks, this is the first web Instance > /var/www/html/index.html"
              EOF

  tags = {
    Name = "HelloWorld-WebInstance"
  }
}


