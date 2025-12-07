provider "aws" {
  region = "us-east-1"
}


resource "tls_private_key" "mykey" {
  algorithm = "RSA"
}


resource "aws_key_pair" "aws-key" { # Create a "web-key" for AWS!!
  key_name   = "web-key"        
  public_key = tls_private_key.mykey.public_key_openssh


  provisioner "local-exec" { # Create "web-key.pem" on your computer!!
    command = "echo '${tls_private_key.mykey.private_key_pem}' > ./web-key.pem" && chmod 600 ./web-key.pem"
  }
}

