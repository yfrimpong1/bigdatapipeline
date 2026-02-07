FROM apache/spark-py:latest
USER root

# Move your real, heavy jars into the image
COPY ../../libs/hadoop-aws-3.3.4.jar /opt/spark/jars/
COPY ../../libs/aws-java-sdk-bundle-1.12.262.jar /opt/spark/jars/

# Force the classpath so the Hadoop S3A connector is found
ENV SPARK_DIST_CLASSPATH="/opt/spark/jars/hadoop-aws-3.3.4.jar:/opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar"

WORKDIR /app
COPY src/job.py .
RUN chmod 644 /opt/spark/jars/*.jar && chown -R 185:0 /opt/spark /app

USER 185