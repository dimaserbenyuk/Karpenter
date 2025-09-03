# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token = "eks-cluster-efs"
  
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100

  encrypted = true

  tags = {
    Name = "eks-cluster-efs"
  }
}

# EFS Mount Targets (по одному в каждой приватной подсети)
resource "aws_efs_mount_target" "private1" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private1.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "private2" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private2.id
  security_groups = [aws_security_group.efs.id]
}

# Security Group для EFS
resource "aws_security_group" "efs" {
  name_prefix = "efs-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Allow access from Karpenter nodes
  ingress {
    description = "NFS from Karpenter nodes"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [aws_security_group.karpenter.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}

# EFS Access Point для динамического провижнинга
resource "aws_efs_access_point" "dynamic" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/dynamic_provisioning"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "dynamic-provisioning"
  }
}

# Output для использования в StorageClass
output "efs_file_system_id" {
  value = aws_efs_file_system.main.id
}

output "efs_access_point_id" {
  value = aws_efs_access_point.dynamic.id
}
