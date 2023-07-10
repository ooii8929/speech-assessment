module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "5.0.0"

    name = var.vpc_name
    cidr = var.vpc_cidr

    azs = var.vpc_azs
    private_subnets = var.vpc_private_subnets
    public_subnets = var.vpc_public_subnets

    enable_nat_gateway = var.vpc_enable_nat_gateway

    tags = var.vpc_tags
}

resource "aws_security_group" "example_sg" {
  name        = "example-sg"
  description = "Example security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "example-sg"
  }
}

module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.2.1"
  count   = 1

  name = "demo-ec2-cluster"

  ami                    = "ami-0d3bbfd074edd7acb"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.vpc.default_security_group_id, aws_security_group.example_sg.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.session_manager_instance_profile.name
  
  associate_public_ip_address = true
  tags = {
    Terraform   = "true"
    Environment = "development"
  }
    # Add user data
  user_data = <<-EOF
              #!/bin/bash
              touch /home/ec2-user/hello.txt
              echo 'Hello, World!' > /home/ec2-user/hello.txt
              sudo yum update
              sudo yum search docker
              sudo yum info docker
              sudo yum install -y docker
              sudo systemctl status docker.service
              EOF
}

resource "aws_iam_role" "session_manager_role" {
  name               = "SSMSessionManagerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "session_manager_policy_attachment" {
  policy_arn = aws_iam_policy.ssm_session_manager_policy.arn
  role       = aws_iam_role.session_manager_role.name
}

resource "aws_iam_instance_profile" "session_manager_instance_profile" {
  name = "SSMSessionManagerInstanceProfile"
  role = aws_iam_role.session_manager_role.name
}

resource "aws_iam_policy" "ssm_session_manager_policy" {
  name        = "SSMSessionManagerPolicy"
  description = "Grant necessary permissions for AWS Systems Manager Session Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

output "vpc_public_subnets" {
  description = "IDs of the VPC's public subnets"
  value       = module.vpc.public_subnets
}

output "ec2_instance_public_ips" {
  description = "Public IP addresses of EC2 instances"
  value       = module.ec2_instances[*].public_ip
}

output "name" {
  value = aws_iam_instance_profile.session_manager_instance_profile.name
}