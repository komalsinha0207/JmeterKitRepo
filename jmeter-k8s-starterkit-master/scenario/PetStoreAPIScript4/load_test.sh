slave_array=(10.36.0.1); index=1 && while [ ${index} -gt 0 ]; do for slave in ${slave_array[@]}; do if echo 'test open port' 2>/dev/null > /dev/tcp/${slave}/1099; then echo ${slave}' ready' && slave_array=(${slave_array[@]/${slave}/}); index=$((index-1)); else echo ${slave}' not ready'; fi; done; echo 'Waiting for slave readiness'; sleep 2; done
echo "Installing needed plugins for master"
cd /opt/jmeter/apache-jmeter/bin
sh PluginsManagerCMD.sh install-for-jmx PetStoreAPIScript4.jmx
echo "Done installing plugins, launching test"
jmeter -Ghost= -Gport= -Gprotocol= -Gthreads= -Gduration= -Grampup= --reportatendofloadtests --reportoutputfolder /report/report-PetStoreAPIScript4.jmx-2023-11-16_103554 --logfile /report/PetStoreAPIScript4.jmx_2023-11-16_103554.jtl --nongui --testfile PetStoreAPIScript4.jmx -Dserver.rmi.ssl.disable=true --remoteexit --remotestart 10.36.0.1 >> jmeter-master.out 2>> jmeter-master.err &
trap 'kill -10 1' EXIT INT TERM
java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-master.out 2>> jmeter-master.err
echo "Starting load test at : Thu Nov 16 10:35:54 UTC 2023" && wait
