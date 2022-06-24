
# 1. SET UP A PROVIDER    
provider "aws" {                               # I USE THIS TO SET UP A PROVIDER AND GIVE IT A DEFAULT REGION
    region = "eu-north-1"
   
}


# I CREATED A VPC 

resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "createdby-akeem"
  }
}

# I CREATED 2 PUBLIC SUBNET & 2 PRIVATE SUBNET

resource "aws_subnet" "public_eu_north_1a" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "Createdby-akeem"
  }
}

resource "aws_subnet" "public_eu_north_1b" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1b"

  tags = {
    Name = "createdby-akeem"
  }
}

# I CREATE AN INTERNET GATEWAY

resource "aws_internet_gateway" "my_vpc_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "My VPC - Internet Gateway"
  }
}

# I CREATED A ROUTE TABLE

resource "aws_route_table" "my_vpc_public" {
    vpc_id = aws_vpc.my_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_vpc_igw.id
    }

    tags = {
        Name = "createdby-akeem"
    }
}

# I CREATE A ROUTE TABLE ASSOCIATION

resource "aws_route_table_association" "my_vpc_us_east_1a_public" {
    subnet_id = aws_subnet.public_eu_north_1a.id
    route_table_id = aws_route_table.my_vpc_public.id
}

resource "aws_route_table_association" "my_vpc_us_east_1b_public" {
    subnet_id = aws_subnet.public_eu_north_1b.id
    route_table_id = aws_route_table.my_vpc_public.id
}

# I describe the Security Group for our web-servers, which will allow HTTP connections to our instances

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "createdby-akeem"
  }
}

# I CREATE EC2 INSTANCE

resource "aws_instance" "nginx" {
    ami = "ami-0e3f1570eb0a9bc7f"
    instance_type = "t2.micro"
    availability_zone = "eu-north-1a"
    subnet_id = aws_subnet.public_eu_north_1a.id
       user_data = <<-EOF
                #!/bin/bash
                sudo amazon-linux-extras install -y nginx1.12
                sudo systemctl start nginx
               
                EOF
       }


# I Create a lunch template

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = ami-0e3f1570eb0a9bc7f # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type = "t2.micro"
  key_name = "iac-key"

  security_groups = [ aws_security_group.allow_http.id ]
  associate_public_ip_address = true

   user_data = <<-EOF
                < /usr/share/nginx/html/index.html
                chkconfig nginx on
                service nginx start
              EOF


  lifecycle {
    create_before_destroy = true
  }
}


# I create a elb and a security group for my elb

resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "createdby-akeem"
  }
}

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.elb_http.id
  ]
  subnets = [
    aws_subnet.public_eu_north_1a.id,
    aws_subnet.public_eu_north_1b.id
  ]

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}

# I CRETAE AN AUTO SCALING GROUP

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 3
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [
    aws_subnet.public_eu_north_1a.id,
    aws_subnet.public_eu_north_1b.id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}

output "elb_dns_name" {
  value = aws_elb.web_elb.dns_name
}




module "vpc" {
  source = "./modules/vpc"
 
  infra_env = var.infra_env
}
