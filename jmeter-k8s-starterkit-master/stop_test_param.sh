#!/bin/bash

# Function to delete pods based on the provided parameter(s)
delete_pods() {
    local testid="$1"
    local NAMESPACE= "default"
    local master_pod="jmeter-master$testid"
    local slave_pod="jmeter-slaves$testid"

    # Delete jmeter-master pods
    master_pods=$(kubectl get pods -n default -l jmeter_mode=master -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "$master_pod")
    if [ -n "$master_pods" ]; then
        echo "Deleting jmeter-master pods matching the test id '$testid':"
        for pod in $master_pods; do
            echo "Deleting pod: $pod"
            kubectl delete pod "$pod"
        done
    else
        echo "No jmeter-master pods found matching the test id '$testid'"
    fi

    # Delete jmeter-slaves pods
    slave_pods=$(kubectl get pods -n default -l jmeter_mode=slave -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "$slave_pod")
    if [ -n "$slave_pods" ]; then
        echo "Deleting jmeter-slaves pods matching the test id '$testid':"
        for pod in $slave_pods; do
            echo "Deleting pod: $pod"
            kubectl delete pod "$pod"
        done
    else
        echo "No jmeter-slaves pods found matching the test id '$testid'"
    fi
}

# Check if any parameters are provided
if [ $# -eq 0 ]; then
    echo "Please provide one or more test id(s) to delete pods."
    exit 1
fi

# Iterate through provided parameters and delete pods
for testid in "$@"; do
    delete_pods "$testid"
done

