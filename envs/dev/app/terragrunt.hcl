terraform {
  source = "${get_repo_root()}/modules/app"
}

inputs = {
  name               = "hello-world-codex-assignment"
  image              = "hashicorp/http-echo:1.0.0"
  replicas           = 1
  port               = 5678
  values_output_path = "${get_repo_root()}/helm/values-dev.yaml"
}