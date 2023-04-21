# powerbi_terraform
#create an AWS account and create the access keys for a user or root user.
#create key pairs from EC2.
I created one named "main-key"

# 1. on terraform, use the provider configuration code to enable terraform to download the plugin to connect to that provider.
	provider "aws" {
  		region = "us-east-1"
  		access_key = "xxxxxxxxxxxxxxxxx"
  		secret_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
	
	}


# 2. create a VPC
	resource "aws_vpc" "dashboard-vpc" {
  		cidr_block       = "10.0.0.0/16"
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
# 4. create a subnet
resource "aws_subnet" "subnet-1" {
 	vpc_id     = aws_vpc.dashboard-vpc.id
 	cidr_block = "10.0.1.0/24"
    	availability_zone = "us-east-1a"
  	tags = {
    	Name = "prod-subnet"
	}
}
# 5. associate the subnet with the Route table
resource "aws_route_table_association" "a" {
    	subnet_id = aws_subnet.subnet-1.id
    	route_table_id = aws_route_table.dashboard-route-table.id
}
# 6. create security group to allow port 22, 80, 443
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
# 7. create a network interface with an IP in the subnet that was created in step 4
resource "aws_network_interface" "web-server-ni" {
    subnet_id = aws_subnet.subnet-1.id
    private_ips = ["10.0.1.50"]
    security_groups = [aws_security_group.allow_web.id] 
}
# 8. assign an elastic Ip to the network interface created in step 7
resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.web-server-ni.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [aws_internet_gateway.igw]
}
# 9. create windows server and install/enable apache2
resource "aws_instance" "dashboard-server" {
    		ami = "ami-007855ac798b5175e"
    		instance_type = "t2.micro"
      	availability_zone = "us-east-1a" 
    		key_name =  "main-key"

    		network_interface {
        		device_index = 0
        		network_interface_id = aws_network_interface.web-server-ni.id
    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemct1 start apache2
                sudo bash -c 'echo your very fisrt web server > /var/www/html/index.html' 
                EOF


    user_data = <<-EOF
                <powershell>
                Invoke-Webrequest “https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup_x64.exe” -Outfile “C:\PBIDesktopSetup_x64.exe”
                Start-Process -FilePath "C:\PBIDesktopSetup_x64.exe" "-silent", "-norestart", "ACCEPT_EULA=1"
                </powershell>
                EOF

    user_data = <<-EOF
                <powershell>
                Install-WindowsFeature -name Web-Server -IncludeManagementTools
                New-Item -Path C:\inetpub\wwwroot\index.html -ItemType File -Value "Shivam open knowledge center welcomes you" -Force
                </powershell>
                EOF




    tags = {
      Name = "Dashboard-web-server"
    }
}
   	}

10. #create an S3 bucket or amazon RDS to store the data.
11. #connect to the data source from the Power BI desktop using the direct query option
12. #perform ETL and create model the data 
13. #develop the visualisation for the report/dashboard
14. #publish the report to power BI service (workspace)
15. #create the dashboard and app
16. #share the dashboard with users in same workgroup.
 
