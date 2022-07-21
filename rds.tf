resource "aws_db_instance" "default" {
  depends_on             = ["aws_security_group.db-sg"]
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  db_subnet_id           = "aws_subnet.eu_north_1c.id"
  availability_zone      = "eu-north-1b"
  name                   = "mydb"
  username               = "foo"
  password               = "foobarbaz"
  publicly_accessible    = "false" 
}
