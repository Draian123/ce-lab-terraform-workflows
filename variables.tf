variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "tf-workflows"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}
