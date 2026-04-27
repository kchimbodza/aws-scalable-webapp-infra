# VPC
resource "aws_vpc" "webapp" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "webapp-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = 3

  vpc_id                  = aws_vpc.webapp.id
  cidr_block              = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"][count.index]
  availability_zone       = ["us-east-1a", "us-east-1b", "us-east-1c"][count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.webapp.id
  cidr_block        = ["10.0.4.0/24", "10.0.5.0/24"][count.index]
  availability_zone = ["us-east-1a", "us-east-1b"][count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
    Type = "private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "webapp" {
  vpc_id = aws_vpc.webapp.id

  tags = {
    Name = "webapp-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.webapp.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webapp.id
  }

  tags = {
    Name = "webapp-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.webapp.id

  tags = {
    Name = "webapp-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
