#Creating a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }
}

#Create Internet Gateway
resource "aws_internet_gateway" "project-igw" {
   vpc_id = aws_vpc.my_vpc.id
}

#Creating Public Route Table
resource "aws_route_table" "project-route-table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.project-igw.id
  }

  tags = {
    Name = var.route_table_name
  }
}

#Creating Public Subnets
resource "aws_subnet" "project-subnet" {
    count = length(var.public_subnet)
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = var.public_subnet[count.index]
    availability_zone = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = true
    tags = {
      "Name" = "project-subnet-${count.index}"
    }
}

#Associating subnet with public route table
resource "aws_route_table_association" "project-subnet-association" {
  count = length(var.public_subnet)
  subnet_id = aws_subnet.project-subnet.*.id[count.index]
  route_table_id = aws_route_table.project-route-table.id
}

# Create a security group for the load balancer

resource "aws_security_group" "lb-sg" {
  name        = var.load-balancer-sg
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
    
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group to allow port 22, 80 and 443 on the Instances

resource "aws_security_group" "project-sg" {
  name        = var.instance-sg
  description = "Allow SSH, HTTP and HTTPS inbound traffic for private instances"
  vpc_id      = aws_vpc.my_vpc.id

 ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.lb-sg.id]
  }


 ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.lb-sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
   
  }

  tags = {
    Name = "Project-sg-rule"
  }
}

#Creating Instances
resource "aws_instance" "my-web" {
  count = 2
  ami = var.instance_ami
  instance_type = var.instance_type
  key_name = "Freecode"
  security_groups = [aws_security_group.project-sg.id]
  subnet_id = aws_subnet.project-subnet.*.id[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    "Name" = "my-web-${count.index}"
    source = "terraform"
  }
}

resource "aws_instance" "my-web-2" {
  count = 1
  ami = var.instance_ami
  instance_type = var.instance_type
  key_name = "Freecode"
  security_groups = [aws_security_group.project-sg.id]
  subnet_id = aws_subnet.project-subnet.*.id[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    "Name" = "my-web-2"
    source = "terraform"
  }
}

#Creating a file to save the IP Addresses of the instances
resource "local_file" "Ip_address" {
  filename = "/vagrant/ansible/host-inventory"
  content  = <<EOT
${aws_instance.my-web[0].public_ip}
${aws_instance.my-web[1].public_ip}
${aws_instance.my-web-2[0].public_ip}
  EOT
}

# Create an Application Load Balancer
resource "aws_lb" "project-lb" {
  name               = var.lb-name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb-sg.id]
  subnets            = [aws_subnet.project-subnet[0].id, aws_subnet.project-subnet[1].id]
  #enable_cross_zone_load_balancing = true
  enable_deletion_protection = false
  depends_on                 = [aws_instance.my-web, aws_instance.my-web-2]
}

# Create the target group
resource "aws_lb_target_group" "project-target-group" {
  name     = var.tg-name
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create the listener
resource "aws_lb_listener" "project-listener" {
  load_balancer_arn = aws_lb.project-lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project-target-group.arn
  }
}


# Create the listener rule
resource "aws_lb_listener_rule" "project-listener-rule" {
  listener_arn = aws_lb_listener.project-listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project-target-group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Attach the target group to the load balancer

resource "aws_lb_target_group_attachment" "project-tg-attachment" {
  target_group_arn = aws_lb_target_group.project-target-group.arn
  target_id        = aws_instance.my-web[0].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "project-tg-attachment1" {
  target_group_arn = aws_lb_target_group.project-target-group.arn
  target_id        = aws_instance.my-web[1].id
  port             = 80
}
 
resource "aws_lb_target_group_attachment" "project-target-group-attachment2" {
  target_group_arn = aws_lb_target_group.project-target-group.arn
  target_id        = aws_instance.my-web-2[0].id
  port             = 80
}
