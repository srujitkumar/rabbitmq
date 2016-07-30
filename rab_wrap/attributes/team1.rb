
# Maintaining erlang cookie same for the master and slaves
default['rabbitmq']['erlang_cookie'] = 'dfsRabbitMQ'

# Defining the default user and password
# rabbitmq.config defaults
default['rabbitmq']['default_user'] = 'guest'
default['rabbitmq']['default_pass'] = 'guest'

# log levels
default['rabbitmq']['log_levels'] = { 'connection' => 'debug', 'channel' => 'debug', 'mirroring' => 'debug', 'federation' => 'debug'}

# loopback_users
# List of users which are only permitted to connect to the broker via a loopback interface (i.e. localhost).
# If you wish to allow the default guest user to connect remotely, you need to change this to [].
default['rabbitmq']['loopback_users'] = []

# clustering
default['rabbitmq']['cluster'] = true
default['rabbitmq']['clustering']['enable'] = true
default['rabbitmq']['clustering']['use_auto_clustering'] = true
default['rabbitmq']['clustering']['cluster_name'] = 'RMQ01'
default['rabbitmq']['clustering']['cluster_nodes'] = []

# users
default['rabbitmq']['enabled_users'] =
  [{ name: 'guest', password: 'guest', rights:
    [{ vhost: '/', conf: '.*', write: '.*', read: '.*' }]
  }]

default['rabbitmq']['enabled_plugins'] = %w(rabbitmq_amqp1_0 rabbitmq_auth_backend_ldap rabbitmq_auth_mechanism_ssl rabbitmq_consistent_hash_exchange rabbitmq_tracing rabbitmq_federation rabbitmq_federation_management rabbitmq_event_exchange)
default['rabbitmq']['disabled_plugins'] = %w(rabbitmq_shovel rabbitmq_stomp rabbitmq_mqtt rabbitmq_shovel_management)
