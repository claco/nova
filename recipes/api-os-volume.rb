#
# Cookbook Name:: nova
# Recipe:: api-os-volume
#
# Copyright 2012, Rackspace US, Inc.
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

include_recipe "nova::nova-common"

platform_options = node["nova"]["platform"]

directory "/var/lock/nova" do
    owner "nova"
    group "nova"
    mode "0700"
    action :create
end

package "python-keystone" do
  action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
  options platform_options["package_overrides"]
end

platform_options["api_os_volume_packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

service "nova-api-os-volume" do
  service_name platform_options["api_os_volume_service"]
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, "template[/etc/nova/nova.conf]", :delayed
end

ks_admin_endpoint = get_access_endpoint("keystone-api", "keystone", "admin-api")
ks_service_endpoint = get_access_endpoint("keystone-api", "keystone", "service-api")
keystone = get_settings_by_role("keystone-setup","keystone")

template "/etc/nova/api-paste.ini" do
  source "api-paste.ini.erb"
  owner "nova"
  group "nova"
  mode "0600"
  variables(
    "service_port" => ks_service_endpoint["port"],
    "keystone_api_ipaddress" => ks_service_endpoint["host"],
    "admin_port" => ks_admin_endpoint["port"],
    "admin_token" => keystone["admin_token"]
  )
  notifies :restart, "service[nova-api-os-volume]", :delayed
end
