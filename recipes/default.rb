#
# Cookbook Name:: deploy_tomcat_app
# Recipe:: default
#
# Copyright (c) 2017 The Authors, All Rights Reserved.

#
# Variables
#
$node_name = Chef.run_context.node.name.to_s
$war_folder = TomcatService.get_war_folder
$username = node['tomcat_manager']['user']
$password = node['tomcat_manager']['pwd']
$app_name = node['app']['name']
$war_url = node['app']['war_url']
$version_url = node['app']['version_url']
$version_patterm = node['app']['version_patterm']
$version_from_url = node['app']['version_from_url']
$mail_to = node['mail']['to']

#
# Download requirements
#
include_recipe 'deploy_tomcat_app::prepare'

#
# Configure Tomcat Manager
#
include_recipe 'tomcat_manager'

#
# Deploy PDT
#
include_recipe 'deploy_tomcat_app::deploy'
