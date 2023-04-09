resource "null_resource" "multipass" {
  triggers = {
    name = var.name
  }

  provisioner "local-exec" {
    command    = "multipass launch --name ${var.name} -c${var.cores} -m${var.memory}GB -d${var.storage}GB --cloud-init ${var.userdata} --timeout 600 ${var.image}"
    on_failure = continue
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "multipass delete ${self.triggers.name} --purge"
    on_failure = continue
  }
}