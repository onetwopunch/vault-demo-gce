vault {
  address = "${vault_address}"
  ca_cert = "/etc/vault/ca.crt"
}

auto_auth {
  method "gcp" {
    config {
      type = "gce"
      role = "client-role"
    }
  }

  sink "file" {
    config {
      path = "/opt/demo-client/.vault-token"
    }
  }
}
