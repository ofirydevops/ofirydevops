data "aws_vpc" "default" {
  default = true
}

# Get all route tables with internet gateway routes (public route tables)
data "aws_route_tables" "public" {
  vpc_id = data.aws_vpc.default.id
  
  filter {
    name   = "route.destination-cidr-block"
    values = ["0.0.0.0/0"]
  }
  
  filter {
    name   = "route.gateway-id"
    values = ["igw-*"]
  }
}

# Get details for each public route table to access associations
data "aws_route_table" "public_details" {
  for_each       = toset(data.aws_route_tables.public.ids)
  route_table_id = each.value
}

# Extract subnet IDs from route table associations
locals {
  vpc_id = data.aws_vpc.default.id
  
  # Get subnet IDs from public route table associations
  public_subnet_ids = toset(flatten([
    for rt in data.aws_route_table.public_details : [
      for assoc in rt.associations : assoc.subnet_id
      if assoc.subnet_id != null && assoc.subnet_id != ""
    ]
  ]))
}