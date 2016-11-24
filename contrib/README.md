Integration with Gitlab
=======================

Whenever a Puppet module is pushed to GIT, we automatically want to trigger syntax checks and reject
the commit if something is not ok.
If syntax is fine, we check whether this module is pinned on ref => 'master' in the r10k Puppetfile
and eventually trigger r10k on the Puppet master so that it gets rolled out.

Whenever a push in the control\_repo happens, we want to trigger r10k deploy for that environment/branch.
As a performance improvement we do not roll out every single module in that environment, but only the ones
that have changed in the Puppetfile.

NB: if a Ruby file change was pushed, we also trigger a reload of Apache / Passenger on the Puppet master.


Installation on GIT Server
--------------------------

On your GIT Server install package rubygem-puppet-lint and copy `contrib/git-custom_hooks` to `/opt`.


### Global hooks

Gitlab, out of the box, does not support global hooks (one hook, triggered for many repositories),
but you can achieve this functionality with a small patch.
    
    cd /opt/gitlab/embedded/service/gitlab-shell/lib
    patch -s -N -p0 -f < '/opt/git-custom_hooks/gitlab_custom_hook.patch'


### Customisations

In `git-custom_hooks/post-receive` you want to specify the username of the r10k user on the Puppet master
and the ip or fqdn of the Puppet master.

    r10kuser = 'r10k'
    puppetserver = 'puppet.example.com'


On your GIT Server you also need to create an SSH Key, with which you can access the Puppet Master (r10kuser).


In `git-custom_hooks/ris-git-hook.rb` you want to implement the following functions / regexes.
They are needed by to tool to find out in which repo the push happened, since the hooks are global.


    def is\_puppet\_module?
      group_name.match /^puppet-modules-/
    end

    def is\_ext\_puppet\_module?
      group_name == 'puppet-modules-ext'
    end

    def has\_validator\_checks\_enabled?
      group_name == 'puppet-modules-int' || group_name == 'puppet-config'
    end

    def is\_control\_repo?
      group_name == 'puppet-config' && repo_name == 'control_repo'
    end


Default setup:

* control\_repo in: puppet-config/control\_repo
* internal modules: puppet-modules-int/xzy
* external modules: puppet-modules-ext/puppetlabs-apache


Installation on the Puppet Master
---------------------------------

On the Puppet Master you install the script `r10k-deploy-shell.rb` in the r10k users home directory.

Finally you authorize the GIT servers public key in the r10kusers `.ssh/authorized_keys` file with the 
following prefix:

    command="~/r10k-deploy-shell.rb $SSH_ORIGINAL_COMMAND",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty

