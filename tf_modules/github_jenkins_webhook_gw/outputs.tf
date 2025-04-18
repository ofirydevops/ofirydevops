output "auth_lambda_zip_name" {
  value = local.lambdas["gh_jenkins_webhook_auth"]["output_zip_path"] 
}