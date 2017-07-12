#
# Cookbook Name:: deploy_tomcat_app
# Recipe:: prepare
#
# Copyright (c) 2017 The Authors, All Rights Reserved.

#
# Download war
#
log "#{$app_name}.war downloaded from #{$war_url}" do
  action :nothing
end

directory 'C:\chef\New_War' do
  action :create
end

remote_file "Download #{$app_name}.war" do
  path "C:\\chef\\New_War\\#{$app_name}.war"
  source $war_url
  notifies :write, "log[#{$app_name}.war downloaded from #{$war_url}]", :immediately
end

#
# Edit Eva-config.yml
#
data_source_url = ''
data_source_username = ''
data_source_password = ''
localidad_codigo = ''
localidad_nombre = ''
localidad_url_central = ''

ruby_block 'Edit Eva-config.yml file' do
  block do
    file_content = File.read('C:\Eva\Eva-config.yml')
    file_content = file_content.gsub(/data_source_url/,data_source_url)
    file_content = file_content.gsub(/data_source_username/,data_source_username)
    file_content = file_content.gsub(/data_source_password/,data_source_password)
    file_content = file_content.gsub(/localidad_codigo/,localidad_codigo)
    file_content = file_content.gsub(/localidad_nombre/,localidad_nombre)
    file_content = file_content.gsub(/localidad_url_central/,localidad_url_central)
    File.open('C:\Eva\Eva-config.yml', 'w') { |file| file.write file_content }
  end
  action :nothing
end

cookbook_file 'C:\Eva\Eva-config.yml' do
  source 'Eva-config.yml'
  action :nothing
  notifies :run, 'ruby_block[Edit Eva-config.yml file]', :immediately
end

ruby_block 'Get values from Eva-config.properties' do
  block do
    file_content = File.read('C:\Eva\Eva-config.properties').encode("UTF-16be", :invalid=>:replace, :replace=>"ñ").encode('UTF-8')
    file_content.each_line do |line|
      pair = line.split '='
      value = pair.last.chop
      data_source_url = "#{pair[1]}=#{value}" if pair.first.eql? 'dataSource.url'
      data_source_username = value if pair.first.eql? 'dataSource.username'
      data_source_password = value if pair.first.eql? 'dataSource.password'
      localidad_codigo = value if pair.first.eql? 'localidad.codigo.localidad'
      localidad_nombre= value if pair.first.eql? 'localidad.nombre.localidad'
      localidad_url_central = value if pair.first.eql? 'localidad.url.central'
    end
  end
  only_if { File.exist?('C:\Eva\Eva-config.properties') && !File.exist?('C:\Eva\Eva-config.yml') }
  notifies :create, 'cookbook_file[C:\Eva\Eva-config.yml]', :immediately
end

#
# Validate process
#
ruby_block 'Validation' do
  block do
    message = 'Available resources:'
    message << "\n- Eva-config.yml file." if File.exist?('C:\Eva\Eva-config.yml')
    message << "\n- #{$app_name}.war file." if File.exist?("C:\\chef\\New_War\\#{$app_name}.war")
    Chef::Log.info("\n#{message}")
    #Tool.simple_email($mail_to, "Chef Prepare Node #{$node_name}", message)
  end
  only_if { File.exist?('C:\Eva\Eva-config.yml') || File.exist?("C:\\chef\\New_War\\#{$app_name}.war") }
end
