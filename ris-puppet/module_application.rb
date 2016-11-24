require 'ris/puppetfile'
require File.expand_path('../base.rb', __FILE__)
require 'yaml'

# RisPuppet::Module manages the control_repo's Puppetfile in the specified environment
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class RisPuppet::Module < RisPuppet::Base

  attr_reader :current_repo, :puppetfile

  def init
    initialize_logger
    add_option :environment, "-e", "--env=ENVIRONMENT", "Desired Puppet environment"
    add_option :ref,         "-r", "--ref=REFERENCE",   "Git reference (Tag, Commit, Branch - deploy only)"
    add_option :module,      "-m", "--module=MODULE",   "Puppet module name (remove only)"
    add_option :force,       "-f", "--force",           "Force deploy in protected environments (for emergencys only!)"
    add_option :comment,     "-c", "--comment=COMMENT", "Optional comment added to control-repo commit"
  end

  def deploy_action
    assert_action_not_in_force_environment
    prepare_current_repo
    prepare_control_repo(File.dirname(current_repo.basedir))
    checkout_control_repo_branch target_branch
    prepare_puppetfile
    set_puppetfile_module project, desired_ref
    controlrepo_commit_changes(append_comment_to_message("Pinned #{project} to #{desired_ref[0,9]}'"))
  end

  def pin_action
    assert_action_not_in_force_environment
    prepare_current_repo
    prepare_control_repo(File.dirname(current_repo.basedir))
    checkout_control_repo_branch target_branch
    prepare_puppetfile
    set_puppetfile_module project, desired_ref
    controlrepo_commit_changes(append_comment_to_message("Pinned #{project} to #{desired_ref[0,9]}'"), false)
  end

  def remove_action
    assert_action_not_in_force_environment
    if has_option? :module
      remove_module_by_name get_option(:module)
    else
      remove_current_module
    end
  end

  def unpin_action
    assert_action_not_in_force_environment
    if has_option? :module
      remove_module_by_name get_option(:module), false
    else
      remove_current_module false
    end
  end

  def validate_action
    validate_puppet_module
  end

  protected

  def append_comment_to_message(message, autocomment = true)
    if has_option? :comment
      "#{message}: #{get_option :comment}"
    else
      if autocomment
        cmt = current_repo.get_last_commit_message
        if cmt
          "#{message}: #{cmt}"
        else
          message
        end
      else
        message
      end
    end
  end

  def remove_module_by_name(name, push = true)
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      prepare_control_repo dir
      checkout_control_repo_branch target_branch
      remove_and_commit name, push
    end
  end

  def remove_current_module(push = true)
    prepare_current_repo
    prepare_control_repo(File.dirname(current_repo.basedir))
    checkout_control_repo_branch target_branch
    remove_and_commit project, push
  end

  def remove_and_commit(module_name, push)
    prepare_puppetfile
    unset_puppetfile_module module_name
    controlrepo_commit_changes(append_comment_to_message("Removed #{module_name}", false), push)
  end

  def target_branch
    @target_branch ||= get_option(:environment, get_setting('module_application_default_environment'))
  end

  def prepare_current_repo
    @current_repo = Ris::Gitrepo.new(
      Ris::Gitrepo::detect_basedir
    ).must_be_clean.must_have_nothing_to_push.fetch
  end

  def prepare_puppetfile
    control_repo.pull
    @puppetfile = Ris::Puppetfile.new(control_repo.basedir + '/Puppetfile')
  end

  def desired_ref
    if @ref.nil?

      if has_option? :ref
        ref = get_option :ref
      else
        ref = current_repo.current_tag_or_commit
      end
      assert_valid_ref ref
      @ref = "'#{ref}'"
    end

    @ref
  end

  def assert_action_not_in_force_environment
    force_envs = get_setting('module_application_force_environments')
    raise "You must use a Merge Request to perform an action in the '#{target_branch}' environment!" if force_envs and force_envs.include? target_branch and ! has_option?(:force)
  end

  def assert_valid_ref(ref)
    return if current_repo.remote_has_tag? ref
    hash = current_repo.resolve_ref ref
    raise "Unable to resolve '#{ref}'" if hash.nil?
    raise "'#{ref}' does not exist at origin" unless current_repo.remote_has_commit? hash
  end

  def git_group
    parse_origin_url if @git_group.nil?
    @git_group
  end

  def project
    parse_origin_url if @project.nil?
    @project
  end

  def parse_origin_url
    repo_path = current_repo.get_config('remote.origin.url').gsub /^.*:(.*)\.git$/, '\1'
    (@git_group, @project) = repo_path.split '/', 2
    unless get_required_setting('module_application_git_module_groups').include? @git_group
      raise "Unsupported git group: #{@git_group}"
    end
    @project.sub!(/-/, '/')

    return nil
  end

  def set_puppetfile_module(module_name, ref)
    puppetfile.set_module module_name, ref
    puppetfile.store
  end

  def unset_puppetfile_module(module_name)
    puppetfile.unset_module module_name
    puppetfile.store
  end

  # from GitHooks

  def validate_puppet_module
    prepare_environment
    check_puppet_manifests
    check_puppet_syntax
    check_erb_syntax
    check_ruby_syntax
    check_yaml_syntax
  end

  def check_puppet_syntax
    run_check_method 'puppet_lint', /\.pp$/, ' * Validating Puppet style (lint)'
  end

  def check_puppet_manifests
    run_check_method 'puppet_parser_validate', /\.pp$/, ' * Checking Puppet manifest syntax'
  end

  def check_erb_syntax
    run_check_method 'erb_syntax', /\.erb$/, ' * Checking ERB syntax'
  end

  def check_yaml_syntax
    run_check_method 'yaml_syntax', /\.(?:yaml|yml)$/, ' * Checking YAML syntax'
  end

  def check_ruby_syntax
    run_check_method 'ruby_syntax', /\.rb$/, ' * Checking Ruby syntax'
  end

  def prepare_environment
    ENV.delete 'RUBYOPT'
    ENV.delete 'BUNDLE_BIN_PATH'
    ENV.delete 'BUNDLE_GEMFILE'
    ENV.delete 'GEM_PATH'
    ENV.delete 'GEM_HOME'
    ENV['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    unless ENV.has_key? 'HOME'
      require 'etc'
      ENV['HOME'] = Etc.getpwuid.dir
    end
  end

  def run_check_method(method, filter, header)
    list_files.select { |file|
      file.match filter
    }.each do |file|
      print_header header
      if has_option? :debug
        puts "   - #{file}"
      end
      self.send method, file
      @found_errors = true unless $? == 0
    end
  end

  def puppet_parser_validate(file)
    `puppet parser validate #{file}`
  end

  def puppet_lint(file)
    result = `puppet-lint --no-80chars-check --no-class_inherits_from_params_class-check --with-filename #{file}`
    puts result unless result.empty?
  end

  def erb_syntax(file)
    `erb -P -x -T '-' #{file} | ruby -c`
  end

  def ruby_syntax(file)
    `ruby -c #{file}`
  end

  def yaml_syntax(file)
    begin
      YAML.load_file(file)
    rescue => e
      puts "YAML error: #{e}"
      @found_errors = true
    end
  end

  def found_errors?
    @found_errors == true
  end

  def print_header(header)
    puts header unless headers.has_key? header
    @headers[header] = true
  end

  def headers
    @headers ||= {}
  end

  def list_files
    basedir = Ris::Gitrepo::detect_basedir
    file_list = []
    Dir.chdir(basedir) do
      Dir.glob("**/*").each do |f|
        file_list << File.join(basedir, f) if File.file? f
      end
    end
    file_list
  end

end
