S3 URL for Deliverables: http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com/plot.png

S3 URL for CSV data: http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com/data.csv

Repo URL: https://github.com/nathanctodd/ds5220-data-project-2#


Answer to Questions:

1. In the ISS sample application, data is persisted in DynamoDB. If this were a much higher-frequency application (hundreds of writes per minute), what changes would you make to the persistence strategy and why?
- If the application were to handle hundreds of writes per minute, I would consider switching from DynamoDB to a more scalable and high-throughput database solution, such as Amazon Aurora or Amazon RDS. These relational databases can handle a higher volume of transactions and provide better performance for write-heavy workloads. I would also implement batching of writes to reduce the number of individual write operations, which can further improve performance and reduce costs. This change would ensure that the application can efficiently manage the increased data load without experiencing latency or performance issues.

2. The ISS tracker detects orbital burns by comparing consecutive altitude readings. Describe at least one way this detection logic could produce a false positive, and how you would make it more robust.
- One way the detection logic could produce a false positive is if there is a temporary glitch or anomaly in the altitude readings, such as a sensor error or a brief communication issue. This would make the readings appear as if there was a decrease in altitude flagging an orbital burn when in reality there was none. To make the detection logic more robust, I would implement a smoothing algorithm or a moving average to filter out noise and anomalies in the altitude data. Additionally, I could set a threshold for the minimum change in altitude required to trigger an orbital burn detection, which would help reduce false positives caused by minor fluctuations in the readings.


3. How does each `CronJob` pod get AWS permissions without credentials being passed into the container?
- Each `CronJob` pod gets AWS permissions through the use of an IAM role that is associated with the EC2 instance running the Kubernetes cluster. The EC2 instance has an IAM instance profile attached to it, which grants the necessary permissions to access AWS services such as DynamoDB and S3. When the `CronJob` pods run on the EC2 instance, they inherit the permissions of the instance profile, allowing them to interact with AWS services without needing to pass explicit credentials into the container. This approach is more secure and simplifies credential management, as it avoids hardcoding sensitive information in the application code or environment variables.

4. Notice the structure of the `iss-tracking` table in DynamoDB. What is the partition key and what is the sort key? Why do these work well in this example, but may not work for other solutions?
- The partition key for the `iss-tracking` table in DynamoDB is `satellite_id`, and the sort key is `timestamp`. This structure works well in this example because it allows for efficient querying of data based on the satellite's unique identifier and the time of the readings. The partition key ensures that all data for a specific satellite is stored together, while the sort key allows for sorting and retrieving data in chronological order. However, this structure may not work for other solutions if there are multiple satellites being tracked or if there is a need to query data based on different attributes (e.g., altitude or velocity). In such cases, a different partition key and sort key design may be necessary to optimize query performance and accommodate the specific use case.


Outputs from command line:

nathanctodd@NathanTodd ds5220-data-project-2 % ./deploy.sh

==> [1/5] Initialising Terraform...

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

==> [2/5] Applying Terraform (S3, EC2, EIP, IAM, DynamoDB)...
data.aws_iam_policy_document.ec2_assume_role: Reading...
data.aws_ami.ubuntu: Reading...
data.aws_iam_policy_document.ec2_assume_role: Read complete after 0s [id=2851119427]
data.aws_ami.ubuntu: Read complete after 0s [id=ami-04eaa218f1349d88b]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # data.aws_iam_policy_document.ec2_permissions will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "ec2_permissions" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "s3:GetObject",
              + "s3:PutObject",
            ]
          + effect    = "Allow"
          + resources = [
              + "arn:aws:s3:::ygu6ax-data-project-2/*",
            ]
        }
      + statement {
          + actions   = [
              + "dynamodb:GetItem",
              + "dynamodb:PutItem",
              + "dynamodb:Query",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
        }
    }

  # aws_dynamodb_table.iss_tracking will be created
  + resource "aws_dynamodb_table" "iss_tracking" {
      + arn              = (known after apply)
      + billing_mode     = "PAY_PER_REQUEST"
      + hash_key         = "satellite_id"
      + id               = (known after apply)
      + name             = "iss-tracking"
      + range_key        = "timestamp"
      + read_capacity    = (known after apply)
      + stream_arn       = (known after apply)
      + stream_label     = (known after apply)
      + stream_view_type = (known after apply)
      + tags_all         = (known after apply)
      + write_capacity   = (known after apply)

      + attribute {
          + name = "satellite_id"
          + type = "S"
        }
      + attribute {
          + name = "timestamp"
          + type = "S"
        }
    }

  # aws_eip.k3s will be created
  + resource "aws_eip" "k3s" {
      + allocation_id        = (known after apply)
      + arn                  = (known after apply)
      + association_id       = (known after apply)
      + carrier_ip           = (known after apply)
      + customer_owned_ip    = (known after apply)
      + domain               = "vpc"
      + id                   = (known after apply)
      + instance             = (known after apply)
      + ipam_pool_id         = (known after apply)
      + network_border_group = (known after apply)
      + network_interface    = (known after apply)
      + private_dns          = (known after apply)
      + private_ip           = (known after apply)
      + ptr_record           = (known after apply)
      + public_dns           = (known after apply)
      + public_ip            = (known after apply)
      + public_ipv4_pool     = (known after apply)
      + tags_all             = (known after apply)
      + vpc                  = (known after apply)
    }

  # aws_iam_instance_profile.ec2_profile will be created
  + resource "aws_iam_instance_profile" "ec2_profile" {
      + arn         = (known after apply)
      + create_date = (known after apply)
      + id          = (known after apply)
      + name        = "ds5220-project2-instance-profile"
      + name_prefix = (known after apply)
      + path        = "/"
      + role        = "ds5220-project2-ec2-role"
      + tags_all    = (known after apply)
      + unique_id   = (known after apply)
    }

  # aws_iam_role.ec2_role will be created
  + resource "aws_iam_role" "ec2_role" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "ec2.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "ds5220-project2-ec2-role"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags_all              = (known after apply)
      + unique_id             = (known after apply)
    }

  # aws_iam_role_policy.ec2_policy will be created
  + resource "aws_iam_role_policy" "ec2_policy" {
      + id          = (known after apply)
      + name        = "ds5220-project2-ec2-policy"
      + name_prefix = (known after apply)
      + policy      = (known after apply)
      + role        = (known after apply)
    }

  # aws_instance.k3s will be created
  + resource "aws_instance" "k3s" {
      + ami                                  = "ami-04eaa218f1349d88b"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = (known after apply)
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = "ds5220-project2-instance-profile"
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_lifecycle                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t3.large"
      + ipv6_address_count                   = (known after apply)
      + ipv6_addresses                       = (known after apply)
      + key_name                             = "ds5220"
      + monitoring                           = (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      + placement_partition_number           = (known after apply)
      + primary_network_interface_id         = (known after apply)
      + private_dns                          = (known after apply)
      + private_ip                           = (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      + secondary_private_ips                = (known after apply)
      + security_groups                      = (known after apply)
      + source_dest_check                    = true
      + spot_instance_request_id             = (known after apply)
      + subnet_id                            = (known after apply)
      + tags                                 = {
          + "Name" = "ds5220-project2-k3s"
        }
      + tags_all                             = {
          + "Name" = "ds5220-project2-k3s"
        }
      + tenancy                              = (known after apply)
      + user_data                            = "1144b962156448cbf44573457ebbefa83b21a6c8"
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = false
      + vpc_security_group_ids               = (known after apply)

      + root_block_device {
          + delete_on_termination = true
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + tags_all              = (known after apply)
          + throughput            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = 30
          + volume_type           = "gp3"
        }
    }

  # aws_security_group.ec2_sg will be created
  + resource "aws_security_group" "ec2_sg" {
      + arn                    = (known after apply)
      + description            = "Allow inbound SSH, HTTP, 8000, 8080"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = ""
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "App port 8000"
              + from_port        = 8000
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 8000
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "App port 8080"
              + from_port        = 8080
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 8080
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "HTTP"
              + from_port        = 80
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 80
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "SSH"
              + from_port        = 22
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 22
            },
        ]
      + name                   = "ds5220-project2-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags_all               = (known after apply)
      + vpc_id                 = (known after apply)
    }

Plan: 7 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_name         = "ygu6ax-data-project-2"
  + dynamodb_table_name = "iss-tracking"
  + ec2_instance_id     = (known after apply)
  + ec2_public_ip       = (known after apply)
  + s3_website_url      = "http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com"
  + ssh_command         = (known after apply)
aws_iam_role.ec2_role: Creating...
aws_dynamodb_table.iss_tracking: Creating...
aws_security_group.ec2_sg: Creating...
aws_iam_role.ec2_role: Creation complete after 0s [id=ds5220-project2-ec2-role]
aws_iam_instance_profile.ec2_profile: Creating...
aws_security_group.ec2_sg: Creation complete after 3s [id=sg-06d318fe318707321]
aws_iam_instance_profile.ec2_profile: Creation complete after 6s [id=ds5220-project2-instance-profile]
aws_instance.k3s: Creating...
aws_dynamodb_table.iss_tracking: Still creating... [10s elapsed]
aws_dynamodb_table.iss_tracking: Creation complete after 13s [id=iss-tracking]
data.aws_iam_policy_document.ec2_permissions: Reading...
data.aws_iam_policy_document.ec2_permissions: Read complete after 0s [id=1264140801]
aws_iam_role_policy.ec2_policy: Creating...
aws_iam_role_policy.ec2_policy: Creation complete after 0s [id=ds5220-project2-ec2-role:ds5220-project2-ec2-policy]
aws_instance.k3s: Still creating... [10s elapsed]
aws_instance.k3s: Creation complete after 15s [id=i-04a044baf2ee5487e]
aws_eip.k3s: Creating...
aws_eip.k3s: Creation complete after 4s [id=eipalloc-0dcff05208b504840]

Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

bucket_name = "ygu6ax-data-project-2"
dynamodb_table_name = "iss-tracking"
ec2_instance_id = "i-04a044baf2ee5487e"
ec2_public_ip = "3.218.155.56"
s3_website_url = "http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com"
ssh_command = "ssh -i <your-key>.pem ubuntu@3.218.155.56"

    EC2 Elastic IP : 3.218.155.56
    S3 Website URL : http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com

==> [3/5] Waiting for SSH on 3.218.155.56...
    ...not ready yet, retrying in 10s
    SSH is up.

==> [4/5] Waiting for K3S node to become Ready (may take ~2 min)...
    ...K3S not ready yet, retrying in 15s
    ...K3S not ready yet, retrying in 15s
    K3S cluster status:
NAME              STATUS   ROLES           AGE   VERSION
ip-172-31-32-67   Ready    control-plane   16s   v1.34.6+k3s1
NAME              STATUS   AGE
default           Active   21s
kube-node-lease   Active   21s
kube-public       Active   21s
kube-system       Active   21s

==> [5/5] Deploying Kubernetes manifests...
simple-job.yaml                                                                                                                        100%  358    22.5KB/s   00:00    
iss-job-patched.yaml                                                                                                                   100%  622    33.0KB/s   00:00    

    Applying simple-job.yaml (smoke test)...
cronjob.batch/hello-cronjob created
    Waiting up to 6 min for hello-cronjob to fire...
    ...waiting for hello-cronjob pod, retrying in 20s
    ...waiting for hello-cronjob pod, retrying in 20s
    ...waiting for hello-cronjob pod, retrying in 20s
    ...waiting for hello-cronjob pod, retrying in 20s
    ...waiting for hello-cronjob pod, retrying in 20s
    Log from hello-cronjob-29585660-f2z4g:
Hello from CronJob - Thu Apr 2 14:20:01 UTC 2026
    Removing simple-job...
cronjob.batch "hello-cronjob" deleted from default namespace

    Applying ISS tracker CronJob...
cronjob.batch/iss-tracker created

    Active CronJobs:
NAME          SCHEDULE       TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
iss-tracker   */15 * * * *   <none>     False     0        <none>          1s

╔══════════════════════════════════════════════════════════╗
║  All done!                                               ║
╠══════════════════════════════════════════════════════════╣
║  EC2 IP        : 3.218.155.56                           ║
║  SSH           : ssh -i <key>.pem ubuntu@3.218.155.56      ║
║  Website URL   : http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com║
║  Plot URL      : http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com/plot.png║
║  Data CSV URL  : http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com/data.csv║
╚══════════════════════════════════════════════════════════╝

Next steps:
  1. Build + push your custom data pipeline container
  2. kubectl apply -f <your-pipeline-job>.yaml
  3. After 72+ data points, grab the plot URL above for Canvas


