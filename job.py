from pyspark.sql import SparkSession # pyright: ignore[reportMissingImports]

spark = SparkSession.builder.appName("BigDataJob").getOrCreate()

df = spark.read.csv("s3a://yaw-bdata-raw-bucket/input/", header=True)
df.groupBy("country").count().write.mode("overwrite") \
  .parquet("s3a://yaw-bdata-processed-bucket/output/")

spark.stop()
