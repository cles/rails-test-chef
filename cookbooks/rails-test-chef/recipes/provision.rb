require 'chef/provisioning'

with_driver 'aws'
with_machine_options :bootstrap_options => { :instance_type => ENV['AWS_INSTANCE_TYPE'],
                                             :image_id => ENV['AWS_IMAGE_ID'],
                                             :key_name => ENV['AWS_KEY_NAME'] }

with_chef_server "http://localhost:8889" # use chef-zero

machine 'rails_app' do
  tag 'rails_app'
  role 'rails_app'
  chef_environment 'production'
  action :ready
end

machine_file '/etc/chef/encrypted_data_bag_secret' do
  machine 'rails_app'
  local_path node['rails_app']['secret_file']
  action :upload
end

machine 'rails_app' do
  action :converge
end
