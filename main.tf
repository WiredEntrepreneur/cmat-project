#####################
# Network
#####################

resource "aws_vpc" "sl-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "sl-vpc"
  }
}

resource "aws_subnet" "sl-subnet" {
  vpc_id                  = aws_vpc.sl-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  depends_on = [aws_vpc.sl-vpc]

  tags = {
    Name = "sl-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.sl-vpc.id

  depends_on = [aws_vpc.sl-vpc]

  tags = {
    Name = "sl-gw"
  }
}

resource "aws_route_table" "sl-route-table" {
  vpc_id = aws_vpc.sl-vpc.id

  tags = {
    Name = "sl-route-table"
  }
}

resource "aws_route" "sl-route" {
  route_table_id         = aws_route_table.sl-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sl-subnet.id
  route_table_id = aws_route_table.sl-route-table.id
}

#####################
# Security Group
#####################

variable "sg_ports" {
  type    = list(number)
  default = [22, 443, 80, 8080]
}

resource "aws_security_group" "sl-sg" {
  name        = "sl-sg"
  description = "Allow SSH/HTTP/HTTPS inbound and all outbound traffic"
  vpc_id      = aws_vpc.sl-vpc.id

  lifecycle {
    ignore_changes = [
      description,
      tags,
      tags_all
    ]
  }

  dynamic "ingress" {
    for_each = var.sg_ports
    iterator = ports

    content {
      from_port   = ports.value
      to_port     = ports.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#####################
# AMI
#####################

# data "aws_ami" "myami" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm*"]
#   }
# }
data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}


#####################
# EC2 instance
#####################

resource "aws_instance" "myec2" {
  ami           = data.aws_ami.myami.id
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.sl-subnet.id
  vpc_security_group_ids = [aws_security_group.sl-sg.id]

  # Use the key pair we created in mykey.tf
  key_name = aws_key_pair.aws-key.key_name

  tags = {
    Name = "terraform-instance"
  }

  # Optional: stop AMI refresh from forcing recreation
  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}

#####################
# Ansible inventory
#####################

resource "local_file" "inventory" {
  filename = "${path.module}/inventory.ini"

  content = <<EOF
[webserver]
${aws_instance.myec2.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${path.module}/web-key.pem ansible_python_interpreter=/usr/bin/python3 ansible_ssh_common_args='-o IdentitiesOnly=yes'
EOF
}
