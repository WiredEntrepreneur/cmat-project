resource "null_resource" "wait_for_ssh" {
  triggers = {
    instance_ip = aws_instance.myec2.public_ip
  }

  provisioner "local-exec" {
    command = "until ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -i ${path.module}/web-key.pem ec2-user@${aws_instance.myec2.public_ip} 'echo ssh_ready' >/dev/null 2>&1; do echo 'Waiting for SSH...'; sleep 5; done"
  }
}

resource "null_resource" "run_playbook" {
  depends_on = [
    null_resource.wait_for_ssh,
    local_file.inventory
  ]

  triggers = {
    instance_id = aws_instance.myec2.id
    instance_ip = aws_instance.myec2.public_ip
    playbook_sha = filesha1("${path.module}/playbook.yml")
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbook.yml"
  }
}