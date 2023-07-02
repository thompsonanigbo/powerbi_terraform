provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA4VCBYGRLMDTV255Z"
  secret_key = "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"
}

# 1. create a VPC
resource "aws_vpc" "dashboard-vpc" {
  cidr_block       = "10.0.0.0/16"
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "production"
  }
}

# 2. create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dashboard-vpc.id

}

# 3. create a custom Route Table
resource "aws_route_table" "dashboard-route-table" {
  vpc_id = aws_vpc.dashboard-vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "prod"
  }
}


# 4. create a subnet for the ec2
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.dashboard-vpc.id
  cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
  tags = {
    Name = "prod-subnet"
  }
}

# 5. create subnets for the RDS
resource "aws_subnet" "rds-1" {
  vpc_id     = aws_vpc.dashboard-vpc.id
  cidr_block = "10.0.4.0/24"
    availability_zone = "us-east-1a"
  tags = {
    Name = "rds-1"
  }
}
resource "aws_subnet" "rds-2" {
  vpc_id     = aws_vpc.dashboard-vpc.id
  cidr_block = "10.0.5.0/24"
    availability_zone = "us-east-1b"
  tags = {
    Name = "rds-2"
  }
}
resource "aws_subnet" "rds-3" {
  vpc_id     = aws_vpc.dashboard-vpc.id
  cidr_block = "10.0.6.0/24"
    availability_zone = "us-east-1b"
  tags = {
    Name = "rds-3"
  }
}
# 6. create a subnet group for the rds.
resource "aws_db_subnet_group" "rds" {
  name       = "rds"
 
	subnet_ids = [aws_subnet.rds-1.id, aws_subnet.rds-2.id, aws_subnet.rds-3.id]
  tags = {
    Name = "rds"
  }
}

# 7. associate the ec2 subnet with the Route table
resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.dashboard-route-table.id
}
# 8. create security group to allow port 22, 80, 443, 3389, 1433, and icmp
resource "aws_security_group" "allow_web" {
    name = "allow_web_traffic"
    description = "allow web inbound traffic"
    vpc_id = aws_vpc.dashboard-vpc.id

    ingress {
      cidr_blocks = ["0.0.0.0/0"] 
      description = "HTTPS"
      from_port = 443
      protocol = "tcp"
      to_port = 443
    } 

    ingress {
      cidr_blocks = ["0.0.0.0/0"] 
      description = "HTTP"
      from_port = 80
      protocol = "tcp"
      to_port = 80
    } 
    ingress {
      cidr_blocks = ["0.0.0.0/0"] 
      description = "SSH"
      from_port = 22
      protocol = "tcp"
      to_port = 22
    } 

    ingress {
      cidr_blocks = ["0.0.0.0/0"] 
      description = "SSH"
      from_port = 3389
      protocol = "tcp"
      to_port = 3389
    } 
    ingress {
      cidr_blocks = ["0.0.0.0/0"] 
      description = "SSH"
      from_port = 1433
      protocol = "tcp"
      to_port = 1433
    } 
    ingress {
      cidr_blocks = ["0.0.0.0/0"] 
      description = "Allow all incoming ICMP - IPv4 traffic"
      from_port = -1
      protocol = "icmp"
      to_port = -1
    } 
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "allow_web"
    }
}
# 9. create a network interface with an IP in the subnet that was created in step 4
resource "aws_network_interface" "web-server-ni" {
    subnet_id = aws_subnet.subnet-1.id
    private_ips = ["10.0.1.50"]
    security_groups = [aws_security_group.allow_web.id] 
}
# 10. assign an elastic Ip to the network interface created in step 7
resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.web-server-ni.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [aws_internet_gateway.igw, aws_instance.dashboard-server]
}

# 11. create an S3 bucket.
resource "aws_s3_bucket" "stroke-bucket" {
  bucket = "stroke-bucket"
  
  tags = {
    Name = "strokedisease-bucket"
  }
}

# Upload an object
resource "aws_s3_object" "object" {

 bucket = aws_s3_bucket.stroke-bucket.id
  key    = "healthcare_stroke.csv"
  
  source = "C:/Users/THOMPSON ANIGBO/Downloads/healthcare_stroke.csv"

  etag = filemd5("C:/Users/THOMPSON ANIGBO/Downloads/healthcare_stroke.csv")

}
# 12. create a role for the EC2
resource "aws_iam_role" "ec2s3access_role" {
    name = "ec2_role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# 13. attach existing policy of full access to s3 bucket to the role created  
resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
    role       = aws_iam_role.ec2s3access_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 14. create an instance profile with the role such that any service can take up
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2s3access_role.name
}

# 15. create EC2 windows server and install Power Bi, SSMS, AWS CLI and download file from S3 bucket
resource "aws_instance" "dashboard-server" {
    ami = "ami-0bde1eb2c18cb2abe"
    instance_type = "t2.medium"
    availability_zone = "us-east-1a"
    key_name =  "main-key"
    iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-ni.id
    }
    user_data = <<-EOF
                <powershell>
                Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -Outfile C:\AWSCLIV2.msi
                $arguments = "/i `"C:\AWSCLIV2.msi`" /quiet"
                Start-Process msiexec.exe -ArgumentList $arguments -Wait
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
                aws s3 cp 's3://stroke-bucket/healthcare_stroke.csv' 'C:\Users\Administrator\Downloads\healthcare_stroke.csv'
                Invoke-Webrequest -Uri 'https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup_x64.exe' -Outfile 'C:\PBIDesktopSetup_x64.exe'  
                Start-Process -FilePath 'C:\PBIDesktopSetup_x64.exe' '-silent', '-norestart', 'ACCEPT_EULA=1'
                Invoke-Webrequest -Uri 'https://aka.ms/ssmsfullsetup' -Outfile 'C:\SSMS-Setup-ENU.exe'
                Start-Process -FilePath "C:\SSMS-Setup-ENU.exe" -ArgumentList "/Install /Quiet"
                </powershell>
                EOF
    tags = {   
        Name = "Dashboard-web-server"
    }
}



# 16. create a role for the RDS
resource "aws_iam_role" "rds_role" {
    name = "rds_role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "rds.amazonaws.com"
        }
      },
    ]
  })
}

# 17. attach an existing policy of full access to s3 bucket to the role created  
resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess2" {
    role       = aws_iam_role.rds_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 18. create an instance profile with the role such that the RDS service can take up
resource "aws_iam_instance_profile" "rds_profile" {
  name = "rds-profile"
  role = aws_iam_role.rds_role.name
}

# 19. RDS SQL Server Instance
resource "aws_db_instance" "StrokeDb" {
  allocated_storage    = 20
  engine               = "sqlserver-ex"
  engine_version       = "14.00.3451.2.v1"
  instance_class       = "db.t2.micro"
  identifier           = "stroke-database"
  username             = "admin"
  password             = "Munachimso%5"
  publicly_accessible    = true
  skip_final_snapshot    = true
  db_subnet_group_name = aws_db_subnet_group.rds.name

  vpc_security_group_ids = [aws_security_group.allow_web.id]

}

resource "aws_db_instance_role_association" "example" {
  db_instance_identifier = aws_db_instance.StrokeDb.id
  feature_name           = "S3_INTEGRATION"
  role_arn               = aws_iam_role.rds_role.arn
}