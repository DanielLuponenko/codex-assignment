terraform {
  source = "${get_repo_root()}/modules/app"
}

inputs = {
  name               = "hello-world-codex-assignment"
  image              = "nginx:alpine"
  replicas           = 1
  port               = 80
  values_output_path = "${get_repo_root()}/helm/values-dev.yaml"
}