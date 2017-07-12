#
# Cookbook Name:: deploy_tomcat_app
# Recipe:: download_sw_64bits
#
# Copyright (c) 2017 The Authors, All Rights Reserved.

directory 'C:\Software64' do
  action :create
end

remote_file 'Download Apache Tomcat' do
  path 'C:\Software64\apache-tomcat-7.0.69.exe'
  source 'https://evachef.blob.core.windows.net/resources/installer/apache-tomcat-7.0.69.exe'
end

remote_file 'Download Java JDK' do
  path 'C:\Software64\jdk-7u79-windows-x64.exe'
  source 'https://evachef.blob.core.windows.net/resources/installer/jdk-7u79-windows-x64.exe'
end
