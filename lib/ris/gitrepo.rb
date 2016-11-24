require 'shellwords'

# Ris::Gitrepo is a wrapper to the GIT CLI
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class Ris::Gitrepo

  attr_accessor :basedir,
                :source

  def initialize(basedir)
    @basedir = basedir
  end

  def get_last_commit_message
    lines = git('log', '-1').split(/\n/)
    lines[4].strip if lines.length >= 5
  end

  def self.detect_basedir
    dir = run_git 'rev-parse', '--show-toplevel'
    raise "I'm not in a git repository" unless $? == 0
    return dir
  end

  def is_clean?
    git('status', '--porcelain').empty?
  end

  def is_dirty?
    ! is_clean?
  end

  def must_be_clean
    raise "Working directory #{basedir} is dirty, please clean up or commit your changes" if is_dirty?
    self
  end

  def must_have_nothing_to_push
    must_have_nothing_to_push_to current_branch
  end

  def must_have_nothing_to_push_to(branch)
    cnt = unpushed_commits(branch).length
    raise "Working directory #{basedir} has #{cnt} unpushed commits for branch #{branch}" if cnt > 0
    self
  end

  def list_remote_heads
    git('ls-remote', '--heads', 'origin').split(/\n/).collect do |line|
      line.split(/\s+/).last
    end
  end

  def list_remote_tags
    git('ls-remote', '--tags', 'origin').split(/\n/).collect do |line|
      line.split(/\s+/).last
    end
  end

  def exists?
    File.directory? basedir
  end

  def has_remote_branch?(branch)
    list_remote_heads.include? 'refs/heads/' + branch
  end

  def has_branch?(branch)
    git 'show-ref', '--verify', '--quiet', 'refs/heads/' + branch
    $? == 0
  end

  def assert_remote_branch_exists(branch)
    raise "There is no such remote branch: #{branch}" unless has_remote_branch? branch
    self
  end

  def assert_no_remote_branch_exists(branch)
    raise "Remote branch already exists: #{branch}" if has_remote_branch? branch
    self
  end

  def get_config(key)
    git 'config', '--get', key
  end

  def create
    raise "Cannot create repo in #{basedir}, directory already exists" if exists?
    File.mkdir basedir
    git 'init'
  end

  def clone(origin)
    raise "Cannot create repo in #{basedir}, directory already exists" if exists?
    source = origin
    self.class.run_git 'clone', '-q', source, basedir
  end

  def pull
    # As of a bug git pull refuses to run with --work-tree
    Dir.chdir(basedir) do
      self.class.debug "In directory: #{Dir.pwd}"
      self.class.run_git 'pull'
    end
    self.class.debug "Back to directory: #{Dir.pwd}"
    assert_success
  end

  def unpushed_commits(branch)
    # gives list of ">a2345a9..."
    git('rev-list', '--left-right', 'refs/remotes/origin/' + branch + '...HEAD').split(/\n/)
  end

  def fetch
    git 'fetch', '--all', '--tags'
    assert_success
  end

  def current_branch
    git('rev-parse', '--symbolic-full-name', '--abbrev-ref', 'HEAD')
  end

  def checkout(ref, branch = nil)
    branch = ref if branch.nil?
    if has_branch? branch
      git 'checkout', '-q', branch
    else
      git 'checkout', '-q', '-b', branch, 'origin/' + ref
    end
    assert_success
  end

  def current_commit
    resolve_ref 'HEAD'
  end

  def resolve_ref(ref)
    hash = git 'rev-parse', '--verify', ref
    hash if $? == 0
  end

  def remote_has_commit?(hash)
    git('log', '--remotes=origin', '--pretty=%H', '--all').include? hash
  end

  def remote_has_tag?(tag)
    list_remote_tags.include? "refs/tags/#{tag}"
  end

  def tag_name(revision, default = nil)
    tag = git 'name-rev', '--tags', '--name-only', revision
    if tag == 'undefined'
      return default
    end
    tag.gsub /\^.*$/, ''
  end

  def current_tag_or_commit
    rev = current_commit
    tag_name rev, rev
  end

  def add(*args)
    self.send 'git', 'add', *args
    assert_success
  end

  def commit(message)
    git 'commit', '-m', message
    assert_success
  end

  def push
    git 'push'
    assert_success
  end

  def push_current_branch
    git 'push', '-u', 'origin', current_branch
    assert_success
  end

  def create_branch_from(branch, source)
    git 'checkout', '-b', branch, source
    assert_success
    git 'push', '-u', 'origin', branch
    assert_success
  end

  def destroy_local_branch(branch)
    git 'branch', '-D', branch
    assert_success
  end

  def destroy_remote_branch(branch)
    git 'push', 'origin', ':' + branch
    assert_success
  end

  def gitdir
    basedir + '/.git'
  end

  def assert_success
    raise "Command execution failed (#{$?}): #{@@last_command}" unless $? == 0
    self
  end

  def git(*args)
    args.unshift('--work-tree', basedir, '--git-dir', gitdir)
    self.class.send 'run_git', *args
  end

  def self.run_git(*args)
    params = args.collect{ |arg|
      arg.shellescape
    }.join ' '
   
    @@last_command = "git #{params}"
    debug "Running: #{@@last_command}"

    `#{@@last_command}`.chomp
  end

  def self.list_remote_heads(url)
    run_git('ls-remote', '--heads', url).split(/\n/).collect do |line|
      line.split(/\s+/).last
    end
  end

  def self.list_remote_tags(url)
    run_git('ls-remote', '--tags', url).split(/\n/).collect do |line|
      line.split(/\s+/).last
    end
  end

  def self.debug(message)
    @@logger.debug message if @@logger
  end

  def self.logger=(logger)
    @@logger = logger
  end

end
