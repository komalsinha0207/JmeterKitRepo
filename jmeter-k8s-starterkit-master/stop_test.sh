#!/bin/bash

# Define the namespace where JMeter pods are running
NAMESPACE="default"

# Get the list of JMeter master and slave pods running in the namespace
JMETER_MASTER_PODS=$(kubectl get pods -n $NAMESPACE -l jmeter_mode=master -o jsonpath='{.items[*].metadata.name}')
JMETER_SLAVE_PODS=$(kubectl get pods -n $NAMESPACE -l jmeter_mode=slave -o jsonpath='{.items[*].metadata.name}')

# Check if there are any JMeter pods running
if [ -z "$JMETER_MASTER_PODS" ] && [ -z "$JMETER_SLAVE_PODS" ]; then
    echo "No JMeter pods are currently running in the namespace $NAMESPACE"
    exit 0
fi

# Delete the JMeter Master pods
if [ -n "$JMETER_MASTER_PODS" ]; then
    for MPOD in $JMETER_MASTER_PODS; do
        echo "Deleting pod: $MPOD"
        kubectl delete pod $MPOD -n $NAMESPACE
    done
fi

if [ -n "$JMETER_SLAVE_PODS" ]; then
    for SPOD in $JMETER_SLAVE_PODS; do
        echo "Deleting pod: $SPOD"
        kubectl delete pod $SPOD -n $NAMESPACE
    done
fi

# Monitor the status of the pods to ensure they have been terminated
while true; do
    TERMINATED=$(kubectl get pods -n $NAMESPACE -l 'jmeter_mode in (master,slave)' --field-selector=status.phase!=Running -o jsonpath='{.items[*].metadata.name}')
    if [ -z "$TERMINATED" ]; then
        echo "All JMeter pods have been terminated."
        break
    else
        echo "Waiting for the following pods to be terminated: $TERMINATED"
        sleep 5
    fi
done

echo "Script execution completed."

