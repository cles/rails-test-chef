app_info = node['rails_app']
bins = node['rbenv']['binaries']
arch = node['kernel']['machine']

if bins.include? app_info['ruby_version']
  ruby_ver = app_info['ruby_version']
  ruby_binary = "ruby-#{ruby_ver}.tar.bz2"
  execute "Install ruby #{app_info['ruby_version']} binaries" do
    user node['rbenv']['user']
    group node['rbenv']['group']
    cwd "#{node['rbenv']['root_path']}/versions"
    command <<-EOM
      wget #{node['rbenv']['binaries_url']}/#{node["platform_version"]}/#{arch}/#{ruby_binary};
      tar jxf #{ruby_binary};
      rm #{ruby_binary};
    EOM
    not_if {  File.directory?(File.join('opt', 'rbenv', 'versions', app_info['ruby_version'])) }
  end

end
