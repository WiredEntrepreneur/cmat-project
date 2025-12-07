resource "null_resource" "run_playbook" {

  triggers = {
    instance_id = aws_instance.myec2.id
    instance_ip = aws_instance.myec2.public_ip
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml"
  }
}

