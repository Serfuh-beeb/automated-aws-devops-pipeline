resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet"
  subnet_ids = aws_subnet.database[*].id
  tags       = { Name = "${var.project}-db-subnet" }
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project}-db"
  engine                 = "postgres"
  engine_version         = "15.13"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  tags                   = { Name = "${var.project}-db" }
}
