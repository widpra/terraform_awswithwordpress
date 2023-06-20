provider "aws" {
  region = "us-east-1"

}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_key_pair" "example" {
  key_name           = "onprem_keys"
  include_public_key = true

}

data "aws_acm_certificate" "issued" {
  domain   = "*.pkadel.com.np"
  statuses = ["ISSUED"]
}


resource "aws_vpc" "Terraform_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Terraform_vpc"
  }
}

resource "aws_subnet" "ter_Private_subnet1" {
  depends_on        = [aws_vpc.Terraform_vpc]
  vpc_id            = aws_vpc.Terraform_vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]

  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "ter_Private_subnet1"
  }
}

resource "aws_subnet" "ter_Public_subnet1" {
  depends_on = [aws_vpc.Terraform_vpc]

  vpc_id                  = aws_vpc.Terraform_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  cidr_block              = "10.0.2.0/24"
  tags = {
    Name = "ter_public_subnet1"

  }
}

resource "aws_subnet" "ter_Private_subnet2" {
  depends_on = [aws_vpc.Terraform_vpc]

  vpc_id            = aws_vpc.Terraform_vpc.id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.0.3.0/24"
  tags = {
    Name = "ter_Private_subnet2"
  }

}

resource "aws_subnet" "ter_Public_subnet2" {
  depends_on = [aws_vpc.Terraform_vpc]

  vpc_id            = aws_vpc.Terraform_vpc.id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.0.4.0/24"
  tags = {
    Name = "ter_public_subnet2"

  }
}

resource "aws_internet_gateway" "ter_IGW" {
  depends_on = [aws_vpc.Terraform_vpc]

  vpc_id = aws_vpc.Terraform_vpc.id
}


resource "aws_eip" "private" {
  domain = "vpc"
}

resource "aws_nat_gateway" "terr_natgateway" {
  depends_on = [aws_eip.private, aws_subnet.ter_Public_subnet1]

  connectivity_type = "public"
  subnet_id         = aws_subnet.ter_Public_subnet2.id
  allocation_id     = aws_eip.private.id
}


resource "aws_route_table" "Ter_publicroutetb" {
  vpc_id = aws_vpc.Terraform_vpc.id
  tags = {
    Name = "Terraform_public_route"

  }
}

resource "aws_route_table" "Ter_privateroutetb" {
  vpc_id = aws_vpc.Terraform_vpc.id
  tags = {
    Name = "Terraform_private_route"
  }
}


resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.ter_Private_subnet2.id
  route_table_id = aws_route_table.Ter_privateroutetb.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.ter_Private_subnet1.id
  route_table_id = aws_route_table.Ter_privateroutetb.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.ter_Public_subnet1.id
  route_table_id = aws_route_table.Ter_publicroutetb.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.ter_Public_subnet2.id
  route_table_id = aws_route_table.Ter_publicroutetb.id
}


resource "aws_route" "Ter_privateroute1" {
  route_table_id         = aws_route_table.Ter_privateroutetb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.terr_natgateway.id
}

resource "aws_route" "Ter_publicroute1" {
  route_table_id         = aws_route_table.Ter_publicroutetb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ter_IGW.id
}

resource "aws_security_group" "bastion_host" {
  name   = "Bastionhost_sg"
  vpc_id = aws_vpc.Terraform_vpc.id

  ingress {
    description = "SSH request"

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
}

resource "aws_security_group" "webserver_sg" {
  name   = "webserver_sg"
  vpc_id = aws_vpc.Terraform_vpc.id


  ingress {
    description = "SSH request"

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http request inbound"

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "https request inbound"

    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }



  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "aws_security_group" "mysql_sg" {
  name       = "myql_sg"
  depends_on = [aws_security_group.webserver_sg]
  vpc_id     = aws_vpc.Terraform_vpc.id

  ingress {
    description     = "MySQL Access"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver_sg.id]
  }
  ingress {
    description = "SSH request"

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PING to Webserver"
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Network Traffic from the MySQL instance
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "Bastionhost" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.ter_Public_subnet1.id
  vpc_security_group_ids = [aws_security_group.bastion_host.id]
  key_name               = data.aws_key_pair.example.key_name
  tags = {
    Name = "Bastion_host"
  }

}

resource "aws_instance" "webserver" {
  depends_on    = [aws_instance.mysql]
  ami           = "ami-09988af04120b3591"
  instance_type = "t2.micro" # associate_public_ip_address = true

  subnet_id              = aws_subnet.ter_Private_subnet2.id
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  key_name               = data.aws_key_pair.example.key_name

  user_data = <<-EOF
   #! /bin/bash
    sudo yum update -y
    sudo yum install docker -y
    sudo systemctl restart docker && sudo systemctl enable docker
    sudo docker pull wordpress
    sudo docker run --name wordpress -p 80:80 -e WORDPRESS_DB_HOST=${aws_instance.mysql.private_ip} -e WORDPRESS_DB_USER=root -e WORDPRESS_DB_PASSWORD=root -e WORDPRESS_DB_NAME=wordpressdb -d wordpress
  EOF

  tags = {
    Name = "Webserver"
  }


}

resource "aws_instance" "mysql" {
  ami                    = "ami-09988af04120b3591"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.ter_Private_subnet1.id
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  key_name               = data.aws_key_pair.example.key_name

  user_data = <<-EOF
 #! /bin/bash
sudo yum update
sudo yum install docker -y
sudo systemctl restart docker
sudo ystemctl enable docker
sudo docker pull mysql
sudo docker run --name mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=wordpressdb -p 3306:3306 -d mysql:5.7
EOF


  tags = {
    Name = "MYSQLserver"
  }


}


output "public_ip" {
  value = aws_instance.webserver.public_ip

}

output "privateip" {
  value = aws_instance.mysql.private_ip
}



# resource "aws_eip_association" "private" {
# # network_interface_id = aws_nat_gateway.terr_natgateway.network_interface_id
# # allocation_id = aws_eip.private.id
# }

resource "aws_security_group" "wordpress" {
  name_prefix = "wordpress"
  vpc_id      = aws_vpc.Terraform_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "elb_wp" {
  name               = "ELB-for-wordpress"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.ter_Public_subnet1.id, aws_subnet.ter_Public_subnet2.id]
  security_groups    = [aws_security_group.wordpress.id]



}

resource "aws_lb_target_group" "alb-example" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Terraform_vpc.id
}

# resource "aws_lb_listener" "front_end" {
#   load_balancer_arn = aws_lb.elb_wp.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.alb-example.arn
#   }
# }

resource "aws_lb_listener" "httpsredirect" {
  load_balancer_arn = aws_lb.elb_wp.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.issued.arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-example.arn
  }
}


resource "aws_lb_target_group_attachment" "test" {
  depends_on       = [aws_lb_target_group.alb-example, aws_instance.webserver]
  target_group_arn = aws_lb_target_group.alb-example.arn
  target_id        = aws_instance.webserver.id
  port             = 80
}

output "dns_name" {
  value = aws_lb.elb_wp.dns_name


}



data "aws_route53_zone" "selected" {
  name = "pkadel.com.np"

}
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "wordpress11.pkadel.com.np"
  type    = "A"

  alias {
    name                   = aws_lb.elb_wp.dns_name
    zone_id                = aws_lb.elb_wp.zone_id
    evaluate_target_health = true
  }
}


# resource "aws_launch_configuration" "example" {
#   image_id        = "ami-0261755bbcb8c4a84"
#   instance_type   = "t2.micro"
#   security_groups = [aws_security_group.wordpress.id]

# }

# resource "aws_autoscaling_group" "example" {
#   name                 = "example"
#   launch_configuration = aws_launch_configuration.example.id
#   min_size             = 1
#   max_size             = 1
#   desired_capacity     = 1
#   vpc_zone_identifier  = [aws_subnet.public.id]
#   load_balancers       = [aws_elb.example.name]

#   tag_specifications = {
#     resource_type = "instance"



#     tags = {
#       key   = "Name"
#       value = "Terraform"
#     }
#   }
# }
