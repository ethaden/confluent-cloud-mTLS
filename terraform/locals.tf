# Run the script to get the environment variables of interest.
# This is a data source, so it will run at plan time.
data "external" "env" {
  program = ["${path.module}/locals-from-env.sh"]

  # For Windows (or Powershell core on MacOS and Linux),
  # run a Powershell script instead
  #program = ["${path.module}/env.ps1"]
}

locals {
    confluent_tags = {
        owner = var.owner!="" ? var.owner : data.external.env.result["user"]
        owner_fullname = var.owner_fullname!="" ? var.owner_fullname : data.external.env.result["owner_fullname"]
        owner_email = var.owner_email!="" ? var.owner_email : data.external.env.result["owner_email"]
        tf_last_updated = var.tf_last_updated!="" ? var.tf_last_updated : data.external.env.result["current_datetime"]
        divvy_last_modified_by = var.owner_email!="" ? var.owner_email : data.external.env.result["owner_email"]
    }
    # Comment the next four lines if this project is not using Confluent Cloud
    confluent_creds = {
        api_key = data.external.env.result["api_key"]
        api_secret = data.external.env.result["api_secret"]
    }

    username = var.username!="" ? var.username : data.external.env.result["user"]
    resource_prefix = var.resource_prefix!="" ? var.resource_prefix : local.username
}

output "confluent_tags" {
    value = local.confluent_tags
}
