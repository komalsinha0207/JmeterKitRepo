slave_array=(10.44.0.10 10.44.0.8 10.44.0.9); index=3 && while [ ${index} -gt 0 ]; do for slave in ${slave_array[@]}; do if echo 'test open port' 2>/dev/null > /dev/tcp/${slave}/1099; then echo ${slave}' ready' && slave_array=(${slave_array[@]/${slave}/}); index=$((index-1)); else echo ${slave}' not ready'; fi; done; echo 'Waiting for slave readiness'; sleep 2; done
echo "Installing needed plugins for master"
cd /opt/jmeter/apache-jmeter/bin
sh PluginsManagerCMD.sh install-for-jmx PetStoreAPIScriptLoad100User.jmx
echo "Done installing plugins, launching test"
jmeter -Ghost= -Gport= -Gprotocol= -Gthreads= -Gduration= -Grampup= --reportatendofloadtests --reportoutputfolder /report/report-PetStoreAPIScriptLoad100User.jmx-2023-10-19_101800 --logfile /report/PetStoreAPIScriptLoad100User.jmx_2023-10-19_101800.jtl --nongui --testfile PetStoreAPIScriptLoad100User.jmx -Dserver.rmi.ssl.disable=true --remoteexit --remotestart 10.44.0.10,10.44.0.8,10.44.0.9 >> jmeter-master.out 2>> jmeter-master.err &
trap 'kill -10 1' EXIT INT TERM
java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-master.out 2>> jmeter-master.err
echo "Starting load test at : Thu Oct 19 10:18:00 UTC 2023" && wait
