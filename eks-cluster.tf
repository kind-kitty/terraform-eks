resource "aws_iam_role" "cluster-role" {
	name = "eks-cluster-role"
	
	assume_role_policy = <<POLICY 
	{
  	"Version": "2012-10-17",
  	"Statement": [
   	{	
      		"Effect": "Allow",
      		"Principal": {
        	"Service": "eks.amazonaws.com"
      		},
      	"Action": "sts:AssumeRole"
    	}
  	]
	}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-role-AmazonEKSClusterPolicy" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
	role = ${aws_iam_role.cluster-role.name}
}

resource "aws_iam_role_policy_attachment" "cluster-role-AmazonEKSServicePolicy" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
	role = ${aws_iam_role.cluster-role.name}
}

resource "aws_security_group_rule" "cluster-ingress-node-https" {
	description              = "Allow pods to communicate with the cluster API Server"
	from_port                = 443
	protocol                 = "tcp"
	security_group_id        = "sg-dc00bbed"
	source_security_group_id = ${aws_security_group.node-sg.id}
	to_port                  = 443
	type                     = "ingress"
}


resource "aws_eks_cluster" "cluster" {
	name     = ${var.cluster-name}
	role_arn = ${aws_iam_role.cluster-role.arn}

	vpc_config {
		security_group_ids = ["sg-dc00bbed"]
		subnet_ids = ["subnet-53b10635", "subnet-d749fbf6"]
	}
	depends_on = [
		aws_iam_role_policy_attachment.cluster-role-AmazonEKSClusterPolicy,
    		aws_iam_role_policy_attachment.cluster-role-AmazonEKSServicePolicy,
  	]	
}
