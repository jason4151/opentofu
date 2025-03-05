# analytics/main.tf
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "opentofu-state-bucket-jason4151"
    key    = "vpc/terraform.tfstate"
    region = "us-east-2"
  }
}

resource "aws_athena_database" "vpc_logs" {
  name   = "vpc_logs_db"
  bucket = "opentofu-flow-logs-jason4151"
}

resource "aws_athena_workgroup" "vpc_logs" {
  name        = "vpc-logs-workgroup"
  description = "Workgroup for querying VPC Flow Logs"

  configuration {
    result_configuration {
      output_location = "s3://opentofu-flow-logs-jason4151/athena-results/"
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

resource "aws_glue_catalog_table" "vpc_flow_logs" {
  database_name = aws_athena_database.vpc_logs.name
  name          = "vpc_flow_logs"
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://opentofu-flow-logs-jason4151/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "bigint"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start"
      type = "bigint"
    }
    columns {
      name = "end"
      type = "bigint"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }

  parameters = {
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2025,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.hour.type"      = "integer"
    "projection.hour.range"     = "0,23"
    "storage.location.template" = "s3://opentofu-flow-logs-jason4151/AWSLogs/${data.terraform_remote_state.vpc.outputs.account_id}/vpcflowlogs/us-east-2/$${year}/$${month}/$${day}/$${hour}"
  }

  depends_on = [aws_athena_database.vpc_logs]
}