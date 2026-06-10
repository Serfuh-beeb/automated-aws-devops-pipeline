terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "devops-project-tfstate-535387"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "devops-project-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ---------- Variables ----------

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_profile" {
  default = "sami"
}

variable "project" {
  default = "devops-project"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "az_count" {
  default = 2
}

variable "container_port" {
  default = 8000
}

variable "cpu" {
  default = 256
}

variable "memory" {
  default = 512
}

variable "desired_count" {
  default = 2
}

variable "db_username" {
  default   = "postgres"
  sensitive = true
}

variable "db_password" {
  default   = "ChangeMeL8r!"
  sensitive = true
}

variable "db_name" {
  default = "taskdb"
}

variable "github_repo" {
  description = "GitHub repo in format owner/repo"
  default     = "Serfuh-beeb/automated-aws-devops-pipeline"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}
