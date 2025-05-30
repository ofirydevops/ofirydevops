locals { 
    docker_dep_files = [
      "${path.module}/../child/ci/docker/Dockerfile",
      "${path.module}/../child/main.py",
      "${path.module}/../utils.py",
      "${path.module}/../cnfg.py",
      "${path.module}/../../Pipfile",
      "${path.module}/../../Pipfile.lock"
    ]

    docker_dep_files_content      = [for file in local.docker_dep_files : file(file)]
    docker_dep_files_content_hash = sha256(join("", local.docker_dep_files_content))
    child_wrapper_ecr_repo_url    = aws_ecr_repository.child_runner_wrapper.repository_url
    child_wrapper_image_tag       = "batch_child_wrapper_${substr(local.docker_dep_files_content_hash, 0, 15)}"
    child_wrapper_image           = "${local.child_wrapper_ecr_repo_url}:${local.child_wrapper_image_tag}"
}

resource "null_resource" "child_wrapper_images_docker_build_and_push" {
  depends_on = [
    aws_ecr_repository.child_runner_wrapper
  ]
  triggers = {
    hash = local.docker_dep_files_content_hash
  }
  provisioner "local-exec" {
    environment = {
      PROFILE             = local.global_conf["profile"]
      REGION              = local.global_conf["region"]
      DOCKER_IMAGE        = local.child_wrapper_image
      DOCKER_REGISTRY     = split("/", local.child_wrapper_ecr_repo_url)[0]
      DOCKER_COMPOSE_PATH = "${path.module}/../child/ci/docker/docker-compose.yml"
      DOCKER_BUILDKIT     = "1"
      BUILDX_BAKE_ENTITLEMENTS_FS = "0"
    }
    command = "${path.module}/build_and_push.sh"
  }
}


resource "aws_ecr_repository" "child_runner_wrapper" {
    name                 = "batch_runner_wrapper"
    image_tag_mutability = "MUTABLE"
    force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "child_runner_wrapper" {
    repository               = aws_ecr_repository.child_runner_wrapper.name
    policy                   = templatefile("${path.module}/ecr_lifecycle_policy.json", {
      tag_prefix             = local.image_tag_prefix
    })
}