#
# Cookbook Name:: rails-test-chef
# Recipe:: node
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'apt'
include_recipe 'build-essential'

# db
mysql2_chef_gem 'default' do
  client_version node['mysql']['version'] if node['mysql'] && node['mysql']['version']
  action :install
end

mysql_service 'rails' do
  version node['mysql']['version']
  initial_root_password node['mysql']['server_root_password']
  action [:create, :start]
end

db_info = node['rails_app']['db_info']
db_pass = data_bag_item('rails_app', 'db')['password']
db_name = "#{node['rails_app']['name']}_#{node.chef_environment}"

mysql_connection_info = { :host => db_info['host'],
                          :port => node['mysql']['config']['port'],
                          :username => 'root',
                          :password => node['mysql']['server_root_password'] }

mysql_database db_name do
  connection mysql_connection_info
  action :create
end

mysql_database_user db_info['username'] do
  connection mysql_connection_info
  password db_pass
  database_name db_name
  privileges [:all]
  action :create
end

mysql_database_user db_info['username'] do
  connection mysql_connection_info
  password db_pass
  database_name db_name
  privileges [:all]
  action :grant
end

## rails_app
app_info = node['rails_app']

# users
deploy_user = app_info['user']
deploy_group = app_info['user']

user_account deploy_user do
  create_group true
end

group "sudo" do
   action :modify
   members deploy_user
   append true
end

ssh_authorized_keys = data_bag_item('rails_app', 'ssh_authorized_keys')['keys']
ssh_authorized_keys.each do |key_data|
  ssh_authorize_key key_data['email'] do
    key key_data['key']
    user deploy_user
  end
end

sudo app_info['name'] do
  user deploy_user
  commands ["/usr/bin/service #{app_info['name']} restart"]
  nopasswd true
end

# rbenv
app_name = app_info['name']
app_root = app_info['app_root']
ruby_ver = node['rails_app']['ruby_version']

include_recipe 'rbenv::default'
include_recipe 'rbenv::ruby_build'

include_recipe 'rails-test-chef::ruby_binaries'
# rbenv_command 'rehash'
rbenv_gem "bundler" do
  ruby_version ruby_ver
end

# nodejs (dependency)
include_recipe 'nodejs'

# folder & templates
directory app_root do
  owner deploy_user
  group deploy_group
  recursive true
end

["shared",
 "shared/config",
 "shared/bin",
 "shared/vendor",
 "shared/public",
 "shared/bundle",
 "shared/tmp",
 "shared/tmp/sockets",
 "shared/tmp/cache",
 "shared/tmp/sockets",
 "shared/tmp/pids",
 "shared/log",
 "shared/system",
 "releases"].each do |dir|
   directory "#{app_root}/#{dir}" do
     owner deploy_user
     group deploy_group
     recursive true
   end
 end

template "#{app_root}/shared/.ruby-version" do
  owner deploy_user
  group deploy_group
  mode 0600
  source "ruby_version.erb"
  variables ruby_version: ruby_ver
end

template "#{app_root}/shared/config/database.yml" do
  owner deploy_user
  group deploy_group
  mode 0600
  source "app_database.yml.erb"
  variables :db_info => app_info['db_info'],
            :db_pass => db_pass,
            :db_name => db_name,
            :rails_env => node.chef_environment
end

template "#{app_root}/shared/config/secrets.yml" do
  owner deploy_user
  group deploy_group
  mode 0600
  source "app_secrets.yml.erb"
  variables :secret => data_bag_item('rails_app', 'secret')['key'],
            :rails_env => node.chef_environment
end

template "#{app_root}/shared/config/unicorn.rb" do
  owner deploy_user
  group deploy_user
  mode 0644
  source "app_unicorn.rb.erb"
  variables :name => app_name,
            :deploy_user => deploy_user,
            :number_of_workers => 2
end

template "/etc/init/#{app_name}.conf" do
  mode 0644
  source "unicorn_upstart.erb"
  variables :name => app_name,
            :rails_env => node.chef_environment,
            :deploy_user => deploy_user,
            :app_root => app_root
end

# TODO: Find a better way to source rbenv... the cookbook does NOT enable it for
# noninteractive shells
deploy app_root do
  repo "https://github.com/cles/rails-test.git"
  user deploy_user
  enable_submodules true

  migrate true
  migration_command ". /etc/profile.d/rbenv.sh && rbenv shell #{ruby_ver} && bundle exec rake db:migrate --trace"
  before_migrate do
    execute 'link .ruby-version' do
      user deploy_user
      group deploy_group
      cwd release_path
      command "ln -s #{app_root}/shared/.ruby-version"
    end

    execute 'bundle install' do
      user deploy_user
      group deploy_group
      cwd release_path
      command ". /etc/profile.d/rbenv.sh && rbenv shell #{ruby_ver} && bundle install --binstubs --path #{app_root}/shared/bundle"
    end
  end

  symlinks('tmp/pids' => 'tmp/pids',
           'log' => 'log',
           'config/secrets.yml' => 'config/secrets.yml',
           'config/unicorn.rb' => 'config/unicorn.rb')

  before_restart do
    execute 'assets precompile' do
      user deploy_user
      group deploy_group
      cwd release_path
      command ". /etc/profile.d/rbenv.sh && rbenv shell #{ruby_ver} && bundle exec rake assets:precompile"
    end
  end

  environment "RAILS_ENV" => "production"
  shallow_clone true
  action :deploy
  restart_command "sudo service #{app_name} restart"
end

service app_name do
  provider Chef::Provider::Service::Upstart
  action [ :enable ]
end

# nginx
include_recipe 'nginx'

template "/etc/nginx/sites-available/#{app_name}.conf" do
  source "app_nginx.conf.erb"
  variables(
    name: app_name,
    domain_names: [ node['cloud']['public_ips'].first ])
  notifies :reload, resources(service: "nginx")
end

nginx_site 'default' do
  enable false
end

nginx_site "#{app_name}.conf" do
  action :enable
end

# logrotate
logrotate_app app_name do
  cookbook "logrotate"
  path ["#{app_root}/current/log/*.log"]
  frequency "daily"
  rotate 14
  compress true
  create "644 #{deploy_user} #{deploy_user}"
end
