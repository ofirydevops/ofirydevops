locals {

    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))

    codeartifact_domains = {
        batch_runner = {
            name = "batch-runner"
        }
    }

    codeartifact_repos = {
        batch_runner = {
            ssm_param   = "/codeartifact/batch_runner_main"
            repo_name   = "main"
            domain      = aws_codeartifact_domain.main["batch_runner"]
            package_dir = "${path.module}/../../batch_runner/py_lib"
        }
    }

    codeartifact_packages_files = {
        for k, v in local.codeartifact_repos: k => merge(v, { package_files = fileset(v.package_dir, "**/*.py") })
    }


    codeartifact_packages_contents = {
        for k, v in local.codeartifact_packages_files: k => join("",[for file in v.package_files : file("${v.package_dir}/${file}")])
    }

    codeartifact_packages_hashes = {
        for k, v in local.codeartifact_packages_contents: k => sha256(v)
    }
}


resource "aws_codeartifact_domain" "main" {
    for_each = local.codeartifact_domains
    domain   = each.value.name
}

resource "aws_codeartifact_repository" "main" {
    for_each = local.codeartifact_repos
    repository = each.value.repo_name
    domain     = each.value.domain.domain
}

resource "aws_ssm_parameter" "codeartifact_params" {
    for_each = local.codeartifact_repos
    name     = each.value.ssm_param
    type     = "String"
    value    = jsonencode({
        domain  = each.value.domain.domain
        owner   = each.value.domain.owner
        repo    = aws_codeartifact_repository.main[each.key].repository
        region  = local.global_conf["region"]
        profile = local.global_conf["profile"]
    })
}


resource "null_resource" "upload_py_lib_to_codeartifact" {
    for_each = local.codeartifact_repos
    depends_on = [
        aws_codeartifact_repository.main
    ]
    triggers = {
        hash = local.codeartifact_packages_hashes[each.key]
    }
    provisioner "local-exec" {
        environment = {
            CODEARTIFACT_DOMAIN       = each.value.domain.domain
            CODEARTIFACT_REPO         = each.value.repo_name
            CODEARTIFACT_DOMAIN_OWNER = each.value.domain.owner
            REGION                    = local.global_conf["region"]
            PROFILE                   = local.global_conf["profile"]
            PACKAGE_DIR               = each.value.package_dir
        }
        command = "${path.module}/upload_python_lib_to_codeartifact.sh"
    }
}

