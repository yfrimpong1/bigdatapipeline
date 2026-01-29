FROM apache/spark-py

WORKDIR /app
COPY job.py /app/job.py
