#!/bin/bash

# Output file for master logs
#MASTER_LOG_FILE= jmeterLogs/jmeter_master_logs_.txt

# Output directory for slave logs
#SLAVE_LOG_FILE="jmeterLogs/jmeter_slave_logs_${exec}.txt"

# Ensure the output directory exists
#mkdir -p $SLAVE_LOG_FILE

# Fetch and store JMeter master logs
#echo "Fetching logs from JMeter master pod..."
#kubectl logs -l jmeter_mode=master --namespace default > jmeterLogs/jmeter_master_logs_.txt
MASTER_PODS=$(kubectl get pods -l jmeter_mode=master --namespace default -o jsonpath='{.items[*].metadata.name}')

for MASTER_POD_NAME in $MASTER_PODS; do
echo "Fetching logs from JMeter master pod: $MASTER_POD_NAME..."
    filename=$(echo "$MASTER_POD_NAME" | sed 's/.*slaves\([^-]*\)-[^-]*$/\1/')
    kubectl logs $MASTER_POD_NAME --namespace default > jmeterLogs/jmeter_pod_logs_$MASTER_POD_NAME.txt
echo "Pod logs for $POD_NAME saved ---> jmeterLogs/jmeter_pod_logs_$MASTER_POD_NAME.txt"
done

#echo "JMeter master logs saved to: $MASTER_LOG_FILE"

# Fetch and store JMeter slave logs
echo "Fetching logs from JMeter pods..."
SLAVE_PODS=$(kubectl get pods -l jmeter_mode=slave --namespace default -o jsonpath='{.items[*].metadata.name}')

for POD_NAME in $SLAVE_PODS; do
    echo "Fetching logs from JMeter slave pod: $POD_NAME..."
    filename=$(echo "$POD_NAME" | sed 's/.*slaves\([^-]*\)-[^-]*$/\1/')
    kubectl logs $POD_NAME --namespace default > jmeterLogs/jmeter_pod_logs_$POD_NAME.txt
echo "Pod logs for $POD_NAME saved ---> jmeterLogs/jmeter_pod_logs_$POD_NAME.txt"
done

echo "Done copying the pod logs".

