
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


resource "aws_cloudwatch_metric_alarm" "cwm-alarm" {
  alarm_name                = "terraform-test-cwm-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []
}





