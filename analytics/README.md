# Analytics
This project sets up an analytics layer for querying VPC Flow Logs stored in S3 using AWS Athena and the AWS Glue Data Catalog. It enables troubleshooting of network issues by analyzing Parquet-formatted logs.

## Deploy
To deploy the analytics configuration:

```bash
cd analytics
tofu init
tofu apply
```

## This creates:
* An Athena database (vpc_logs_db)
* A Glue catalog table (vpc_flow_logs) for the Flow Logs in s3://opentofu-flow-logs-jason4151/
* An Athena workgroup (vpc-logs-workgroup) for running queries

## Query in Athena
To analyze VPC Flow Logs:

1. Navigate to the AWS Console > Athena.
2. Select the vpc_logs_db database and vpc_flow_logs table.
3. Run the following query to check for rejected traffic from the jump-box:

```sql
SELECT *
FROM vpc_flow_logs
WHERE srcaddr = '<ec2-instance-private-ip>'
AND dstport = 443
AND action = 'REJECT'
LIMIT 100;
```
Replace <ec2-instance-private-ip> with the appropriate private IP.