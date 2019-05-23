# Vault GCE Auth Demo

Designed as a demo to be used in conjunction with [`google-private-vault`](https://github.com/onetwopunch/google-private-vault)

## Permissions

1. The Vault cluster needs access to `compute.instances.get`, so for this demo we'll just give it access to `roles/compute.viewer` this is not actually in the docs
2. The Vault cluster (according to the docs) also needs access to `roles/iam.serviceAccountKeyAdmin` and `roles/browser`
3. The Client node needs to be able to sign a JWT token to identify itself with Vault so it needs `roles/iam.serviceAccountTokenCreator`
4. In this exercise we're also going to be pulling a public CA cert for TLS authentication/encryption with Vault, which is stored in a bucket we created in the [`google-private-vault`](https://github.com/onetwopunch/google-private-vault) module

To avoid modifying terraform code on the `google-private-vault` module, you can just pass in these values into `terraform.tfvars` and run apply again on that module to add the right permissions to an exiting cluster:
```
service_account_project_additional_iam_roles = [
  "roles/iam.serviceAccountKeyAdmin",
  "roles/compute.viewer",
  "roles/browser"
]
allowed_service_accounts = [
  "vault-demo-client@[PROJECT].iam.gserviceaccount.com"
]
```

The necessary roles for this project are all default variables.


### 1. Log Into Vault Bastion

```
gcloud beta compute ssh vault-bastion --tunnel-through-iap
```

### 2. Create a `policy.hcl`

This is the new formate for generic secrets. When migrating to `kv` v2, you'll need
to add a `data` path to your policies. This is outlined [in the docs](https://www.vaultproject.io/docs/secrets/kv/kv-v2.html#acl-rules).

```
path "kv-v2/data/client/api-token" {
  capabilities = ["read"]
}
```

### 3. Configure Vault and store a secret for our client

```
# Enable the GCP auth backend
vault auth enable gcp

# Enable the KV backend to store and retrieve secrets
vault secrets enable kv-v2

# Create the policy for our client program
vault policy write client policy.hcl

# Create a role for our client function specifying the policy
vault write auth/gcp/role/client-role \
	type="gce" \
	policies="client" \
	bound_projects="$PROJECT" \
	bound_service_accounts="vault-demo-client@$PROJECT.iam.gserviceaccount.com"

# Store a value where the client can read it
vault kv put kv-v2/client/api-token value='Super Secret API String'
```

### 4. Run Terraform Apply

```
cd vault-demo-gce
terraform apply
```

### 5. Log into the newly created client instance

```
gcloud beta compute ssh vault-demo --tunnel-through-iap
```

### 6. Ensure vault agent is running

```
sudo systemctl status vault-agent
```

### 7. Now let's pretend to be a client process and get a secret

This user could be something like `tomcat` or some other process that would need access to Vault secrets.

```
sudo -su demo-client
```

If you list your home directory, you can see `vault agent` already authenticated and stored the service's `.vault-token` where it needs to be for authentication. This is part of that `templates/agent.hcl` file in this repo.

```
$ cd && ls -la
total 16
drwxrwxr-x 2 demo-client vault-users 4096 May 23 04:33 .
drwxr-xr-x 3 root        root        4096 May 23 04:16 ..
-rw-r----- 1 vault-agent vault-agent   26 May 23 04:30 .vault-token
```

As this vault user, lets' try to grab the secret that we created in the Bastion. First let's source the environment file that was created at startup and then do the kv get operation.

```
source /etc/vault/vault.env
vault kv get kv-v2/client/api-token
====== Metadata ======
Key              Value
---              -----
created_time     2019-05-23T04:46:37.141839758Z
deletion_time    n/a
destroyed        false
version          1

==== Data ====
Key      Value
---      -----
value    Super Secret API String
```
