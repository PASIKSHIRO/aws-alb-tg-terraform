# resource "aws_subnet" "main" {
#   vpc_id     = "vpc-3bd83b52"
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "Main"
#   }
# }

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deploy" {
  key_name   = "Yurii key for ${var.description}"
  public_key = var.public_key
}

resource "aws_security_group" "main" {
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    },
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    }
  ]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

# Create a basic ALB 
resource "aws_alb" "my-app-alb" {
  name                             = "my-app-alb"
  subnets                          = ["subnet-7e806c17", "subnet-7b929e03"]
  enable_cross_zone_load_balancing = true
  internal                         = true
}


# Create target groups with one health check per group
resource "aws_alb_target_group" "target-group-1" {
  name     = "target-group-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-3bd83b52"

  lifecycle { create_before_destroy = true }

  health_check {
    path                = "/"
    port                = 80
    healthy_threshold   = 6
    unhealthy_threshold = 2
    timeout             = 2
    interval            = 5
    matcher             = "200"
  }
}

# Create a Listener 
resource "aws_alb_listener" "my-alb-listener" {
  load_balancer_arn = aws_alb.my-app-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.target-group-1.arn
    type             = "forward"
  }
}


resource "aws_autoscaling_group" "my-alb-asg" {
  name                      = "my-alb-asg"
  max_size                  = "2"
  min_size                  = "1"
  desired_capacity          = "1"
  wait_for_elb_capacity     = "1"
  health_check_type         = "ELB"
  default_cooldown          = 300
  force_delete              = true
  health_check_grace_period = 300
  launch_configuration      = aws_launch_configuration.my-app-alb.name
  depends_on                = [aws_alb.my-app-alb]
  target_group_arns         = [aws_alb_target_group.target-group-1.arn]
  vpc_zone_identifier       = ["subnet-7e806c17", "subnet-7b929e03"]
  termination_policies = [
    "OldestInstance",
    "OldestLaunchConfiguration",
  ]
}

resource "aws_launch_configuration" "my-app-alb" {
  name_prefix     = "tets-persistence_service-lc"
  image_id        = data.aws_ami.ubuntu.id
  security_groups = [aws_security_group.main.id]
  instance_type   = "t2.nano"
  key_name        = aws_key_pair.deploy.key_name

  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_instance" "default" {
#   ami           = data.aws_ami.ubuntu.id
#   instance_type = "t2.micro"
#   key_name      = aws_key_pair.deploy.key_name

#   tags = {
#     description = var.description
#   }

#   vpc_security_group_ids = [aws_security_group.main.id]
# }
