provider "google" {
  project = "${var.project}"
  region = "${var.region}"
}

resource "google_service_account" "client" {
  account_id   = "vault-demo-client"
  display_name = "Vault Client"
}

# Give ability of the client to pull CA.crt. Note this will also give
# the bastion the ability to see the vault.key.enc, but it will not
# have the ability to decrypt, so it shouldn't matter.
resource "google_project_iam_member" "client-iam" {
  count   = "${length(var.roles)}"
  role    = "${element(var.roles, count.index)}"
  member  = "serviceAccount:${google_service_account.client.email}"
}

resource "google_compute_instance" "client" {
  project     = "${var.project}"
  zone         = "${var.region}-a"
  name        = "vault-demo"

  machine_type = "n1-standard-1"
  network_interface {
    subnetwork         = "${var.subnetwork}"
    subnetwork_project = "${var.project}"
  }

  service_account {
    email  = "${google_service_account.client.email}"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  scratch_disk {}
  metadata_startup_script = "${data.template_file.client-startup-script.rendered}"
}

data "template_file" "vault-agent-systemd" {
  template = "${file("${path.module}/templates/vault-agent.service")}"
}

data "template_file" "agent-config" {
  template = "${file("${path.module}/templates/agent.hcl")}"

  vars {
    vault_address = "${var.vault_address}"
  }
}

data "template_file" "client-startup-script" {
  template = "${file("${path.module}/templates/startup.sh")}"

  vars {
    agent_config            = "${data.template_file.agent-config.rendered}"
    vault_systemd           = "${data.template_file.vault-agent-systemd.rendered}"
    vault_version           = "${var.vault_version}"

    vault_tls_bucket        = "${var.vault_tls_bucket}"
    vault_ca_cert_filename  = "${var.vault_ca_cert_filename}"
  }
}

resource "google_compute_firewall" "allow-ssh" {
  project = "${var.project}"
  name    = "demo-client-allow-ssh"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Allow SSH only from IAP
  source_ranges = ["35.235.240.0/20"]
  target_service_accounts = ["${google_service_account.client.email}"]
}
