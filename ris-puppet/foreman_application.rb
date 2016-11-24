require File.expand_path('../base.rb', __FILE__)
require 'rubygems'
require 'json'
require 'highline/import'

# RisPuppet::Foreman manages foreman imports
#
# Authors:
#  Stefan Peer

class RisPuppet::Foreman < RisPuppet::Base

  def init
    initialize_logger
    add_option :username,    "-u", "--username=USERNAME",             "Username for foreman authentication, defaults to current user"
    add_option :password,    "-p", "--password=PASSWORD",             "Password for foreman authentication, defaults to ask for password"
    add_option :smartproxy,  "-p", "--smartproxy=PUPPET-SMART-PROXY", "Puppet Smart Proxy in Foreman, see config file for default setting"
    add_option :foremanhost, "-f", "--foremanhost=FOREMAN-HOST",      "Foreman host, see config file for default setting"
    add_option :cacert,      "-c", "--cacert=CA-CERT-PATH",           "Foremans CA Certificate Path, see config file for default setting"
    add_option :env,         "-e", "--env=ENV",                       "Environment, defaults to all environments"
  end

  def default_action
    import_action
  end

  def import_action
    set_parameter_defaults
    res = get_api_result "/smart_proxies/#{get_option :smartproxy}/import_puppetclasses", 'POST'
    puts res['message']
  end

  def hosts_action
    set_parameter_defaults
    get_hosts.each do |h|
      puts h['name']
    end
  end

  def hostsclasses_action
    set_parameter_defaults
    get_hosts.each do |h|
      puts h['name']
      curl_classes = get_api_result "/hosts/#{h['name']}/puppetclasses"
      curl_classes['results'].each do |mo, cl|
        cl.each do |c|
          puts " * #{c['name']}"
        end
      end
    end
  end

  def dashboard_action
    set_parameter_defaults
    get_dashboard.each do |key, val|
      puts "#{key}: #{val}"
    end
  end

  protected

  def get_dashboard
    if has_option? :env
      dashboard = get_api_result "/dashboard?search=environment%3D#{get_option :env}"
    else
      dashboard = get_api_result '/dashboard'
    end
  end

  def get_hosts
    if has_option? :env
      hosts = get_api_result "/environments/#{get_option :env}/hosts?per_page=10000"
    else
      hosts = get_api_result '/hosts?per_page=10000'
    end
    raise 'No hosts found' unless hosts['results']
    hosts['results']
  end

  def set_parameter_defaults
    set_option(:foremanhost, get_option(:foremanhost, get_setting('foreman_application_default_foremanhost')))
    set_option(:cacert, get_option(:cacert, get_setting('foreman_application_default_cacert')))
    set_option(:username, get_option(:username, ENV['USER']))
    set_option(:smartproxy, get_option(:smartproxy, get_setting('foreman_application_default_smartproxy')))
    username = get_option :username
    unless has_option? :password
      set_option(:password, ask("Password for user '#{username}': ") { |q| q.echo = false })
    end
  end

  def get_api_result(uri, type = 'GET')
    result = JSON.parse `/usr/bin/curl -s --cacert #{get_option :cacert} -u '#{get_option :username}:#{get_option :password}' -X #{type} https://#{get_option :foremanhost}/api#{uri} --header 'Content-Type: application/json'`
    raise result['error']['message'] if result.has_key? 'error'
    result
  end

end
