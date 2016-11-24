require 'ris/gitrepo'

# RisPuppet::Base contains basic functionality shared by all applications
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class RisPuppet::Base < Ris::BaseApplication

  attr_reader   :control_repo

  protected

  def initialize_logger
    Ris::Gitrepo.logger = app
  end

  def control_repo_url
    get_required_setting 'git_control_repo_url'
  end

  def prepare_control_repo(parent_dir)
    @control_repo = Ris::Gitrepo.new(parent_dir + '/control_repo')
    refresh_control_repo
  end

  def refresh_control_repo
    if control_repo.exists?
      control_repo.must_be_clean.fetch
    else
      control_repo.clone control_repo_url
    end
  end

  def list_remote_control_repo_branches
    Ris::Gitrepo.list_remote_heads control_repo_url
  end

  def checkout_control_repo_branch(branch)
    unless control_repo.has_remote_branch? branch
      raise "control_repo has no #{branch} branch. Please use '#{app.command_name} environment' to create a new environment."
    end

    control_repo.checkout branch
  end

  def controlrepo_commit_changes(message, push = true)
    if control_repo.is_dirty?
      control_repo.add puppetfile.filename
      control_repo.commit(message)
      control_repo.push_current_branch if push
    end
  end
end
