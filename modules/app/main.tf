resource "local_file" "values" {
  filename = var.values_output_path
  content = templatefile("${path.module}/templates/values.tpl", {
    name     = var.name
    image    = var.image
    replicas = var.replicas
    port     = var.port
  })
}