module "terraform_pki" {
    # Only generate CA and certificates if no CA has been specified already
    count = var.certificate_authority_public_key_pem=="" ? 1 : 0
    source = "github.com/ethaden/terraform-local-pki.git"

    cert_path = "${var.generated_files_path}/certificates"
    organization = var.cert_organization
    ca_common_name = var.cert_ca_common_name
    client_names = var.cert_clients
    algorithm = "RSA"
    rsa_bits = 2048
    create_keystores = var.create_keystores
    include_ca_in_keystores = true
    keystore_passphrase = var.keystore_passphrase
}

# Create the certificate authority. Use a generic REST provider for now
resource "restapi_object" "certificate_authority" {
  path = "/iam/v2/certificate-authorities"
  #query_string = ""
  data = "${jsonencode(
    {
        "api_version" = "iam/v2",
        "kind" = "CreateCertRequest",
        "display_name" = "${var.certificate_authority_name}",
        "description" = "${var.certificate_authority_description}",
        "certificate_chain" = "${module.terraform_pki[0].ca_cert.cert_pem}",
        "certificate_chain_filename" = "ca_crt.pem",
        "crl_uri" = "",
        "crl_chain" = ""
    })}"
}

resource "restapi_object" "ca_identity_pool_readwrite" {
  path = "/iam/v2/certificate-authorities/${restapi_object.certificate_authority.id}/identity-pools"
  data = "${jsonencode(
    {
        "display_name" = "ReadWrite",
        "description" = "ReadWrite Access",
        "external_identifier" = "CN",
        "filter" = "SAN.contains(\"crn://DeveloperWriteTopicTest\")"
    })}"
}

resource "restapi_object" "ca_identity_pool_read" {
  path = "/iam/v2/certificate-authorities/${restapi_object.certificate_authority.id}/identity-pools"
  data = "${jsonencode(
    {
        "display_name" = "Read",
        "description" = "Read Access",
        "external_identifier" = "CN",
        "filter" = "SAN.contains(\"crn://DeveloperReadTopicTest\")"
    })}"
}

# This is similar to how it will work in the future. Currently not implemented
# resource "confluent_identity_pool" "ReadWrite" {
#   identity_provider {
#     id = restapi_object.certificate_authority.id
#   }
#   display_name    = "ReadWrite"
#   description     = "ReadWrite access to mtls test cluster"
#   identity_claim  = "CN"
#   filter          = "SAN.contains(\"crn://DeveloperWriteTopicTest\")"
# }

resource "confluent_role_binding" "role_binding_pool_readwrite" {
   principal = "User:${restapi_object.ca_identity_pool_readwrite.id}"
   role_name = "DeveloperWrite"
   crn_pattern = "${confluent_kafka_cluster.example_mtls_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_mtls_cluster.id}/topic=${confluent_kafka_topic.example_mtls_topic_test.topic_name}"
}

resource "confluent_role_binding" "role_binding_pool_read" {
   principal = "User:${restapi_object.ca_identity_pool_read.id}"
   role_name = "DeveloperRead"
   crn_pattern = "${confluent_kafka_cluster.example_mtls_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_mtls_cluster.id}/topic=${confluent_kafka_topic.example_mtls_topic_test.topic_name}"
}

#"{\"principal\":\"User:$USER_ID\",\"role_name\":\"$ROLE_NAME\",\"crn_pattern\":\"crn://confluent.cloud/organization=$ORG_ID/environment=$ENV_ID/cloud-cluster=$LKC_ID/kafka=$LKC_ID/topic=$TOPIC_NAME\"}"

resource "local_sensitive_file" "client_config_file" {
    for_each = var.create_keystores ? var.cert_clients : {}

    content = templatefile("${path.module}/templates/client.mtls.conf.tpl",
    {
        cluster_bootstrap_server = trimprefix("${confluent_kafka_cluster.example_mtls_cluster.bootstrap_endpoint}", "SASL_SSL://")
        topic = var.ccloud_cluster_topic
        client_name = each.key
        keystore_file = "./certificates/client_${each.key}.jks"
        keystore_passphrase = var.keystore_passphrase
        consumer_group_prefix = var.ccloud_cluster_consumer_group_prefix
    })
   filename = "${var.generated_files_path}/client-${each.key}-mtls.conf"
}
