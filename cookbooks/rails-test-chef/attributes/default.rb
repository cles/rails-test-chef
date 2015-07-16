default['mysql']['server_root_password'] = 'rootpassword'
default['mysql']['config']['port'] = 3306
default['mysql']['version'] = '5.6'

default['rails_app']['ruby_version'] = "2.2.1"
default['rails_app']['name'] = 'rails-test'
default['rails_app']['user'] = 'deployer'
default['rails_app']['app_root'] = "/home/#{default['rails_app']['user']}/#{default['rails_app']['name']}"
default['rails_app']['repository'] = "https://github.com/cles/rails-test"
default['rails_app']['db_info'] = { 'adapter' => 'mysql2',
                                    'host' => '127.0.0.1',
                                    'username' => default['rails_app']['name'] }
default['rails_app']['secret_file'] = "/home/oriol/src/bebanjo/rails-test-chef/.chef/encrypted_data_bag_secret"

default["rbenv"]["binaries_url"] = "http://binaries.intercityup.com/ruby/ubuntu"
default["rbenv"]["binaries"] = %w(1.9.3-p547 2.0.0-p481 2.1.0 2.1.1 2.1.2 2.1.3 2.1.5 2.2.1)
default["rbenv"]['group_users'] = [ default['rails_app']['user'] ]
