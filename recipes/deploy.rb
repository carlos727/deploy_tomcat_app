#
# Cookbook Name:: deploy_tomcat_app
# Recipe:: deploy
#
# Copyright (c) 2017 The Authors, All Rights Reserved.

#
# Variables
#
shops = %w()

#
# Deploy process
#
ruby_block 'Wait for tomcat to start' do
  block do
    TomcatService.wait_start
  end
end

ruby_block "Verify if #{$app_name} is deployed" do
  block do
    if App.status?($app_name, $username, $password).first
      TomcatManager.undeploy_app($app_name, $username, $password)
    end
  end
  only_if { shops.include?($node_name) }
end

ruby_block "Deploy #{$app_name}"  do
  block do
    TomcatManager.deploy_app($app_name, $username, $password)
  end
  only_if { File.exist?("C:\\chef\\New_War\\#{$app_name}.war") }
end

#
# Validate process
#
ruby_block 'Verify deployment' do
  block do
    if Url.is_reachable?($version_url)
      f = Url.fetch $version_url
      prefix = "B" if $node_name.start_with? "B"
      prefix = "P" if $node_name.start_with? "P"
      codigo_localidad = f['data']['codigoLocalidad']
      nombre_localidad = f['data']['nombreLocalidad']
      version = $version_url[$version_patterm]
      message = "Successful deployment, #{$app_name} v#{version} is ready in #{codigo_localidad} #{nombre_localidad} !"
      Chef::Log.info(message)
      Tool.simple_email($mail_to, "Chef Deployment on Node #{prefix}#{codigo_localidad}", message)
    else
      Chef::Log.error("Request failed.")
      Tool.simple_email($mail_to, "Chef Failed on Node #{$node_name}", "#{$app_name} could not be deployed.")
      # run_context.include_recipe 'deploy_tomcat_app::download_sw_64bits'
    end
  end
end
