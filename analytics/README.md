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

## Potential Future Expansions
The `analytics` project can grow beyond its current scope. Here are some possibilities:

- Integrate CloudTrail logs from S3 to audit API calls alongside VPC Flow Logs.
- Catalog application logs from EC2 instances or services (e.g., web servers) in S3 for analysis.
- Export CloudWatch Metrics (e.g., EC2 CPU usage) to S3 for querying with Athena.
- Create Amazon QuickSight dashboards to visualize Flow Log trends, manageable via Terraform.
- Use Grafana (AWS Managed Grafana) with Athena for real-time network dashboards.
- Implement AWS Glue Jobs to transform logs (e.g., add IP geolocation data).
- Apply SageMaker for anomaly detection on Flow Logs, storing results in S3.
- Analyze AWS Cost Explorer data in S3 to track lab expenses with Athena.
- Set up Terraform-managed budget alerts based on analytics outputs.
- Query GuardDuty findings in S3 to cross-reference with Flow Logs for security insights.
- Feed Athena query results into SNS or Lambda for custom alerts (e.g., high reject rates).
- Aggregate logs from multiple VPCs (e.g., dev, test) in S3 for unified querying.