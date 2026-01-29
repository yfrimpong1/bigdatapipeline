# bigdatapipeline
Build big data Pipeline.

Execution Flow (What Happens When Jenkins Runs)

Jenkins pulls code from Git

Bash script:

Builds Docker image

Pushes image to ECR

Applies Spark job YAML to EKS

Spark Operator schedules job

Executors process big data

Results written to S3 / data lake