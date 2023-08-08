Creates 2 buckets with versioning enabled
*  versioning is now its own resource in Terraform, which is new and interesting
* it also creates one lambda, with:
    x) an IAM role, and an IAM policy
    x) a datasource to zip the python file up, for upload as a Lambda
    x) a trigger, on the source S3 bucket, that triggers the Lambda; and an IAM permission for that

---
Updates: added logging to the python file
- CloudWatch / log groups need to be set up