# analytics/outputs.tf
output "athena_database_name" {
  description = "Name of the Athena database"
  value       = aws_athena_database.vpc_logs.name
}

output "athena_table_name" {
  description = "Name of the Athena table"
  value       = aws_glue_catalog_table.vpc_flow_logs.name  # Updated to reference Glue table
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.vpc_logs.name
}