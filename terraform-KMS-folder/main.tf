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
      },
      {
        Sid    = "AllowDMSAccess"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowRDSAccess"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:GenerateDataKey"
        ]
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
