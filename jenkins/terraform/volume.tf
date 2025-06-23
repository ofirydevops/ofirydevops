data "aws_availability_zones" "azs" {}

locals {
    jenkins_volume_az = data.aws_availability_zones.azs.names[0]
    jenkins_volume_id = aws_ebs_volume.jenkins.id
    jenkins_ebs_volume_size_gb = 20

}

resource "aws_ebs_volume" "jenkins" {
  availability_zone = local.jenkins_volume_az
  size              = local.jenkins_ebs_volume_size_gb
  tags = {
    Name = "${local.namespace}_jenkins_volume"
  }
}
