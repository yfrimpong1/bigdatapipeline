from pyspark.sql import SparkSession # pyright: ignore[reportMissingImports]

spark = SparkSession.builder.appName("BigDataJob").getOrCreate()

df = spark.read.csv("s3a://yawbdata-raw/input/", header=True)
df.groupBy("country").count().write.mode("overwrite") \
  .parquet("s3a://yawbdata-processed/output/")

spark.stop()
