RIS-Puppet
==========

This utility collection should make your life with [Puppet](https://www.puppet.com)
easier. You'll love it especially when deploying your Puppet Code with
[r10k](https://github.com/puppetlabs/r10k). It allows you to trigger 
annoying tasks like deploying module refs to specific environments with
short commands immediately from your working directory.

In the [contrib](contrib) directory you find the GIT hooks and the r10k 
deploy shell, used by this tool.


Installation
------------
Hint: after cloning this repository, you should symlink `bin/ris-puppet`
to `/usr/local/bin` or similar.

Available applications and commands
-----------------------------------

This shows a list of availble applications and commands.

Hint: use `--help` for further information.

### module

While being in a module directory the `deploy` action allows you to
pin this module to your current commit rev in the `control_repo` and
immediately deploys the desired environment to the Puppet master:

    ris-puppet module deploy --env test

As an alternative you can also provide a specific `ref` (branch, commit,
tag):

    ris-puppet module deploy --env test --ref v1.2

For this operation you do not need to be in a module directory.

In order to remove a module from the specified environment, use the
`remove` action:

    ris-puppet module remove --env test --module ris_helloworld

Also this action works outside a module directory.

Analogue to `deploy` and `remove` there exist also `pin` and `unpin`,
which work in exact the same way, except they do not push the
`control_repo` to the remote git server at the end.

The `validate` action performs Puppet, Ruby and YAML syntax checks
and tells you whether there are errors or warnings.


### environment

This application provides means for creating and removing Puppet
environments.

The `create` action creates a new branch, i.e. environment, in the 
`control_repo`, out of the branch specified by the `--from` parameter:

    ris-puppet environment create --env sandbox --from test

The `destroy` action removes the specified environment:

    ris-puppet environment destroy --env sandbox

The `list` action shows a list of all available environments:

    ris-puppet environment list


### foreman

This application provides means to interact with [Foreman](https://www.theforeman.org/).
It offers the folowing actions:

* dashboard
* hosts
* hostsclasses
* import

The `import` action triggers the Puppet class import in Foreman:

    ris-puppet foreman import

The `dashboard` action returns a dashboard as JSON:

    ris-puppet foreman dashboard

The `hosts` actions returns a list of all hosts in a given environment:

    ris-puppet foreman hosts --env sandbox

The `hostsclasses` action returns for each host the assigned Puppet classes:

    ris-puppet foreman hostsclasses

