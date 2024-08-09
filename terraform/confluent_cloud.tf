# Confluent Cloud Kafka Cluster

# Set up a basic cluster (or a standard cluster, see below)
resource "confluent_kafka_cluster" "example_mtls_cluster" {
  display_name = var.ccloud_cluster_name
  availability = var.ccloud_cluster_availability
  cloud        = var.ccloud_cluster_cloud_provider
  region       = var.ccloud_cluster_region
  # Use standard if you want to have the ability to grant role bindings on topic scope
  # standard {}
  # For cost reasons, we use a basic cluster by default. However, you can choose a different type by setting the variable ccloud_cluster_type
  # As each different type is represented by a unique block in the cluster resource, we use dynamic blocks here.
  # Only exactly one can be active due to the way we've chosen the condition for "for_each"
  dynamic "basic" {
    for_each = var.ccloud_cluster_type=="basic" ? [true] : []
    content {
    }
  }
  dynamic "standard" {
    for_each = var.ccloud_cluster_type=="standard" ? [true] : []
    content {
    }
  }
  dynamic "enterprise" {
    for_each = var.ccloud_cluster_type=="enterprise" ? [true] : []
    content {
    }
  }
  dynamic "dedicated" {
    for_each = var.ccloud_cluster_type=="dedicated" ? [true] : []
    content {
        cku = var.ccloud_cluster_ckus
    }
  }
  dynamic "freight" {
    for_each = var.ccloud_cluster_type=="freight" ? [true] : []
    content {
    }
  }

  environment {
    id = var.ccloud_environment_id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Topic with configured name
resource "confluent_kafka_topic" "example_mtls_topic_test" {
  kafka_cluster {
    id = confluent_kafka_cluster.example_mtls_cluster.id
  }
  topic_name         = var.ccloud_cluster_topic
  rest_endpoint      = confluent_kafka_cluster.example_mtls_cluster.rest_endpoint
  partitions_count = 1
  credentials {
    key    = confluent_api_key.example_mtls_api_key_sa_cluster_admin.id
    secret = confluent_api_key.example_mtls_api_key_sa_cluster_admin.secret
  }

  # Required to make sure the role binding is created before trying to create a topic using these credentials
  depends_on = [ confluent_role_binding.example_mtls_role_binding_cluster_admin ]

  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the cluster admin
resource "confluent_service_account" "example_mtls_sa_cluster_admin" {
  display_name = "${local.resource_prefix}_example_mtls_sa_cluster_admin"
  description  = "Service Account mTLS Example Cluster Admin"
}

# An API key with Cluster Admin access. Required for provisioning the cluster-specific resources such as our topic
resource "confluent_api_key" "example_mtls_api_key_sa_cluster_admin" {
  display_name = "${local.resource_prefix}_example_mtls_api_key_sa_cluster_admin"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_mtls_sa_cluster_admin' service account"
  owner {
    id          = confluent_service_account.example_mtls_sa_cluster_admin.id
    api_version = confluent_service_account.example_mtls_sa_cluster_admin.api_version
    kind        = confluent_service_account.example_mtls_sa_cluster_admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.example_mtls_cluster.id
    api_version = confluent_kafka_cluster.example_mtls_cluster.api_version
    kind        = confluent_kafka_cluster.example_mtls_cluster.kind

    environment {
      id = var.ccloud_environment_id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Assign the CloudClusterAdmin role to the cluster admin service account
resource "confluent_role_binding" "example_mtls_role_binding_cluster_admin" {
  principal   = "User:${confluent_service_account.example_mtls_sa_cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.example_mtls_cluster.rbac_crn
  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the producer
resource "confluent_service_account" "example_mtls_sa_producer" {
  display_name = "${local.resource_prefix}_example_mtls_sa_producer"
  description  = "Service Account mTLS Example Producer"
}

resource "confluent_api_key" "example_mtls_api_key_producer" {
  display_name = "${local.resource_prefix}_example_mtls_api_key_producer"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_mtls_sa' service account"
  owner {
    id          = confluent_service_account.example_mtls_sa_producer.id
    api_version = confluent_service_account.example_mtls_sa_producer.api_version
    kind        = confluent_service_account.example_mtls_sa_producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.example_mtls_cluster.id
    api_version = confluent_kafka_cluster.example_mtls_cluster.api_version
    kind        = confluent_kafka_cluster.example_mtls_cluster.kind

    environment {
      id = var.ccloud_environment_id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# For role bindings such as DeveloperRead and DeveloperWrite at least a standard cluster type would be required. We use ACLs instead for basic clusters
resource "confluent_role_binding" "example_mtls_role_binding_producer" {
  # Instaniciate this block only if the cluster type is NOT basic
  count = var.ccloud_cluster_type=="basic" ? 0 : 1
  principal   = "User:${confluent_service_account.example_mtls_sa_producer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.example_mtls_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_mtls_cluster.id}/topic=${confluent_kafka_topic.example_mtls_topic_test.topic_name}"
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_kafka_acl" "example_mtls_acl_producer" {
  # Instaniciate this block only if the cluster type IS basic
  count = var.ccloud_cluster_type=="basic" ? 1 : 0
  kafka_cluster {
     id = confluent_kafka_cluster.example_mtls_cluster.id
  }
  rest_endpoint  = confluent_kafka_cluster.example_mtls_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.example_mtls_topic_test.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.example_mtls_sa_producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  credentials {
    key    = confluent_api_key.example_mtls_api_key_sa_cluster_admin.id
    secret = confluent_api_key.example_mtls_api_key_sa_cluster_admin.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the consumer
resource "confluent_service_account" "example_mtls_sa_consumer" {
  display_name = "${local.resource_prefix}_example_mtls_sa_consumer"
  description  = "Service Account mTLS Lambda Example Consumer"
}


resource "confluent_api_key" "example_mtls_api_key_consumer" {
  display_name = "${local.resource_prefix}_example_mtls_api_key_consumer"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_mtls_sa' service account"
  owner {
    id          = confluent_service_account.example_mtls_sa_consumer.id
    api_version = confluent_service_account.example_mtls_sa_consumer.api_version
    kind        = confluent_service_account.example_mtls_sa_consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.example_mtls_cluster.id
    api_version = confluent_kafka_cluster.example_mtls_cluster.api_version
    kind        = confluent_kafka_cluster.example_mtls_cluster.kind

    environment {
      id = var.ccloud_environment_id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# For role bindings such as DeveloperRead and DeveloperWrite at least a standard cluster type would be required. Let's use ACLs instead
resource "confluent_role_binding" "example_mtls_role_binding_consumer" {
  # Instaniciate this block only if the cluster type is NOT basic
  count = var.ccloud_cluster_type=="basic" ? 0 : 1
  principal   = "User:${confluent_service_account.example_mtls_sa_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.example_mtls_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_mtls_cluster.id}/topic=${confluent_kafka_topic.example_mtls_topic_test.topic_name}"
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_role_binding" "example_mtls_role_binding_consumer_group" {
  # Instaniciate this block only if the cluster type is NOT basic
  count = var.ccloud_cluster_type=="basic" ? 0 : 1
  principal   = "User:${confluent_service_account.example_mtls_sa_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.example_mtls_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_mtls_cluster.id}/group=${var.ccloud_cluster_consumer_group_prefix}*"
  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "example_mtls_acl_consumer" {
  # Instaniciate this block only if the cluster type IS basic
  count = var.ccloud_cluster_type=="basic" ? 1 : 0

  kafka_cluster {
     id = confluent_kafka_cluster.example_mtls_cluster.id
  }
  rest_endpoint  = confluent_kafka_cluster.example_mtls_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.example_mtls_topic_test.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.example_mtls_sa_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  credentials {
    key    = confluent_api_key.example_mtls_api_key_sa_cluster_admin.id
    secret = confluent_api_key.example_mtls_api_key_sa_cluster_admin.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "example_mtls_acl_consumer_group" {
  # Instaniciate this block only if the cluster type IS basic
  count = var.ccloud_cluster_type=="basic" ? 1 : 0

  kafka_cluster {
    id = confluent_kafka_cluster.example_mtls_cluster.id
  }
  rest_endpoint  = confluent_kafka_cluster.example_mtls_cluster.rest_endpoint
  resource_type = "GROUP"
  resource_name = var.ccloud_cluster_consumer_group_prefix
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.example_mtls_sa_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  credentials {
    key    = confluent_api_key.example_mtls_api_key_sa_cluster_admin.id
    secret = confluent_api_key.example_mtls_api_key_sa_cluster_admin.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}

output "cluster_bootstrap_server" {
   value = confluent_kafka_cluster.example_mtls_cluster.bootstrap_endpoint
}
output "cluster_rest_endpoint" {
    value = confluent_kafka_cluster.example_mtls_cluster.rest_endpoint
}

# The next entries demonstrate how to output the generated API keys to the console even though they are considered to be sensitive data by Terraform
# Uncomment these lines if you want to generate that output
# output "cluster_api_key_admin" {
#     value = nonsensitive("Key: ${confluent_api_key.example_mtls_api_key_sa_cluster_admin.id}\nSecret: ${confluent_api_key.example_mtls_api_key_sa_cluster_admin.secret}")
# }

# output "cluster_api_key_producer" {
#     value = nonsensitive("Key: ${confluent_api_key.example_mtls_api_key_producer.id}\nSecret: ${confluent_api_key.example_mtls_api_key_producer.secret}")
# }

# output "cluster_api_key_consumer" {
#     value = nonsensitive("Key: ${confluent_api_key.example_mtls_api_key_consumer.id}\nSecret: ${confluent_api_key.example_mtls_api_key_consumer.secret}")
# }

# Generate console client configuration files for testing in subfolder "generated/client-configs"
# PLEASE NOTE THAT THESE FILES CONTAIN SENSITIVE CREDENTIALS
resource "local_sensitive_file" "client_config_files" {
  # Do not generate any files if var.ccloud_cluster_generate_client_config_files is false
  for_each = var.ccloud_cluster_generate_client_config_files ? {
    "admin" = confluent_api_key.example_mtls_api_key_sa_cluster_admin,
    "producer" = confluent_api_key.example_mtls_api_key_producer,
    "consumer" = confluent_api_key.example_mtls_api_key_consumer} : {}

  content = templatefile("${path.module}/templates/client.conf.tpl",
  {
    client_name = "${each.key}"
    cluster_bootstrap_server = trimprefix("${confluent_kafka_cluster.example_mtls_cluster.bootstrap_endpoint}", "SASL_SSL://")
    api_key = "${each.value.id}"
    api_secret = "${each.value.secret}"
    topic = var.ccloud_cluster_topic
  }
  )
  filename = "${var.generated_files_path}/client-configs/client-${each.key}.conf"
}
