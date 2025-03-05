# athena/main.tf

# Data source to fetch VPC state (for consistency, optional)
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "opentofu-state-bucket-jason4151"
    key    = "vpc/terraform.tfstate"
    region = "us-east-2"
  }
}

# Athena Database
resource "aws_athena_database" "vpc_logs" {
  name   = "vpc_logs_db"
  bucket = "opentofu-flow-logs-jason4151"  # Same as your Flow Logs bucket
}

# Athena Workgroup
resource "aws_athena_workgroup" "vpc_logs" {
  name        = "vpc-logs-workgroup"
  description = "Workgroup for querying VPC Flow Logs"

  configuration {
    result_configuration {
      output_location = "s3://opentofu-flow-logs-jason4151/athena-results/"  # Where query results go
    }
  }

  tags = {
    Name        = "vpc-logs-workgroup"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Athena Table for VPC Flow Logs in Parquet
resource "aws_athena_table" "vpc_flow_logs" {
  name          = "vpc_flow_logs"
  database_name = aws_athena_database.vpc_logs.name

  table_type = "EXTERNAL_TABLE"

  # Define columns matching your Flow Log format (from vpc.tf log_format)
  schema = <<EOF
  `version` INT,
  `account_id` STRING,
  `interface_id` STRING,
  `srcaddr` STRING,
  `dstaddr` STRING,
  `srcport` INT,
  `dstport` INT,
  `protocol` BIGINT,
  `packets` BIGINT,
  `bytes` BIGINT,
  `start` BIGINT,
  `end` BIGINT,
  `action` STRING,
  `log_status` STRING
EOF

  # Partition by date for efficiency (assumes Hive-compatible prefixes from vpc.tf)
  partition_keys = [
    { name = "year", type = "string" },
    { name = "month", type = "string" },
    { name = "day", type = "string" },
    { name = "hour", type = "string" }
  ]

  # Point to your Flow Logs S3 bucket
  storage_descriptor {
    location      = "s3://opentofu-flow-logs-jason4151/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    serde_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
  }

  # Hive-compatible partitioning (matches your vpc.tf setup)
  tbl_properties = {
    "projection.enabled"         = "true"
    "projection.year.type"       = "integer"
    "projection.year.range"      = "2025,2030"  # Adjust range as needed
    "projection.month.type"      = "integer"
    "projection.month.range"     = "1,12"
    "projection.day.type"        = "integer"
    "projection.day.range"       = "1,31"
    "projection.hour.type"       = "integer"
    "projection.hour.range"      = "0,23"
    "storage.location.template"  = "s3://opentofu-flow-logs-jason4151/AWSLogs/${data.terraform_remote_state.vpc.outputs.account_id}/vpcflowlogs/us-east-2/$${year}/$${month}/$${day}/$${hour}"
  }

  depends_on = [aws_athena_database.vpc_logs]
}