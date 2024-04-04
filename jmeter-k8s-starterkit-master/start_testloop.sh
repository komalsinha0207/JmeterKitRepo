#!/bin/bash

# Function to execute JMeter test sequentially
execute_sequentially() {
    local jmx_file="$1"
    local iterations="$2"

    for ((i=1; i<=iterations; i++)); do
        #./start_test.sh -j "$jmx_file" -i 1  # Assuming start_test.sh runs a single iteration
        ./start_test.sh -j "$jmx_file" -n default -c -m -i 1
        # Wait for the completion of the test (add more specific logic if needed)
        sleep 10  # Adjust as needed based on the expected test duration
    done
}

# Execute tests sequentially
execute_sequentially "DashboardTest.jmx" 3  # Replace 5 with the desired number of iterations