require File.expand_path('../base.rb', __FILE__)

# RisPuppet::Environment manages branches in the control_repo
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class RisPuppet::Environment < RisPuppet::Base

  def init
    initialize_logger
    add_option :environment, "-e", "--env=ENVIRONMENT", "Puppet environment"
    add_option :from,        "-f", "--from=FROM", "Source branch (create only)"
  end

  def default_action
    list_action
  end

  def list_action
    list_remote_control_repo_branches.each do |head|
      puts head.sub /^refs\/heads\//, ''
    end
  end

  def create_action
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      prepare_control_repo dir
      from = get_required_option(:from)
      environment = get_required_option(:environment)

      control_repo.
        assert_remote_branch_exists(from).
        assert_no_remote_branch_exists(environment).
        create_branch_from(environment, from)
    end
  end

  def destroy_action
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      prepare_control_repo dir
      environment = get_required_option(:environment)

      control_repo.
        assert_remote_branch_exists(environment).
        destroy_remote_branch(environment)
    end
  end

end
