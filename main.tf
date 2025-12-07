resource "aws_vpc" "sl-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "sl-vpc"
  }
}
resource "aws_subnet" "sl-subnet" {
  vpc_id = aws_vpc.sl-vpc.id
  cidr_block = "10.0.1.0/24"
  depends_on = [aws_vpc.sl-vpc]
  map_public_ip_on_launch = true
  tags = {
    Name = "sl-subnet"
  }
}
resource "aws_route_table" "sl-route-table" {
  vpc_id = aws_vpc.sl-vpc.id
  tags = {
    Name = "sl-route-table"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sl-subnet.id
  route_table_id = aws_route_table.sl-route-table.id
}




resource "aws_internet_gateway" "gw" {
  vpc_id     = aws_vpc.sl-vpc.id
  depends_on = [aws_vpc.sl-vpc]
  tags = {
    Name = "sl-gw"
  }
}
resource "aws_route" "sl-route" {
  route_table_id         = aws_route_table.sl-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}
variable "sg_ports" {
  type = list(number)
  default = [22, 443, 80, 8080]
}
resource "aws_security_group" "sl-sg" {
  name        = "sl-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.sl-vpc.id
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
data "aws_ami" "myami" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}
resource "aws_instance" "myec2" {
  ami             = data.aws_ami.myami.id
  instance_type   = "t2.micro"
  lifecycle {
  prevent_destroy = false
  ignore_changes = [
    ami,                 # prevent recreation because AMI changed
    user_data,           # prevent recreation when user_data changes
    tags,                # prevent recreation if tags change
  ]
  }

  key_name        = "web-key"
  subnet_id       = aws_subnet.sl-subnet.id
  security_groups = [aws_security_group.sl-sg.id]
  tags = {
    Name = "terraform-instance"
  }
   user_data = <<EOF
  #!/bin/bash
  mkdir -p /home/ec2-user/.ssh
  echo "${file("~/.ssh/id_ed25519.pub")}" >> /home/ec2-user/.ssh/authorized_keys
  chown -R ec2-user:ec2-user /home/ec2-user/.ssh
  chmod 600 /home/ec2-user/.ssh/authorized_keys
  EOF
}
resource "local_file" "inventory" {
  content = <<EOF
[webserver]
${aws_instance.myec2.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_python_interpreter=/usr/bin/python3.9 ansible_ssh_common_args='-o IdentitiesOnly=yes'
EOF

  filename = "${path.module}/inventory.ini"
}
