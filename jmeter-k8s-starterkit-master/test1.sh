#!/usr/bin/env bash

while [[ $(kubectl  get pods -l jmeter_mode=master -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status} {..job-name}' | grep jmeter-master20-06-23-21 | awk '{print $1}') != "True" ]]; do echo "$(kubectl  get pods -l jmeter_mode=master )" && sleep 1; done

