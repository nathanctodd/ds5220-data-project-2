terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3"
}

provider "aws" {
  region = var.aws_region
}

# ─── Pre-existing S3 bucket (managed outside Terraform) ─────────────────────
# Bucket "ygu6ax-data-project-2" was created manually and is never touched here.
# We reference it by ARN only for the IAM policy below.
locals {
  bucket_name = "ygu6ax-data-project-2"
  bucket_arn  = "arn:aws:s3:::ygu6ax-data-project-2"
  website_url = "http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com"
}

# ─── DynamoDB Tables ─────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "iss_tracking" {
  name         = "iss-tracking"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "satellite_id"
  range_key = "timestamp"

  attribute {
    name = "satellite_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

resource "aws_dynamodb_table" "tide_tracking" {
  name         = "tide-tracking"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "station_id"
  range_key = "timestamp"

  attribute {
    name = "station_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

# ─── IAM Role for EC2 ────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "ds5220-project2-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_permissions" {
  # S3: read/write to the pre-existing website bucket
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${local.bucket_arn}/*"]
  }

  # DynamoDB: ISS tracking table
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.iss_tracking.arn]
  }

  # DynamoDB: tide tracking table
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.tide_tracking.arn]
  }
}

resource "aws_iam_role_policy" "ec2_policy" {
  name   = "ds5220-project2-ec2-policy"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_permissions.json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ds5220-project2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# ─── Security Group ──────────────────────────────────────────────────────────

resource "aws_security_group" "ec2_sg" {
  name        = "ds5220-project2-sg"
  description = "Allow inbound SSH, HTTP, 8000, 8080"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port 8000"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── EC2 Instance ────────────────────────────────────────────────────────────

# Latest Ubuntu 24.04 LTS (Noble) AMD64 AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "ds5220-project2-k3s"
  }
}

# ─── Elastic IP ──────────────────────────────────────────────────────────────

resource "aws_eip" "k3s" {
  instance = aws_instance.k3s.id
  domain   = "vpc"
}
