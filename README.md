RIS-Puppet
==========

Utility collection to make life with Puppet easier

Hint: after cloning this repository, you should symlink bin/ris-puppet
to /usr/local/bin or similar.

Hint2: use --help for further information.


module
------
While being in a module directory the *deploy* action allows you to
pin this module to your current commit rev in the control\_repo and
immediately deploys the desired environment to the Puppet master:

    ris-puppet module deploy --env test

As an alternative you can also provide a specific ref (branch, commit,
tag):

    ris-puppet module deploy --env test --ref v1.2

For this operation you do not need to be in a module directory.

In order to remove a module from the specified environment, use the
*remove* action:

    ris-puppet module remove --env test --module ris_helloworld

Also this action works outside a module directory.

Analogue to *deploy* and *remove* there exist also *pin* and *unpin*,
which work in exact the same way, except they do not push the
control\_repo to the remote git server at the end.

The *validate* action performs puppet, ruby and yaml syntax checks
and tells you whether there are errors or warnings.


environment
-----------
This application provides means for creating and removing Puppet
environments.

The *create* action creates a new branch, i.e. environment, in the 
control\_repo, out of the branch specified by the --from parameter:

    ris-puppet environment create --env sandbox --from test

The *destroy* action removes the specified environment:

    ris-puppet environment destroy --env sandbox

The *list* action shows a list of all available environments:

    ris-puppet environment list


foreman
-------
This application provides means to interact with foreman.

dashboard     hosts         hostsclasses  import

The *import* action triggers the puppet class import in foreman:

    ris-puppet foreman import

The *dashboard* action returns a dashboard as json:

    ris-puppet foreman dashboard

The *hosts* actions returns a list of all hosts in a given environment:

    ris-puppet foreman hosts --env sandbox

The *hostsclasses* action returns for each host the assigned puppet classes:

    ris-puppet foreman hostsclasses

