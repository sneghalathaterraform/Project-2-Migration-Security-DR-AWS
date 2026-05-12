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
