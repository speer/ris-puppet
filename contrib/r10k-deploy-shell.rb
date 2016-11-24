#!/usr/bin/env ruby

# deploy shell called by git hooks via ssh
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

def exit_with_error(message)
  puts message
  exit 1
end

def is_module_pinned_on_master_in_any_env?(module_name, puppet_env_dir)
  `cat #{puppet_env_dir}/*/Puppetfile | grep "'#{module_name}'" | grep ":ref => 'master'" | wc -l`.to_i > 0
end

puppet_env_dir = '/etc/puppet/environments'
command = ARGV.shift

case command

when 'deploy'
  # trigger r10k deploy

  type = ARGV.shift

  case type
  when 'module'
    exit_with_error 'No module name given' if ARGV.empty?

    module_name = ARGV.shift
    if is_module_pinned_on_master_in_any_env?(module_name, puppet_env_dir)
      Kernel.send 'exec', *['/usr/bin/r10k', 'deploy', 'module', module_name, '--verbose']
    else
      puts 'This module is nowhere pinned on ref master => no r10k deploy'
    end


  when 'environment'
    if ARGV.empty?
      Kernel.send 'exec', *['/usr/bin/r10k', 'deploy', 'environment', '-p', '--verbose']
    else
      environment_name = ARGV.shift
      puppetfile_path = "#{puppet_env_dir}/#{environment_name}/Puppetfile"
      modules_to_deploy = []

      require 'tmpdir'
      require 'fileutils'
      Dir.mktmpdir do |dir|

        FileUtils.cp(puppetfile_path,"#{dir}/Puppetfile")

        # Roll out hiera and Puppetfile
        `/usr/bin/r10k deploy environment #{environment_name} --verbose`

        # Determine which modules have changed
        diff = `/usr/bin/diff --side-by-side --suppress-common-lines "#{puppetfile_path}" "#{dir}/Puppetfile"`
        diff.lines.each do |line|
          next unless m = line.match(/^ris_(int|ext)\s+'([a-zA-Z0-9_]+)'(?:,\s*'([a-zA-Z0-9_]+)')?(.*)$/)
          if $3
            modules_to_deploy << $3
          else
            modules_to_deploy << $2
          end
        end
      end

      if modules_to_deploy.length > 0
        puts "Deploying modules: #{modules_to_deploy.join(', ')}"

        # Roll out modules that have changed
        r10k_command = ['/usr/bin/r10k', 'deploy', 'module', '-e', environment_name]
        (r10k_command << modules_to_deploy).flatten!
        r10k_command << '--verbose'
        Kernel.send 'exec', *r10k_command
      else
        puts "No modules changed in environment #{environment_name} => no r10k deploy"
      end
    end

  else
    exit_with_error "Sorry, I do not know how to deploy #{type}"
  end


when 'reload-apache'
  # trigger apache restart

  puts "Restart Apache because of changes in Ruby scripts"
  Kernel.system 'sudo /etc/init.d/httpd restart'

else
  exit_with_error "Given command #{command} is not allowed"
end
