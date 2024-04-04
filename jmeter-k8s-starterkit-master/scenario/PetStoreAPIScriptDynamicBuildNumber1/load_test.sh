slave_array=(10.35.0.15); index=1 && while [ ${index} -gt 0 ]; do for slave in ${slave_array[@]}; do if echo 'test open port' 2>/dev/null > /dev/tcp/${slave}/1099; then echo ${slave}' ready' && slave_array=(${slave_array[@]/${slave}/}); index=$((index-1)); else echo ${slave}' not ready'; fi; done; echo 'Waiting for slave readiness'; sleep 2; done
echo "Installing needed plugins for master"
cd /opt/jmeter/apache-jmeter/bin
sh PluginsManagerCMD.sh install-for-jmx PetStoreAPIScriptDynamicBuildNumber1.jmx
echo "Done installing plugins, launching test"
jmeter -Ghost= -Gport= -Gprotocol= -Gthreads= -Gduration= -Grampup= --reportatendofloadtests --reportoutputfolder /report/report-PetStoreAPIScriptDynamicBuildNumber1.jmx-2024-04-04_103230 --logfile /report/PetStoreAPIScriptDynamicBuildNumber1.jmx_2024-04-04_103230.jtl --nongui --testfile PetStoreAPIScriptDynamicBuildNumber1.jmx -Dserver.rmi.ssl.disable=true --remoteexit --remotestart 10.35.0.15 >> jmeter-master.out 2>> jmeter-master.err &
trap 'kill -10 1' EXIT INT TERM
java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-master.out 2>> jmeter-master.err
echo "Starting load test at : Thu Apr  4 10:32:30 UTC 2024" && wait
