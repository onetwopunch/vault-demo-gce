#!/usr/bin/env bash
set -xe
set -o pipefail

if [ -f ~/.startup-script-complete ]; then
	echo "Startup script has already run. Exiting..."
	exit 0
fi

apt update
apt install -y jq zip curl

# Download Vaults self signed root TLS cert
mkdir -p /etc/vault/
gsutil cp gs://${vault_tls_bucket}/${vault_ca_cert_filename} /etc/vault/ca.crt

# Setup an environment file for ease of use
cat << EOF > /etc/vault/vault.env
export VAULT_ADDR=https://10.127.13.37:8200
export VAULT_CACERT=/etc/vault/ca.crt
EOF

# Install Vault
curl -o /tmp/vault.zip "https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip"
pushd /tmp
unzip vault.zip
mv vault /usr/local/bin/
rm vault.zip
popd

# Add a user for the Vault agent process
useradd -s /bin/false vault-agent
# And one for our demo-client
useradd -d /opt/demo-client -s /bin/false -G vault-agent demo-client
# Then create the home directory for this service where the vault token
# will be stored.
mkdir -p /opt/demo-client
chmod 0770 /opt/demo-client
chown -R demo-client:vault-agent /opt/demo-client

# Vault agent config
# NOTE: We could also login by requesting a signed JWT from the metadata server:
# curl -H "Metadata-Flavor: Google" 'http://metadata/computeMetadata/v1/instance/service-accounts/default/identity?audience=auth/gcp/login'
mkdir -p /etc/vault
cat <<"EOF" > /etc/vault/agent.hcl
${agent_config}
EOF

chmod 0600 /etc/vault/agent.hcl
chown -R vault-agent:vault-agent /etc/vault
# Create Vault agent systemd service
cat <<"EOF" > /etc/systemd/system/vault-agent.service
${vault_systemd}
EOF


# Start the vault agent
chmod 0644 /etc/systemd/system/vault-agent.service
systemctl daemon-reload
systemctl enable vault-agent

# Let the system know not to run the startup script again
touch ~/.startup-script-complete
reboot
