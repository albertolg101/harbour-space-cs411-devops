# Prompts and Answers

## Deployment to Cloud (EC2 via Terraform)

**Prompt:** Read the current state of the repository and tell me what steps am I missing for deploying to EC2.

**Answer:** The Terraform config was missing a security group (tcp/22 and tcp/4444), an SSH key pair, and an output for the public IP. The Jenkinsfile had broken `withCredentials` syntax in the Deploy stage (mixed `sshUserPrivateKey` with `string` bindings) and a leftover old deploy command referencing variables that no longer existed.

**Prompt:** Why `aws-access-key-id` and not `aws-access-key`?

**Answer:** The credential ID is an arbitrary string chosen when creating the credential in Jenkins. It just needs to match between Jenkins and the Jenkinsfile. It has no relation to AWS naming conventions.

**Prompt:** Why not change the environment variable name?

**Answer:** `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are the standard names that AWS SDKs and tools (including Terraform) look for. Changing them would break Terraform's ability to authenticate.

**Prompt:** Explain what each entry in `main.tf` does.

**Answer:**

- `terraform {}` — pins provider versions and configures S3 backend for shared state
- `provider "aws"` — sets the AWS region (eu-west-3), auth comes from env vars
- `data "aws_ami" "ubuntu"` — looks up the latest Ubuntu 24.04 AMI from Canonical
- `tls_private_key` — generates an RSA key pair in memory (later removed in favor of Jenkins-managed keys)
- `aws_key_pair` — registers a public key with AWS under a name
- `local_file` — writes the private key to disk (later removed)
- `aws_security_group` — firewall rules: SSH and app port 4444 inbound, all outbound
- `aws_instance` — launches the EC2 instance with the AMI, key pair, and security group
- `output "public_ip"` — exposes the instance IP so the Deploy stage can read it

**Prompt:** What does `resource "aws_key_pair" "deployer"` mean?

**Answer:** `aws_key_pair` is the resource type — it tells Terraform which AWS API to call (EC2 Key Pairs). `"deployer"` is the local name — an arbitrary label used only within Terraform to reference this resource (e.g. `aws_key_pair.deployer.key_name`). AWS never sees the local name.

**Prompt:** Is the private key stored in S3?

**Answer:** Indirectly, yes. The `tls_private_key` resource stores its private key material in Terraform's state file, and the state file lives in the S3 bucket. Anyone with access to the bucket can read the state and extract the private key. The state is encrypted at rest (`encrypt = true`), but it's a known tradeoff.

**Prompt:** Is there a better solution for this task's scope?

**Answer:** Two options: (A) create the key pair in the AWS console manually and reference it by name in Terraform, or (B) use `tls_private_key` in Terraform. Option B is fully automated but stores the key in state. For a class project with a private S3 bucket, either works.

**Prompt:** Can we manage the SSH key without Terraform generating it?

**Answer:** Yes. Generate the key locally with `ssh-keygen`, upload the private key to Jenkins as an SSH credential, and have Terraform register the public key with AWS. The public key is derived at runtime using `ssh-keygen -y -f $SSH_KEY` and passed to Terraform as a variable.

**Prompt:** How does Terraform know which machine to deploy the SSH key to?

**Answer:** It doesn't deploy to a specific machine. `aws_key_pair` just registers the public key with AWS. The `aws_instance` resource references that key pair via `key_name`, and AWS injects the public key into the instance's `authorized_keys` at boot via cloud-init.

**Prompt:** What does the `aws_instance` resource do?

**Answer:** Creates the EC2 instance. `ami` is the OS image (Ubuntu 24.04), `instance_type` is the hardware size (t2.micro, free tier), `key_name` is which SSH key pair to inject at boot, `vpc_security_group_ids` is the firewall rules to attach, and `tags` sets the display name in the AWS console.

**Prompt:** What does the `data "aws_ami"` block do?

**Answer:** A read-only lookup that queries AWS for the latest Ubuntu 24.04 AMI published by Canonical (owner `099720109477`). `most_recent = true` picks the newest match. The filter narrows by AMI name pattern. This avoids hardcoding an AMI ID that varies by region and goes stale.

**Prompt:** What does `ssh-keygen -N ""` stand for?

**Answer:** `-N ""` sets an empty passphrase on the key. Without it, `ssh-keygen` would prompt interactively. Empty passphrase is needed for automated use in Jenkins.

**Prompt:** What does `ssh-keygen -f` stand for?

**Answer:** `-f` specifies the output filename for the key. Without it, `ssh-keygen` would prompt for a path (defaulting to `~/.ssh/id_rsa`).

**Prompt:** I still don't understand how Provision has access to the public key.

**Answer:** It didn't — the `aws_instance` referenced a key name that didn't exist in AWS. The solution: Jenkins holds the private key as a credential, the Provision stage extracts the public key at runtime with `ssh-keygen -y -f $SSH_KEY`, and passes it to Terraform as a variable. Terraform creates the `aws_key_pair` with that public key.

**Prompt:** Can we take the public key from a Jenkins variable as well?

**Answer:** You could store it as a separate secret, but then you have two credentials for the same key pair that must stay in sync. Deriving it from the private key with `ssh-keygen -y -f` is simpler: one credential, no duplication.

**Prompt:** What does `ssh-keygen -y -f` do?

**Answer:** `-f` specifies the file to read from, `-y` tells `ssh-keygen` to extract the public key from a private key file instead of generating a new pair.

**Prompt:** Remind me the command to create the key pair.

**Answer:** `ssh-keygen -t rsa -b 4096 -f cs411-cicd-ssh-key.pem -N ""` — creates the private key and a `.pub` file alongside it.

**Prompt:** How do I login with a profile to run `terraform init`?

**Answer:** `AWS_PROFILE=your-profile-name terraform init`, or `export AWS_PROFILE=your-profile-name` before running commands.

**Prompt:** I'm getting an `InvalidClientTokenId` error on `terraform init`.

**Answer:** AWS credentials are invalid or expired. Verify with `aws sts get-caller-identity --profile your-profile-name`. If that fails, generate new access keys in the AWS console (IAM → Users → Security credentials) and update with `aws configure --profile your-profile-name`.

**Prompt:** `terraform --chdir=terraform init` gives "Invalid flags before the subcommand".

**Answer:** Terraform uses a single dash: `-chdir`, not `--chdir`.

**Prompt:** Restrict tcp/22 to my laptop's current IP.

**Answer:** Updated the security group SSH ingress to use the laptop's current public IP with a `/32` CIDR.

**Prompt:** Do I have to leak my IP in the committed code?

**Answer:** No. The IP is stored as a Jenkins secret (`ssh-allowed-ip`) and passed to Terraform at runtime as `-var "ssh_allowed_cidr=$MY_IP/32"`. Nothing is committed to the repo.

**Prompt:** How do I curl the page to verify everything is working?

**Answer:** `curl http://<EC2_PUBLIC_IP>:4444/` — use `http`, not `https`, since the app doesn't serve TLS.

**Prompt:** What Jenkins credentials are required?

**Answer:** Four credentials:

- `aws-access-key-id` (Secret text) — AWS access key
- `aws-secret-access-key` (Secret text) — AWS secret key
- `cs411-cicd-ssh-key` (SSH Username with private key) — private key for EC2 access
- `ssh-allowed-ip` (Secret text) — IP address allowed to SSH into the instance
