
master_node = {}

#Updates the cluster name with the name that is in file and creates a data bag and skips if data bag already exists
ruby_block "Update cluster name" do
	block do
		begin
			require "json"
			rabbit_cluster_name = JSON.load(File.read("/var/tmp/custom_config.json"))["RABBITMQ_CLUSTER_NAME"]
			node.default['rabbitmq']['clustering']['cluster_name']=rabbit_cluster_name
			puts node['rabbitmq']['clustering']['cluster_name']
  		master_node = Chef::DataBagItem.load(node['rabbitmq']['clustering']['cluster_name'], 'master_node')
 			rescue Net::HTTPServerException, Chef::Exceptions::InvalidDataBagName => e
  		Chef::Log.warn('Databag dont exist, Creating new one')
  		master_node = {}
  		
  		if !master_node.empty?
  			raise Chef::Exceptions::AttributeNotFound
  		else
  			master_node_data_bag = Chef::DataBag.new
  			master_node_data_bag.name(node['rabbitmq']['clustering']['cluster_name'])
  			master_node_data_bag.create
  			master_node = {
    			'id' => 'master_node',
    			'hostname' => 'rabbit@' + node['fqdn'].split('.').first
  			}
  			databag_item = Chef::DataBagItem.new
  			databag_item.data_bag(node['rabbitmq']['clustering']['cluster_name'])
  			databag_item.raw_data = master_node
  			databag_item.save
  		end
  		
		rescue Exception => e
			raise "Custom config json is missing"
		end
	end
end

#Creates the data bag with the node name of the main(master) node
master_node_host = node['fqdn'].split('.').first
master_cluster_node = { name: "rabbit@#{master_node_host}", type: 'disk' }
node.default['rabbitmq']['clustering']['cluster_nodes'].push(master_cluster_node)
			
include_recipe 'rabbitmq::default'

#Check for the erlang cookie
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

