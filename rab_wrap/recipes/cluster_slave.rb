
#Updates the cluster name from the file
ruby_block "Update cluster name" do
	block do
		begin
			require "json"
			rabbit_cluster_name = JSON.load(File.read("/var/tmp/custom_config.json"))["RABBITMQ_CLUSTER_NAME"]
			node.default['rabbitmq']['clustering']['cluster_name']=rabbit_cluster_name
			master_node_dbag_item = data_bag_item(node['rabbitmq']['clustering']['cluster_name'], 'master_node')
			master_node_name = master_node_dbag_item['hostname']
			slave_node_name = node['fqdn'].split('.').first
			master_node = { name: master_node_name, type: 'disk' }
			slave_node = { name: "rabbit@#{slave_node_name}", type: 'disk' }
			node.default['rabbitmq']['clustering']['cluster_nodes'] = []
			node.default['rabbitmq']['clustering']['cluster_nodes'].push(master_node)
			node.default['rabbitmq']['clustering']['cluster_nodes'].push(slave_node)
		rescue Exception => e
			raise "Custom config json is missing"
		end
	end
end

include_recipe 'rabbitmq::default'

#Checks for the erlang cookie
if File.exist?('/home/rabbitmq/.erlang.cookie') && File.readable?('/home/rabbitmq/.erlang.cookie')
  existing_erlang_key =  File.read('/home/rabbitmq/.erlang.cookie').strip
else
  existing_erlang_key = ''
end

if node['rabbitmq']['cluster'] && (node['rabbitmq']['erlang_cookie'] != existing_erlang_key)
  log "stop #{node['rabbitmq']['service_name']} to change erlang cookie" do
    notifies :stop, "service[#{node['rabbitmq']['service_name']}]", :immediately
  end

  template '/home/rabbitmq/.erlang.cookie' do
    source 'doterlang.cookie.erb'
    owner 'rabbitmq'
    group 'rabbitmq'
    mode 00400
    notifies :start, "service[#{node['rabbitmq']['service_name']}]", :immediately
    notifies :run, 'execute[reset-node]', :immediately
  end

  # Need to reset for clustering #
  execute 'reset-node' do
    command 'rabbitmqctl stop_app && rabbitmqctl reset && rabbitmqctl start_app'
    action :nothing
  end
end

include_recipe 'rab_wrap::cluster'
