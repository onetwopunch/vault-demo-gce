variable "project" {
  description = "The GCP project ID"
}

variable "network" {
  description = <<EOF
To get the network from the google-private-vault project:
cd google-private-vault
terraform state show google_compute_network.vault-network | egrep "^self_link" | cut -f2 -d=
EOF
}

variable "subnetwork" {
  description = <<EOF
To get the network from the google-private-vault project:
cd google-private-vault
terraform state show google_compute_subnetwork.vault-subnet | egrep "^self_link" | cut -f2 -d=
EOF
}

variable "vault_tls_bucket" {
  description = <<EOF
The bucket where the TLS ca.crt for Vault is stored, unless you passed in your own, it will be found in the google-private-project:
cd google-private-vault
terraform state show google_storage_bucket.vault | egrep "^name" | cut -f2 -d=
EOF
}

variable "region" {
  default = "us-east4"
}
variable "roles" {
  default = [
    "roles/storage.objectViewer",
    "roles/iam.serviceAccountTokenCreator",
  ]
}
variable "vault_ca_cert_filename" {
  default = "ca.crt"
}

variable "vault_address" {
  default = "https://10.127.13.37:8200"
}

variable "vault_version" {
  default = "1.1.2"
}
