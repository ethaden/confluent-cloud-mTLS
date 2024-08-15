# Produce with this command:
# kafka-console-producer --producer.config client-${client_name}-mtls.conf --bootstrap-server ${cluster_bootstrap_server} --topic ${topic}
# Consume with this command:
# kafka-console-consumer --consumer.config client-${client_name}-mtls.conf --bootstrap-server ${cluster_bootstrap_server} --topic ${topic} --from-beginning

bootstrap.servers=${cluster_bootstrap_server}
security.protocol=SSL
#ssl.truststore.location=/etc/ssl/kafka.client.truststore.jks
#ssl.truststore.password=MY_PASSWORD
ssl.keystore.location=${keystore_file}
ssl.keystore.password=${keystore_passphrase}
ssl.key.password=${keystore_passphrase}
# Required for consumers only:
group.id=${client_name}

# Schema Registry
#schema.registry.url=<URL OF SCHEMA REGISTRY>
#basic.auth.credentials.source=USER_INFO
#basic.auth.user.info=<user>:<password>
