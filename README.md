# README

## setup
### chef-dk:

For Ubuntu: (from https://downloads.chef.io/chef-dk/ubuntu/)

```
wget https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chefdk_0.6.2-1_amd64.deb
sudo dpkg -i chefdk_0.6.2-1_amd64.deb
```

on relog:
```
eval "$(chef shell-init bash)"
chef exec bundle
```

### create .chef/knife.rb

sample:
```
log_level :info
current_dir = File.dirname(__FILE__)
root_dir = File.expand_path(File.join(current_dir, '..'))
chef_server_url "http://localhost:8889"
node_name 'node'
# dummy key, any will do, chef-zero will not check it but it must exist
# and be correctly formatted, knife will check that much
client_key '/home/oriol/.ssh/dummy.pem'
private_keys 'oriolfa-key-pair-euwest1' =>'/home/oriol/.ssh/oriolfa-key-pair-euwest1.pem'
secret "#{current_dir}/encrypted_data_bag_secret"
```

### create data bags

#### shared secret

```
openssl rand -base64 512 | tr -d '\r\n' > .chef/encrypted_data_bag_secret
```

#### create db data bag

Used to store the Rails database password on config/database.yml

```
knife data bag create rails_app db --secret-file .chef/encrypted_data_bag_secret -z
```

sample:
```
{
  "id": "db",
  "password": "<any password>"
}
```

### create secret data bag

Used to store Rails secret on config/secrets.yml

```
knife data bag create rails_app secret --secret-file .chef/encrypted_data_bag_secret -z
```

sample:
```
{
  "id": "secret",
  "key": "<any secret, rake secret can generate one>"
}
```

### create ssh_auhtorized_keys data bag

Used to store the authrozied keys that will be added to the ~/.ssh/authorized_keys file for the deploy user

```
knife data bag create rails_app ssh_authorized_keys --secret-file .chef/encrypted_data_bag_secret -z

```

sample:
```
{
  "id": "ssh_authorized_keys",
  "keys": [ { "email": "<key email>",
              "key": "<key>" } ]
}
```

## provision + deploy

Setup env vars
```
AWS_INSTANCE_TYPE='t2.medium'
AWS_IMAGE_ID='ami-47a23a30'
AWS_KEY_NAME='oriolfa-key-pair-euwest1'
export AWS_INSTANCE_TYPE AWS_IMAGE_ID AWS_KEY_NAME
```

```
chef-client -z -o rails-test-chef::provision
```

## config files

cookbooks/rails-chef-test/attributes/default.rb

## TODO/Improvements (in no particular order)

* expand cookbooks/rails-test/chef/recipes/provision.rb to create everything
  from scratch, a vpc... the works, not just a machine
* split cookbooks/rails-test-chef/recipes/default.rb into several recipes, with
  an eye on splitting per role
* split role rails_app into several roles, using the previously split
  recipes. this should help with flexibility, i.e: decoupling the db from the
  host of the rails_app, in case we want to move away from single-host setups
* testing! write specs, make kitchen test work, the split in several cookbooks
  should make testing feasible
* implement ssl-cert config for nginx template, distribute certs via data bag
* adding a provisioner role, with rails-chef-test::provisoner on the
  run_list only. this would allow remote provisioning (as in, not only from a local
  machine).
* look into chef-vault instead of symmetric-key manual distribution?
* self-host the ruby binaries (try to avoid in-node build processes, the
  slowdown is considerable on convergence)
