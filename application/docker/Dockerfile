FROM apache/spark-py:latest
USER root

# Download S3 connector jars from Maven Central
# Hadoop AWS connector (includes S3A implementation)
RUN curl -fL -o /opt/spark/jars/hadoop-aws-3.3.4.jar \
  https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar

# AWS SDK for Java (required dependency)
RUN curl -fL -o /opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar \
  https://repo1.maven.org/maven2/software/amazon/awssdk/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar

# Force the classpath so the Hadoop S3A connector is found
ENV SPARK_DIST_CLASSPATH="/opt/spark/jars/hadoop-aws-3.3.4.jar:/opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar"

WORKDIR /app
COPY src/job.py .
RUN chmod 644 /opt/spark/jars/*.jar && chown -R 185:0 /opt/spark /app

USER 185