resource "aws_eks_cluster" "shelful_dev" {
  name     = "shelful-dev"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.36"

  vpc_config {
    subnet_ids = [
      aws_subnet.private_1a.id,
      aws_subnet.private_1b.id,
    ]

    endpoint_public_access  = true
    endpoint_private_access = true

    public_access_cidrs = [
      "0.0.0.0/0",
    ]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  zonal_shift_config {
    enabled = false
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  deletion_protection = false
}

resource "aws_eks_node_group" "shelful_dev_nodes" {
  cluster_name    = aws_eks_cluster.shelful_dev.name
  node_group_name = "shelful-dev-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1b.id,
  ]

  version       = "1.36"
  ami_type      = "AL2023_x86_64_STANDARD"
  capacity_type = "ON_DEMAND"

  instance_types = [
    "t3.medium",
  ]

  disk_size = 20

  scaling_config {
    min_size     = 2
    max_size     = 2
    desired_size = 2
  }

  update_config {
    max_unavailable = 1
    update_strategy = "DEFAULT"
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "eks"
    Project     = "shelful"
  }
}

resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = aws_eks_cluster.shelful_dev.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.load_balancer_controller.arn
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.shelful_dev.name
  addon_name    = "coredns"
  addon_version = "v1.14.3-eksbuild.14"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.shelful_dev.name
  addon_name    = "kube-proxy"
  addon_version = "v1.36.0-eksbuild.17"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.shelful_dev.name
  addon_name    = "vpc-cni"
  addon_version = "v1.22.4-eksbuild.3"
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = aws_eks_cluster.shelful_dev.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.10-eksbuild.3"
}
