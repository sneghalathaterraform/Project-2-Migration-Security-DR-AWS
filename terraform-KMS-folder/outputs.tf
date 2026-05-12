output "kms_s3_arn" {
  value = aws_kms_key.s3.arn
}

output "kms_ebs_arn" {
  value = aws_kms_key.ebs.arn
}

output "kms_rds_arn" {
  value = aws_kms_key.rds.arn
}
