module "terraform_pki" {
    source = "github.com/ethaden/terraform-local-pki.git"

    cert_path = "${var.generated_files_path}/certificates"
    organization = var.cert_organization
    ca_common_name = var.cert_ca_common_name
    client_names = var.cert_clients
    algorithm = "RSA"
    rsa_bits = 2048
    create_keystores = var.create_keystores
    keystore_passphrase = var.keystore_passphrase
}

# resource "local_sensitive_file" "aws_openvpn_config_files" {
#   for_each = toset(var.cert_clients)

#   #content  = template_file.aws_openvpn_configs[each.key].rendered
#   content = templatefile("${path.module}/templates/aws-openvpn-config.tpl",
#   {
#     vpn_gateway_endpoint = aws_ec2_client_vpn_endpoint.vpn.dns_name,
#     ca_cert_pem = "${module.terraform_pki.ca_cert.cert_pem}",
#     client_cert_pem = module.terraform_pki.client_certs[each.key].cert_pem,
#     client_key_pem = module.terraform_pki.client_keys[each.key].private_key_pem
#   }
#   )
#   filename = "${var.generated_files_path}/client-configs/client-${each.key}.conf"
# }
