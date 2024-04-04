slave_array=(10.40.0.3); index=1 && while [ ${index} -gt 0 ]; do for slave in ${slave_array[@]}; do if echo 'test open port' 2>/dev/null > /dev/tcp/${slave}/1099; then echo ${slave}' ready' && slave_array=(${slave_array[@]/${slave}/}); index=$((index-1)); else echo ${slave}' not ready'; fi; done; echo 'Waiting for slave readiness'; sleep 2; done
echo "Installing needed plugins for master"
cd /opt/jmeter/apache-jmeter/bin
sh PluginsManagerCMD.sh install-for-jmx PetStoreAPIScriptDynamicBuildNumber500.jmx
echo "Done installing plugins, launching test"
jmeter -Ghost= -Gport= -Gprotocol= -Gthreads= -Gduration= -Grampup= --reportatendofloadtests --reportoutputfolder /report/report-PetStoreAPIScriptDynamicBuildNumber500.jmx-2024-01-16_100435 --logfile /report/PetStoreAPIScriptDynamicBuildNumber500.jmx_2024-01-16_100435.jtl --nongui --testfile PetStoreAPIScriptDynamicBuildNumber500.jmx -Dserver.rmi.ssl.disable=true --remoteexit --remotestart 10.40.0.3 >> jmeter-master.out 2>> jmeter-master.err &
trap 'kill -10 1' EXIT INT TERM
java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-master.out 2>> jmeter-master.err
echo "Starting load test at : Tue Jan 16 10:04:35 UTC 2024" && wait
