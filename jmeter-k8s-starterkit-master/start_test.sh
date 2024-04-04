#!/usr/bin/env bash

#=== FUNCTION ================================================================
#        NAME: logit
# DESCRIPTION: Log into file and screen.
# PARAMETER - 1 : Level (ERROR, INFO)
#           - 2 : Message
#
#===============================================================================
logit()
{
    case "$1" in
        "INFO")
            echo -e " [\e[94m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ] $2 \e[0m" ;;
        "WARN")
            echo -e " [\e[93m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  \e[93m $2 \e[0m " && sleep 2 ;;
        "ERROR")
            echo -e " [\e[91m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  $2 \e[0m " ;;
    esac
}

#=== FUNCTION ================================================================
#        NAME: usage
# DESCRIPTION: Helper of the function
# PARAMETER - None
#
#===============================================================================
# Default value for test duration
#test_duration=1
usage()
{
  logit "INFO" "-t <test_duration>"
  logit "INFO" "-j <filename.jmx>"
  logit "INFO" "-n <namespace>"
  logit "INFO" "-c flag to split and copy csv if you use csv in your test"
  logit "INFO" "-m flag to copy fragmented jmx present in scenario/project/module if you use include controller and external test fragment"
  logit "INFO" "-i <injectorNumber> to scale slaves pods to the desired number of JMeter injectors"
  logit "INFO" "-r flag to enable report generation at the end of the test"
  exit 1
}

### Parsing the arguments ###
while getopts 'i:mj:hcrn:t:' option;
    do
      case $option in
        n	)	namespace=${OPTARG}   ;;
        c   )   csv=1 ;;
        m   )   module=1 ;;
        r   )   enable_report=1 ;;
        j   )   jmx=${OPTARG} ;;
        i   )   nb_injectors=${OPTARG} ;;
        h   )   usage ;;
        t   )   test_duration=${OPTARG} ;;
        ?   )   usage ;;
      esac
done

if [ "$#" -eq 0 ]
  then
    usage
fi

### CHECKING VARS ###
if [ -z "${namespace}" ]; then
    logit "ERROR" "Namespace not provided!"
    usage
    namespace=$(awk '{print $NF}' "${PWD}/namespace_export")
fi

if [ -z "${jmx}" ]; then
    #read -rp 'Enter the name of the jmx file ' jmx
    logit "ERROR" "jmx jmeter project not provided!"
    usage
fi


jmx_dir="${jmx%%.*}"

if [ ! -f "scenario/${jmx_dir}/${jmx}" ]; then
    logit "ERROR" "Test script file was not found in scenario/${jmx_dir}/${jmx}"
    usage
fi

# Validate if the provided value for test duration is a positive whole number
if [ -n "${test_duration}" ]; then
if ! [[ "${test_duration}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Please provide a valid positive whole number for test duration using -t flag."
    exit 1
else
echo "------> into else ---->"
sed -i "s/<stringProp name=\"ThreadGroup.duration\">[0-9]\{1,\}<\/stringProp>/<stringProp name=\"ThreadGroup.duration\">${test_duration}<\/stringProp>/g" "scenario/${jmx_dir}/${jmx}"
fi
fi
master_list=($(kubectl get pods -n "${namespace}" | grep jmeter-master | grep Running | awk '{print $1}'))
master_num=${#master_list[@]}

exec_num=$(TZ="Asia/Kolkata" date +%m-%d-%H-%M-%S)
echo "Data: ${exec_num}"
cd ./k8s/jmeter/
cat jmeter-master_template.txt | sed -e "s/<exec_num>/$exec_num/" >> jmeter-master${exec_num}.yml
cat jmeter-slave_template.txt | sed -e "s/<exec_num>/${exec_num}/" >> jmeter-slave${exec_num}.yml
#sed -i "s/completions: .*/completions: ${nb_injectors}/" jmeter-slave${exec_num}.yml
sed -i "s/<completions>/${nb_injectors}/" jmeter-slave${exec_num}.yml
cd ../../

sed -i "s/~~Generated--Id~~/${exec_num}/g" scenario/${jmx_dir}/${jmx}

#master_num_plus_one=$(expr ${master_num} + 1)
master_num_plus_one=${exec_num}
logit "INFO" "master_num_plus_one::${master_num_plus_one}"

# Check the list of existing pods ip addresses
slave_ip_list=$(kubectl -n ${namespace} describe endpoints jmeter-slaves-svc | grep ' Addresses' | awk -F" " '{print $2}')
logit "INFO" "JMeter slave list : ${slave_ip_list}"
slave_ip_array=($(echo ${slave_ip_list} | sed 's/,/ /g'))

# Recreating each pods
logit "INFO" "Recreating pod set"
kubectl -n "${namespace}" delete -f k8s/jmeter/jmeter-master${master_num_plus_one}.yml -f k8s/jmeter/jmeter-slave${master_num_plus_one}.yml 2> /dev/null
kubectl -n "${namespace}" apply -f k8s/jmeter/jmeter-master${master_num_plus_one}.yml -f k8s/jmeter/jmeter-slave${master_num_plus_one}.yml
#kubectl -n "${namespace}" patch job jmeter-slaves${master_num_plus_one} -p '{"spec":{"parallelism":0}, {"completions":'${nb_injectors}'}}'
kubectl -n "${namespace}" patch job jmeter-slaves${master_num_plus_one} -p '{"spec":{"parallelism":0}}'

logit "INFO" "Waiting for all slaves pods to be terminated before recreating the pod set kubectl get pods -l jmeter_mode=slave -o 'jsonpath={.items[?(@.metadata.labels.job-name==\"jmeter-slaves${master_num_plus_one}\")].status.conditions[?(@.type==\"Ready\")].status}'"

while [[ $(kubectl get pods -l jmeter_mode=slave -o 'jsonpath={.items[?(@.metadata.labels.job-name=="jmeter-slaves${master_num_plus_one}")].status.conditions[?(@.type=="Ready")].status}') != "" ]]; do echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=slave )" && sleep 1; done
###-is this needed - kubectl -n ${namespace} get pods -l jmeter_mode=slave -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status} {..job-name}' | grep jmeter-slaves${master_num_plus_one} | awk '{print $1}'
###- kubectl get pods -l jmeter_mode=slave -o 'jsonpath={.items[?(@.metadata.labels.job-name=="jmeter-slaves${master_num_plus_one}")].status.conditions[?(@.type=="Ready")].status}'



# Starting jmeter slave pod 

if [ -z "${nb_injectors}" ]; then
    logit "WARNING" "Keeping number of injector to 1"
    kubectl -n "${namespace}" patch job jmeter-slaves${master_num_plus_one} -p '{"spec":{"parallelism":1}}'
else
    logit "INFO" "Scaling the number of pods to ${nb_injectors}. "
    kubectl -n "${namespace}" patch job jmeter-slaves${master_num_plus_one} -p '{"spec":{"parallelism":'${nb_injectors}'}}'
    logit "INFO" "Waiting for pods to be ready"

    end=${nb_injectors}

	logit "INFO" "validation_string:::==============${validation_string}"
	kubectl -n ${namespace} get pods -l jmeter_mode=slave -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status} {..job-name}' | grep jmeter-slaves${master_num_plus_one} | awk '{print $1}' | sed 's/ //g'


    for ((i=1; i<=end; i++))
    do
        validation_string=${validation_string}"True"
        validation_string2=${validation_string2}"Running"
    done
    echo "=============================================${validation_string2}"
#    while [[ $(kubectl -n ${namespace} get pods -l jmeter_mode=slave -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status} {..job-name}' | grep jmeter-slaves${master_num_plus_one} | awk '{print $1}' | sed 's/ //g') != "${validation_string}" ]]; do echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=slave )" && sleep 1; done

    while [[ $(kubectl -n ${namespace} get pods | grep jmeter-slaves${master_num_plus_one} | grep Running | awk '{print $3}' | awk 'NR%9{printf "%s ",$0;next;}1' | sed 's/ //g') != "${validation_string2}" ]]; do echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=slave )" && sleep 1; done

    ###--- kubectl -n ${namespace} get pods -l jmeter_mode=master -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status} {..job-name}' | grep jmeter-master1 | awk '{print $1}'
    logit "INFO" "Finish scaling the number of pods."
fi

#Get Master pod details
logit "INFO" "Waiting for master pod to be available"
### while [[ $(kubectl -n ${namespace} get pods -l jmeter_mode=master -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=master )" && sleep 1; done

kubectl -n ${namespace} get pods -l jmeter_mode=slave | grep jmeter-slaves${master_num_plus_one}

while [[ $(kubectl -n ${namespace} get pods -l jmeter_mode=master -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status} {..job-name}' | grep jmeter-master${master_num_plus_one} | awk '{print $1}') != "True" ]]; do echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=master )" && sleep 1; done
master_pod=$(kubectl get pod -n "${namespace}" | grep jmeter-master${master_num_plus_one} | awk '{print $1}')

kubectl get pods -n "${namespace}" | grep jmeter-slaves${master_num_plus_one} | grep Running | awk '{print $1}'

#Get Slave pod details
slave_pods=($(kubectl get pods -n "${namespace}" | grep jmeter-slaves${master_num_plus_one} | grep Running | awk '{print $1}'))
slave_num=${#slave_pods[@]}
slave_digit="${#slave_num}"

logit "INFO" "slave_pods:::::::::${slave_pods[@]}"

# jmeter directory in pods
jmeter_directory="/opt/jmeter/apache-jmeter/bin"
kubectl cp /home/ubuntu/new_platform_files/jmeter-k8s-starterkit-master/log4j2.xml default/${master_pod}:/opt/jmeter/apache-jmeter-5.4.1/bin/log4j2.xml
# Copying module and config to pods
if [ -n "${module}" ]; then
    logit "INFO" "Using modules (test fragments), uploading them in the pods"
    module_dir="scenario/module"

    logit "INFO" "Number of slaves is ${slave_num}"
    logit "INFO" "Processing directory.. ${module_dir}"

    for modulePath in $(ls ${module_dir}/*.jmx)
    do
        module=$(basename "${modulePath}")

        for ((i=0; i<end; i++))
        do
            printf "Copy %s to %s on %s\n" "${module}" "${jmeter_directory}/${module}" "${slave_pods[$i]}"
            kubectl -n "${namespace}" cp -c jmeter-slave "${modulePath}" "${slave_pods[$i]}":"${jmeter_directory}/${module}" &
        done            
        kubectl -n "${namespace}" cp -c jmeter-master "${modulePath}" "${master_pod}":"${jmeter_directory}/${module}" &
    done

    logit "INFO" "Finish copying modules in slave pod"
fi

logit "INFO" "Copying ${jmx} to slaves pods"
logit "INFO" "Number of slaves is ${slave_num}"

for ((i=0; i<end; i++))
do
    logit "INFO" "Copying scenario/${jmx_dir}/${jmx} to ${slave_pods[$i]}"
    kubectl cp -c jmeter-slave "scenario/${jmx_dir}/${jmx}" -n "${namespace}" "${slave_pods[$i]}:/opt/jmeter/apache-jmeter/bin/" &

    kubectl cp -c jmeter-slave "JMeter-InfluxDB-Writer-plugin-1.2.2.jar" -n "${namespace}" "${slave_pods[$i]}:/opt/jmeter/apache-jmeter-5.4.1/lib/ext/" &
    kubectl cp -c jmeter-slave "JMeter-InfluxDB-Writer-plugin-1.2.2.jar" -n "${namespace}" "${slave_pods[$i]}:/opt/jmeter/apache-jmeter/lib/ext/" &

done # for i in "${slave_pods[@]}"
logit "INFO" "Finish copying scenario in slaves pod"

logit "INFO" "Copying scenario/${jmx_dir}/${jmx} into ${master_pod}"
kubectl cp -c jmeter-master "scenario/${jmx_dir}/${jmx}" -n "${namespace}" "${master_pod}:/opt/jmeter/apache-jmeter/bin/" &

kubectl cp -c jmeter-master "JMeter-InfluxDB-Writer-plugin-1.2.2.jar" -n "${namespace}" "${master_pod}:/opt/jmeter/apache-jmeter-5.4.1/lib/ext/" &
kubectl cp -c jmeter-master "JMeter-InfluxDB-Writer-plugin-1.2.2.jar" -n "${namespace}" "${master_pod}:/opt/jmeter/apache-jmeter/lib/ext/" &


logit "INFO" "Installing needed plugins on slave pods"

## Starting slave pod 

{
    echo "cd ${jmeter_directory}"
    echo "sh PluginsManagerCMD.sh install-for-jmx ${jmx} > plugins-install.out 2> plugins-install.err"
    echo "jmeter-server -Dserver.rmi.localport=50000 -Dserver_port=1099 -Jserver.rmi.ssl.disable=true >> jmeter-injector.out 2>> jmeter-injector.err &"
    echo "trap 'kill -10 1' EXIT INT TERM"
    echo "java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-injector.out 2>> jmeter-injector.err"
    echo "wait"
} > "scenario/${jmx_dir}/jmeter_injector_start.sh"

# Copying dataset on slave pods
if [ -n "${csv}" ]; then
    logit "INFO" "Splitting and uploading csv to pods"
    dataset_dir=./scenario/dataset

    for csvfilefull in $(ls ${dataset_dir}/*.csv)
        do
            logit "INFO" "csvfilefull=${csvfilefull}"
            csvfile="${csvfilefull##*/}"
            logit "INFO" "Processing file.. $csvfile"
            lines_total=$(cat "${csvfilefull}" | wc -l)
            logit "INFO" "split --suffix-length=\"${slave_digit}\" -d -l $((lines_total/slave_num)) \"${csvfilefull}\" \"${csvfilefull}/\""
            split --suffix-length="${slave_digit}" -d -l $((lines_total/slave_num)) "${csvfilefull}" "${csvfilefull}"

            for ((i=0; i<end; i++))
            do
                if [ ${slave_digit} -eq 2 ] && [ ${i} -lt 10 ]; then
                    j=0${i}
                elif [ ${slave_digit} -eq 2 ] && [ ${i} -ge 10 ]; then
                    j=${i}
                elif [ ${slave_digit} -eq 3 ] && [ ${i} -lt 10 ]; then
                    j=00${i}
                elif [ ${slave_digit} -eq 3 ] && [ ${i} -ge 10 ]; then
                    j=0${i}
                elif [ ${slave_digit} -eq 3 ] && [ ${i} -ge 100 ]; then
                    j=${i}
                else 
                    j=${i}                    
                fi

                printf "Copy %s to %s on %s\n" "${csvfilefull}${j}" "${csvfile}" "${slave_pods[$i]}"
                kubectl -n "${namespace}" cp -c jmeter-slave "${csvfilefull}${j}" "${slave_pods[$i]}":"${jmeter_directory}/${csvfile}" &
            done
    done
fi

wait

for ((i=0; i<end; i++))
do
        logit "INFO" "Starting jmeter server on ${slave_pods[$i]} in parallel"
        kubectl cp -c jmeter-slave "scenario/${jmx_dir}/jmeter_injector_start.sh" -n "${namespace}" "${slave_pods[$i]}:/opt/jmeter/jmeter_injector_start"
        kubectl exec -c jmeter-slave -i -n "${namespace}" "${slave_pods[$i]}" -- /bin/bash "/opt/jmeter/jmeter_injector_start" &  
done


slave_list=$(kubectl -n ${namespace} describe endpoints jmeter-slaves-svc | grep ' Addresses' | awk -F" " '{print $2}')
logit "INFO" "JMeter slave list : ${slave_list}"
slave_array=($(echo ${slave_list} | sed 's/,/ /g'))

for del_ip in ${slave_ip_array[@]}
do
   slave_array=("${slave_array[@]/$del_ip}")
done
echo "After removal - slave_array_IPs ${slave_array[@]}"
slave_array_final=(${slave_array[@]})
echo "After removal - slave_array_IPs ${slave_array_final[@]}"


## Starting Jmeter load test
source "scenario/${jmx_dir}/.env"

param_host="-Ghost=${host} -Gport=${port} -Gprotocol=${protocol}"
param_test="-GtimeoutConnect=${timeoutConnect} -GtimeoutResponse=${timeoutResponse}"
param_user="-Gthreads=${threads} -Gduration=${duration} -Grampup=${rampup}"


if [ -n "${enable_report}" ]; then
    report_command_line="--reportatendofloadtests --reportoutputfolder /report/report-${jmx}-$(date +"%F_%H%M%S")"
fi

sed -i "s/${exec_num}/~~Generated--Id~~/g" scenario/${jmx_dir}/${jmx}

echo "slave_array=(${slave_array_final[@]}); index=${slave_num} && while [ \${index} -gt 0 ]; do for slave in \${slave_array[@]}; do if echo 'test open port' 2>/dev/null > /dev/tcp/\${slave}/1099; then echo \${slave}' ready' && slave_array=(\${slave_array[@]/\${slave}/}); index=\$((index-1)); else echo \${slave}' not ready'; fi; done; echo 'Waiting for slave readiness'; sleep 2; done" > "scenario/${jmx_dir}/load_test.sh"

{ 
    echo "echo \"Installing needed plugins for master\""
    echo "cd /opt/jmeter/apache-jmeter/bin" 
    echo "sh PluginsManagerCMD.sh install-for-jmx ${jmx}" 
    echo "echo \"Done installing plugins, launching test\""
    echo "jmeter ${param_host} ${param_user} ${report_command_line} --logfile /report/${jmx}_$(date +"%F_%H%M%S").jtl --nongui --testfile ${jmx} -Dserver.rmi.ssl.disable=true --remoteexit --remotestart ${slave_array_final} >> jmeter-master.out 2>> jmeter-master.err &"
    echo "trap 'kill -10 1' EXIT INT TERM"
    echo "java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-master.out 2>> jmeter-master.err"
    echo "echo \"Starting load test at : $(date)\" && wait"
} >> "scenario/${jmx_dir}/load_test.sh"
logit "INFO" "Copying scenario/${jmx_dir}/load_test.sh into  ${master_pod}:/opt/jmeter/load_test"
kubectl cp -c jmeter-master "scenario/${jmx_dir}/load_test.sh" -n "${namespace}" "${master_pod}:/opt/jmeter/load_test"
#touch /home/ubuntu/new_platform_files/jmeter-k8s-starterkit-master/jmetr/jmeterLogs/container_logs_${exec_num}.txt
kubectl logs -f -c jmeter-master -n default ${master_pod} > /home/ubuntu/new_platform_files/jmeter-k8s-starterkit-master/jmeterLogs/container_logs_${exec_num}.txt &
echo "_____________>>>>>>${master_pod}"
#sleep 600
#kubectl exec -ti "${master_pod}" -- chmod -R a+rwx "/report"
#  the directory where .jtl file is stored locally
#local_directory="/jmeterLogs"
# Copying the .jtl file from the master pod to the local machine
#echo "kubectl cp -c jmeter-master -n "${namespace}" "${master_pod}:report/${jmx}_$(date +"%F_%H%M%S").jtl" "${local_directory}""
logit "INFO" "Starting the performance test"
logit "INFO" "##################################################"
#sleep 500
logit "INFO" "You can follow test execution summary on the master pod by running :"
logit "INFO" "         kubectl logs -f -c jmeter-master -n ${namespace} ${master_pod}"
logit "INFO" "##################################################"
logit "INFO" "Also using Grafana : kubectl ${namespace} port-forward svc/grafana 8443:443"
#echo "Copying jmeter_.log file from ${master_pod} pod in ${namespace} namespace..."
#sleep 300
#kubectl exec -it ${master_pod} -n default -- ls -l /jmeter | wc -l
GRAFANA_LOGIN=$(kubectl -n "${namespace}" get secret grafana-creds -o yaml | grep GF_SECURITY_ADMIN_USER: | awk -F" " '{print $2}' | base64 --decode)
GRAFANA_PASSWORD=$(kubectl -n "${namespace}" get secret grafana-creds -o yaml | grep GF_SECURITY_ADMIN_PASSWORD: | awk -F" " '{print $2}' | base64 --decode)
logit "INFO" " LOGIN : ${GRAFANA_LOGIN}"
logit "INFO" " PASSWORD : ${GRAFANA_PASSWORD}"


 # Copy the file using kubectl cp
sleep 40
./pod_logs.sh
echo "Starting to copy jmeter.log file. This might take a while...."
# Loop until the JMeter pod is up
while true; do
    # Check if the JMeter pod is running
    if kubectl get pod -n "default" ${master_pod} &> /dev/null; then
kubectl cp default/${master_pod}:/jmeter/jmeter-log.log /home/ubuntu/new_platform_files/jmeter-k8s-starterkit-master/jmeterLogs/jmeter_log_${exec_num}.log &> /dev/null
else
        # If the JMeter pod is not running, exit the loop
        echo "Jmeter.log file copied successfully. Path---> /home/ubuntu/new_platform_files/jmeter-k8s-starterkit-master/jmeterLogs/jmeter_log_${exec_num}.log"
        exit 1
    fi
done
#echo "Jmeter.log file copied successfully. Path---> /home/ubuntu/new_platform_files/jmeter-k8s-starterkit-master/jmeterLogs/jmeter_log_${exec_num}.log"
logit "INFO" "################################################"

