#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2009, Benjamin Black
# Copyright 2009-2013, Chef Software, Inc.
# Copyright 2012, Kevin Nuckolls <kevin.nuckolls@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
class Chef::Resource # rubocop:disable all
  include Opscode::RabbitMQ # rubocop:enable all
end

include_recipe 'dfsRabbitMQServer'

if node['rabbitmq']['logdir']
  directory node['rabbitmq']['logdir'] do
    owner 'rabbitmq'
    group 'rabbitmq'
    mode '775'
    recursive true
  end
end

directory node['rabbitmq']['mnesiadir'] do
  owner 'rabbitmq'
  group 'rabbitmq'
  mode '775'
  recursive true
end

template "#{node['rabbitmq']['config_root']}/rabbitmq-env.conf" do
  source 'rabbitmq-env.conf.erb'
  owner 'rabbitmq'
  group 'rabbitmq'
  mode 00644
  notifies :restart, "service[#{node['rabbitmq']['service_name']}]"
end

template "#{node['rabbitmq']['config']}.config" do
  sensitive true
  source 'rabbitmq.config.erb'
  cookbook node['rabbitmq']['config_template_cookbook']
  owner 'rabbitmq'
  group 'rabbitmq'
  mode 00644
  variables(
    :kernel => format_kernel_parameters,
    :ssl_versions => (format_ssl_versions if node['rabbitmq']['ssl_versions']),
    :ssl_ciphers => (format_ssl_ciphers if node['rabbitmq']['ssl_ciphers'])
  )
  notifies :restart, "service[#{node['rabbitmq']['service_name']}]"
end

template "/etc/default/#{node['rabbitmq']['service_name']}" do
  source 'default.rabbitmq-server.erb'
  owner 'rabbitmq'
  group 'rabbitmq'
  mode 00644
  notifies :restart, "service[#{node['rabbitmq']['service_name']}]"
end

if File.exist?(node['rabbitmq']['erlang_cookie_path']) && File.readable?((node['rabbitmq']['erlang_cookie_path']))
  existing_erlang_key =  File.read(node['rabbitmq']['erlang_cookie_path']).strip
else
  existing_erlang_key = ''
end

if node['rabbitmq']['cluster'] && (node['rabbitmq']['erlang_cookie'] != existing_erlang_key)
  log "stop #{node['rabbitmq']['service_name']} to change erlang cookie" do
    notifies :stop, "service[#{node['rabbitmq']['service_name']}]", :immediately
  end

  template node['rabbitmq']['erlang_cookie_path'] do
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

if node['rabbitmq']['manage_service']
  service node['rabbitmq']['service_name'] do
    action [:enable, :start]
    supports :status => true, :restart => true
    provider Chef::Provider::Service::Upstart if node['rabbitmq']['job_control'] == 'upstart'
  end
else
  service node['rabbitmq']['service_name'] do
    action :nothing
  end
end

include_recipe 'rabbitmq::plugin_management'
