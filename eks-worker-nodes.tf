 
resource "aws_iam_role" "node-role" {
	name = "eks-node-role"

	assume_role_policy = <<POLICY
	{
		"Version": "2012-10-17",
  		"Statement": [
    		{
      			"Effect": "Allow",
      			"Principal": {
        		"Service": "ec2.amazonaws.com"
      			},
      			"Action": "sts:AssumeRole"
    		}
  		]
	}
POLICY

}

resource "aws_iam_role_policy_attachment" "node-role-AmazonEKSWorkerNodePolicy" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
	role = ${aws_iam_role.node-role.name}
}

resource "aws_iam_role_policy_attachment" "node-role-AmazonEKS_CNI_Policy" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
	role = ${aws_iam_role.node-role.name}
}

resource "aws_iam_role_policy_attachment" "node-role-AmazonEC2ContainerRegistryReadOnly" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
	role = ${aws_iam_role.node-role.name}
}
resource "aws_iam_role_policy_attachment" "node-role-AmazonEC2FullAccess" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
	role = ${aws_iam_role.node-role.name}
}

resource "aws_iam_instance_profile" "node-role" {
	name = "eks-node-role"
	role = ${aws_iam_role.node-role.name}
}

resource "aws_security_group" "node-sg" {
	name        = "eks-node-sg"
	description = "Security group for all nodes in the cluster"
	vpc_id      = vpc-5b69a926

	egress {
  		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = "${
		map(
    			"Name", "eks-node-sg",
    			"kubernetes.io/cluster/${var.cluster-name}",  "personal",
		)  	
	}"
}

resource "aws_security_group_rule" "node-ingress-cluster" {
	description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  	from_port                = 443
  	protocol                 = "tcp"
  	security_group_id        = "${aws_security_group.node-sg.id}"
  	source_security_group_id = "sg-dc00bbed"
  	to_port                  = 443
  	type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-cluster2" {
        description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
        from_port                = 80
        protocol                 = "tcp"
        security_group_id        = "${aws_security_group.node-sg.id}"
        source_security_group_id = "sg-dc00bbed"
        to_port                  = 80
        type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-cluster3" {
        description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
        from_port                = 1025
        protocol                 = "tcp"
        security_group_id        = "${aws_security_group.node-sg.id}"
        source_security_group_id = "sg-dc00bbed"
        to_port                  = 65535
        type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-self" {
  	description              = "Allow node to communicate with each other"
  	from_port                = 0
  	protocol                 = "-1"
  	security_group_id        = "${aws_security_group.node-sg.id}"
  	source_security_group_id = "${aws_security_group.node-sg.id}"
  	to_port                  = 65535
 	type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-ssh" {
        description              = "Allow ssh communication"
        from_port                = 22
        protocol                 = "tcp"
        security_group_id        = "${aws_security_group.node-sg.id}"
        source_security_group_id = ["0.0.0.0/0"]
        to_port                  = 65535
        type                     = "ingress"
}


data "aws_ami" "eks-worker" {
	filter {
    		name   = "name"
    		values = ["aws-eks-node-${aws_eks_cluster.demo.version}-v*"]
  	}

  	most_recent = true
  	owners      = ["602401143452"] # Amazon
}

locals {
 	node1-userdata = <<USERDATA
#!/bin/bash
set -ex
B64_CLUSTER_CA=${aws_eks_cluster.cluster.certificate_authority.0.data}
API_SERVER-URL=${aws_eks_cluster.cluster.endpoint}
/etc/eks/bootstrap.sh  ${var.cluster-name} --kubelet-extra-args '--node-labels=eks.amazonaws.com/nodegroup=core1-worker-group,worker-type=standard1' --apiserver-endpoint $API_SERVER_URL --b64-cluster-ca $B64_CLUSTER_CA
USERDATA

	node2-userdata = <<USERDATA
#!/bin/bash
set -ex
B64_CLUSTER_CA=${aws_eks_cluster.cluster.certificate_authority.0.data}
API_SERVER-URL=${aws_eks_cluster.cluster.endpoint}
/etc/eks/bootstrap.sh  ${var.cluster-name} --kubelet-extra-args '--node-labels=eks.amazonaws.com/nodegroup=core2-worker-group,worker-type=standard2' --apiserver-endpoint $API_SERVER_URL --b64
-cluster-ca $B64_CLUSTER_CA
USERDATA
}

resource "aws_launch_configuration" "eks-cluster-standard1" {
  	associate_public_ip_address = false
  	iam_instance_profile = "${aws_iam_instance_profile.node-role.name}"
  	image_id = "${data.aws_ami.eks-worker.id}"
  	instance_type = "t2.micro"
  	name_prefix = "eks-node"
  	security_groups = ["${aws_security_group.node-sg.id}"]
  	user_data_base64 = "${base64encode(local.node1-userdata)}"
	key_name="ec2_key"

  	lifecycle {
    		create_before_destroy = true
  	}
}

resource "aws_autoscaling_group" "eks-cluster-standard1" {
  	desired_capacity = 1
  	launch_configuration ="${aws_launch_configuration.eks-cluster-standard1.id}"
  	max_size = 2
  	min_size = 1
  	name = "terraform-eks-node1"
	vpc_zone_identifier = ["subnet-53b10635", "subnet-d749fbf6"]

  	tag {
    		key = "Name"
    		value = "terraform-eks-node1"
    		propagate_at_launch = true
  	}

  	tag {
    		key = "kubernetes.io/cluster/${var.cluster-name}"
    		value = "personal"
    		propagate_at_launch = true
  	}
}

resource "aws_launch_configuration" "eks-cluster-standard2" {
        associate_public_ip_address = false
        iam_instance_profile = "${aws_iam_instance_profile.node-role.name}"
        image_id = "${data.aws_ami.eks-worker.id}"
        instance_type = "t2.micro"
        name_prefix = "eks-node"
        security_groups = ["${aws_security_group.node-sg.id}"]
        user_data_base64 = "${base64encode(local.node2-userdata)}"
        key_name="ec2_key"

        lifecycle {
                create_before_destroy = true
        }
}

resource "aws_autoscaling_group" "eks-cluster-standard2" {
        desired_capacity = 1
        launch_configuration ="${aws_launch_configuration.eks-cluster-standard2.id}"
        max_size = 2
        min_size = 1
        name = "terraform-eks-node2"
        vpc_zone_identifier = ["subnet-53b10635", "subnet-d749fbf6"]

        tag {
                key = "Name"
                value = "terraform-eks-node2"
                propagate_at_launch = true
        }

        tag {
                key = "kubernetes.io/cluster/${var.cluster-name}"
                value = "personal"
                propagate_at_launch = true
        }
}




















































