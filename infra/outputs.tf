output "ec2_public_ip" {
  description = "Elastic IP attached to the K3S instance"
  value       = aws_eip.k3s.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.k3s.id
}

output "s3_website_url" {
  description = "S3 static website base URL (pre-existing bucket)"
  value       = local.website_url
}

output "bucket_name" {
  description = "S3 bucket name (pre-existing, not managed by Terraform)"
  value       = local.bucket_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.iss_tracking.name
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key>.pem ubuntu@${aws_eip.k3s.public_ip}"
}
