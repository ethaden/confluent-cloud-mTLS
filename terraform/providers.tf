terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
      version = "2.32.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = local.confluent_creds.api_key
  cloud_api_secret = local.confluent_creds.api_secret
}
