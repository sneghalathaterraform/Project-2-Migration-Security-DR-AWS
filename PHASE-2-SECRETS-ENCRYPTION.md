# Phase 2 — Secrets & Encryption
## Project 2: Migration, Security & DR Platform

**Domain:** cloudgrip.art  
**AWS Region:** us-east-1  
**AWS Account ID:** 752988091288  

---

## What We Built

| Service | Purpose |
|---------|---------|
| EC2 Instance | Linux server to run OpenSSL commands |
| OpenSSL | Generated self-signed TLS certificate for cloudgrip.art |
| ACM | Stores the TLS certificate for use with ALB / CloudFront |
| KMS | 3 master encryption keys for S3, EBS, RDS |
| Secrets Manager | Secure vault for DB credentials and API keys |
| S3 + KMS | Proved encryption works by uploading and verifying a test file |

---

## STEP 1 — Import Key Pair to AWS

### 1.1 Extract public key from .pem file (PowerShell — Windows)
```powershell
ssh-keygen -y -f "D:\Sneghalatha\AWS_Cloud_engineer\Documentof Learning new topics\newaccount_key.pem" | Out-File -FilePath "D:\Sneghalatha\AWS_Cloud_engineer\Documentof Learning new topics\newaccount_key.pub" -Encoding ASCII
```

### 1.2 Import public key to AWS EC2
```powershell
aws ec2 import-key-pair `
  --key-name "project2-key" `
  --public-key-material fileb://"D:\Sneghalatha\AWS_Cloud_engineer\Documentof Learning new topics\newaccount_key.pub" `
  --region us-east-1
```

### 1.3 Verify key pair was imported
```powershell
aws ec2 describe-key-pairs --region us-east-1 --query "KeyPairs[*].KeyName" --output table
```

---

## STEP 2 — Launch EC2 Instance (Terraform)

### Folder: `terraform\`

### File: `variables.tf`
```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "key_pair_name" {
  default = "project2-key"
}

variable "my_ip" {
  description = "Your local machine public IP for SSH access (e.g. 203.0.113.10/32)"
  type        = string
}
```

### File: `main.tf`
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "openssl_sg" {
  name        = "project2-openssl-sg"
  description = "Allow SSH from my IP only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "project2-openssl-sg"
    Project = "Project2"
  }
}

resource "aws_instance" "openssl_server" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  key_name                    = var.key_pair_name
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.openssl_sg.id]
  associate_public_ip_address = true

  tags = {
    Name    = "project2-openssl-server"
    Project = "Project2"
  }
}
```

### File: `outputs.tf`
```hcl
output "instance_id" {
  value = aws_instance.openssl_server.id
}

output "public_ip" {
  value = aws_instance.openssl_server.public_ip
}

output "ssh_command" {
  value = "ssh -i newaccount_key.pem ec2-user@${aws_instance.openssl_server.public_ip}"
}
```

### Terraform Commands
```powershell
cd "D:\Sneghalatha\AWS_Cloud_engineer\Module-wise-Project\Project-2\terraform"

# Get your public IP first
(Invoke-WebRequest -Uri "https://checkip.amazonaws.com").Content.Trim()

terraform init
terraform plan -var="my_ip=99.246.198.79/32"
terraform apply -var="my_ip=99.246.198.79/32"
terraform output
```

---

## STEP 3 — Fix .pem File Permissions & SSH Into EC2

### Fix permissions on the .pem file (PowerShell — Run as Administrator)
```powershell
$keyFile = "D:\Sneghalatha\AWS_Cloud_engineer\Documentof Learning new topics\newaccount_key.pem"
$acl = Get-Acl $keyFile
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "Read", "Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path $keyFile -AclObject $acl
```

### SSH into EC2
```powershell
ssh -i "D:\Sneghalatha\AWS_Cloud_engineer\Documentof Learning new topics\newaccount_key.pem" ec2-user@<PUBLIC-IP>
```

---

## STEP 4 — Generate OpenSSL Self-Signed Certificate (Inside EC2 Terminal)

### 4.1 Verify OpenSSL is installed
```bash
openssl version
```

### 4.2 Install a text editor (if needed)
```bash
sudo dnf install -y nano
```

### 4.3 Create working directory
```bash
mkdir ~/certs && cd ~/certs
```

### 4.4 Generate RSA private key
```bash
openssl genrsa -out private.key 2048
```

### 4.5 Create OpenSSL config file
```bash
cat > ~/certs/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[req_distinguished_name]
C  = IN
ST = Tamil Nadu
L  = Chennai
O  = CloudGrip
OU = IT
CN = cloudgrip.art

[v3_req]
keyUsage         = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[alt_names]
DNS.1 = cloudgrip.art
DNS.2 = www.cloudgrip.art
EOF
```

### 4.6 Generate CSR (Certificate Signing Request)
```bash
openssl req -new \
  -key ~/certs/private.key \
  -out ~/certs/certificate.csr \
  -config ~/certs/openssl.cnf
```

### 4.7 Self-sign the certificate (valid 365 days)
```bash
openssl x509 -req -days 365 \
  -in ~/certs/certificate.csr \
  -signkey ~/certs/private.key \
  -out ~/certs/certificate.crt \
  -extensions v3_req \
  -extfile ~/certs/openssl.cnf
```

### 4.8 Verify the certificate
```bash
openssl x509 -in ~/certs/certificate.crt -text -noout | grep -E "Subject:|DNS:|Not Before|Not After"
```

Expected output:
```
Not Before: May 12 19:54:26 2026 GMT
Not After : May 12 19:54:26 2027 GMT
Subject: C=IN, ST=Tamil Nadu, L=Chennai, O=CloudGrip, OU=IT, CN=cloudgrip.art
DNS:cloudgrip.art, DNS:www.cloudgrip.art
```

### 4.9 Confirm all files exist
```bash
ls -lh ~/certs/
```

Files created:
```
private.key     → RSA private key (secret — never share)
certificate.csr → Certificate signing request
certificate.crt → Self-signed certificate
openssl.cnf     → Config used to generate cert
```

---

## STEP 5 — Copy Certificate from EC2 to Windows & Import to ACM

### 5.1 Copy files from EC2 to Windows (PowerShell — new window, not inside EC2)
```powershell
scp -i "D:\Sneghalatha\AWS_Cloud_engineer\Documentof Learning new topics\newaccount_key.pem" `
  ec2-user@<PUBLIC-IP>:~/certs/certificate.crt `
  "D:\Sneghalatha\AWS_Cloud_engineer\Module-wise-Project\Project-2\"

scp -i "D:\Sneghalatha\AWS_Cloud_engineer\Documentof Learning new topics\newaccount_key.pem" `
  ec2-user@<PUBLIC-IP>:~/certs/private.key `
  "D:\Sneghalatha\AWS_Cloud_engineer\Module-wise-Project\Project-2\"
```

### 5.2 Import certificate to ACM
```powershell
aws acm import-certificate `
  --certificate fileb://"D:\Sneghalatha\AWS_Cloud_engineer\Module-wise-Project\Project-2\certificate.crt" `
  --private-key fileb://"D:\Sneghalatha\AWS_Cloud_engineer\Module-wise-Project\Project-2\private.key" `
  --region us-east-1 `
  --tags Key=Project,Value=Project2 Key=Name,Value=cloudgrip-self-signed-cert
```

### 5.3 Verify certificate was imported
```powershell
aws acm list-certificates --region us-east-1 --output table
```

---

## STEP 6 — Create KMS Keys for S3, EBS, RDS (Terraform)

### Folder: `terraform-KMS-folder\`

### File: `variables.tf`
```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "project2"
}
```

### File: `main.tf`
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  kms_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# ── KMS Key: S3 ─────────────────────────────────────────────
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 encryption - Project2"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = local.kms_policy

  tags = {
    Name    = "${var.project_name}-s3-kms-key"
    Project = "Project2"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project_name}-s3-key"
  target_key_id = aws_kms_key.s3.key_id
}

# ── KMS Key: EBS ─────────────────────────────────────────────
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS encryption - Project2"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = local.kms_policy

  tags = {
    Name    = "${var.project_name}-ebs-kms-key"
    Project = "Project2"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.project_name}-ebs-key"
  target_key_id = aws_kms_key.ebs.key_id
}

# ── KMS Key: RDS ─────────────────────────────────────────────
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption - Project2"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = local.kms_policy

  tags = {
    Name    = "${var.project_name}-rds-kms-key"
    Project = "Project2"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds-key"
  target_key_id = aws_kms_key.rds.key_id
}

# ── Enable default EBS encryption ────────────────────────────
resource "aws_ebs_encryption_by_default" "enable" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "set" {
  key_arn = aws_kms_key.ebs.arn
}
```

### File: `outputs.tf`
```hcl
output "kms_s3_arn" {
  value = aws_kms_key.s3.arn
}

output "kms_ebs_arn" {
  value = aws_kms_key.ebs.arn
}

output "kms_rds_arn" {
  value = aws_kms_key.rds.arn
}
```

### Terraform Commands
```powershell
cd "D:\Sneghalatha\AWS_Cloud_engineer\Module-wise-Project\Project-2\terraform-KMS-folder"
terraform init
terraform plan
terraform apply
terraform output
```

### KMS ARNs Created
```
kms_s3_arn  = arn:aws:kms:us-east-1:752988091288:key/c3c37ce8-fd2d-4336-859f-6021ea284d01
kms_ebs_arn = arn:aws:kms:us-east-1:752988091288:key/953b0a92-9b35-4710-a1ef-f0b937051059
kms_rds_arn = arn:aws:kms:us-east-1:752988091288:key/32539a1c-f704-4b59-b6e1-7085f355c7c0
```

---

## STEP 7 — Secrets Manager (AWS CLI)

### 7.1 Store RDS database credentials
```powershell
aws secretsmanager create-secret `
  --name "project2/rds/credentials" `
  --description "RDS master credentials for Project2" `
  --secret-string '{"username":"dbadmin","password":"YourStrongPassword123!"}' `
  --kms-key-id "arn:aws:kms:us-east-1:752988091288:key/32539a1c-f704-4b59-b6e1-7085f355c7c0" `
  --region us-east-1 `
  --tags Key=Project,Value=Project2
```

### 7.2 Store application API keys
```powershell
aws secretsmanager create-secret `
  --name "project2/app/api-keys" `
  --description "Application API keys for Project2" `
  --secret-string '{"api_key":"demo-key-12345","api_secret":"demo-secret-12345"}' `
  --kms-key-id "arn:aws:kms:us-east-1:752988091288:key/c3c37ce8-fd2d-4336-859f-6021ea284d01" `
  --region us-east-1 `
  --tags Key=Project,Value=Project2
```

### 7.3 Verify secrets were created
```powershell
aws secretsmanager list-secrets `
  --region us-east-1 `
  --query "SecretList[*].{Name:Name,ARN:ARN}" `
  --output table
```

### 7.4 Retrieve a secret (to test)
```powershell
aws secretsmanager get-secret-value `
  --secret-id "project2/rds/credentials" `
  --region us-east-1
```

---

## STEP 8 — Prove S3 KMS Encryption Works (AWS CLI)

### 8.1 Create an S3 bucket
```powershell
aws s3api create-bucket `
  --bucket project2-kms-test-752988091288 `
  --region us-east-1 `
  --tags Key=Project,Value=Project2
```

### 8.2 Apply KMS encryption to the bucket
```powershell
aws s3api put-bucket-encryption `
  --bucket project2-kms-test-752988091288 `
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "arn:aws:kms:us-east-1:752988091288:key/c3c37ce8-fd2d-4336-859f-6021ea284d01"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

### 8.3 Verify encryption is set on the bucket
```powershell
aws s3api get-bucket-encryption `
  --bucket project2-kms-test-752988091288
```

### 8.4 Create and upload a test file
```powershell
echo "This is a KMS encryption test" > testfile.txt

aws s3 cp testfile.txt s3://project2-kms-test-752988091288/testfile.txt
```

### 8.5 Verify the file is KMS encrypted
```powershell
aws s3api head-object `
  --bucket project2-kms-test-752988091288 `
  --key testfile.txt `
  --query "{Encryption:ServerSideEncryption, KMSKeyId:SSEKMSKeyId}"
```

Expected output:
```json
{
  "Encryption": "aws:kms",
  "KMSKeyId": "arn:aws:kms:us-east-1:752988091288:key/c3c37ce8-fd2d-4336-859f-6021ea284d01"
}
```

### 8.6 Download and decrypt the file (proves decryption works)
```powershell
aws s3 cp s3://project2-kms-test-752988091288/testfile.txt downloaded-testfile.txt
cat downloaded-testfile.txt
```

---

## Summary — What Each Service Does

| Service | What it protects | How |
|---------|-----------------|-----|
| **KMS S3 Key** | Files stored in S3 | Encrypts every object uploaded |
| **KMS EBS Key** | EC2 disk volumes | Encrypts data written to disk |
| **KMS RDS Key** | Database data | Encrypts database storage |
| **Secrets Manager** | Passwords & API keys | Encrypted vault, no hardcoding |
| **ACM Certificate** | Website traffic | HTTPS encryption for cloudgrip.art |

## Protection Model

```
Data at rest   → Protected by KMS (S3, EBS, RDS)
Data in transit → Protected by ACM/TLS certificate (HTTPS)
Credentials    → Protected by Secrets Manager
```

---

## Important ARNs & Names (Save These)

```
KMS S3  Key ARN : arn:aws:kms:us-east-1:752988091288:key/c3c37ce8-fd2d-4336-859f-6021ea284d01
KMS EBS Key ARN : arn:aws:kms:us-east-1:752988091288:key/953b0a92-9b35-4710-a1ef-f0b937051059
KMS RDS Key ARN : arn:aws:kms:us-east-1:752988091288:key/32539a1c-f704-4b59-b6e1-7085f355c7c0

KMS Aliases:
  alias/project2-s3-key
  alias/project2-ebs-key
  alias/project2-rds-key

Secrets Manager:
  project2/rds/credentials
  project2/app/api-keys

S3 Test Bucket : project2-kms-test-752988091288
EC2 Key Pair   : project2-key
EC2 Instance   : project2-openssl-server
```
