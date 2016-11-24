require 'tmpdir'
require 'fileutils'
require 'yaml'

module Ris
end

# Generic Git Hook functions
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class Ris::GitHook

  attr_accessor :branch,
                :action,
                :oldrev,
                :newrev

  def handle_hook_stdin(stdin)
    stdin.each_line do |line|
      (@oldrev, @newrev, ref) = line.split ' '
      @action = detect_action(oldrev, newrev)
      @branch = ref.split('/').last
      begin
        trigger_actions
      rescue => e
        exit_with_error e
      ensure
        remove_tempdir
        @repodir = nil
        @temp_files = nil
      end
    end
  end

  def set_actions(&code)
    @actions = code
  end

  def trigger_actions
    if @actions.kind_of? Proc
      instance_eval &@actions
    else
      puts "Implementing a Ris::GitHook without any actions makes no sense"
    end
  end

  def is_puppet_module?
    group_name.match /^puppet-modules-/
  end

  def is_ext_puppet_module?
    group_name == 'puppet-modules-ext'
  end

  def has_validator_checks_enabled?
    group_name == 'puppet-modules-int' || group_name == 'puppet-config'
  end

  def is_control_repo?
    group_name == 'puppet-config' && repo_name == 'control_repo'
  end

  def group_name
    detect_repo unless @group_name
    @group_name
  end

  def repo_name
    detect_repo unless @repo_name
    @repo_name
  end

  def detect_action(old, new)
    if old == no_branch
      action = 'create'
    elsif new == no_branch
      action = 'delete'
    else
      action = 'modify'
    end
  end

  def list_files
    case action
    when 'create'
      `git ls-tree --full-name -r #{newrev}`.split(/\n/).collect do |line|
        line.split(' ').last
      end
    when 'modify'
      `git diff --name-only #{oldrev} #{newrev}`.split(/\n/)
    when 'delete'
      files = []
    end
  end

  def run_all_validators
    validate_puppet_module
  end

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

  def self.run(&code)
    hook = self.new
    hook.set_actions &code
    hook.handle_hook_stdin STDIN
  end

  protected

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
    list_temp_files.select { |file|
      file.match filter
    }.each do |file|
      go_to_tempdir
      print_header header
      self.send method, repo_name + '/' + file
      @found_errors = true unless $? == 0
      go_to_former_dir
    end
  end

  def go_to_tempdir
    return if Dir.pwd == tempdir
    @old_dir = Dir.pwd
    Dir.chdir tempdir
  end

  def go_to_former_dir
    Dir.chdir @old_dir if @old_dir
    @old_dir = nil
  end

  def puppet_parser_validate(file)
    `puppet parser validate #{file}`
  end

  def puppet_lint(file)
    result = `puppet-lint --no-80chars-check --no-class_inherits_from_params_class-check --with-filename #{tempdir}/#{file}`
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

  def list_temp_files
    return @temp_files unless @temp_files.nil?
    dir = repodir
    @temp_files = []
    list_files.each do |file|
      FileUtils.mkdir_p(dir + '/' + File.dirname(file))
      hash = file_hash file
      next if hash.nil?
      `git cat-file blob #{hash} > #{dir}/#{file}`
      @temp_files << file
    end
    @temp_files
  end

  def tempdir
    if @tempdir.nil?
      @tempdir = Dir.mktmpdir
    end

    @tempdir
  end

  def repodir
    if @repodir.nil?
      @repodir = tempdir + '/' + repo_name
      Dir.mkdir @repodir
    end
    @repodir
  end

  def remove_tempdir
    FileUtils.rm_rf @tempdir if @tempdir
    @tempdir = nil
  end

  def file_hash(filename)
    file_hash_map[filename]
  end

  # Get a map of all objects in the new revision
  def file_hash_map
    if @file_hash_map.nil?
      @file_hash_map = {}
      `git ls-tree --full-name -r #{newrev}`.split(/\n/).each do |line|
        (mode, type, hash, filename) = line.split(/\s+/, 4)
        @file_hash_map[filename] = hash
      end
    end
    @file_hash_map
  end

  def no_branch
    @no_branch ||= '0' * 40
  end

  def exit_with_error(message)
    puts "ERROR: #{message}"
    exit 1
  end

  def detect_repo
    if Dir.pwd.match /\/([^\/]+)\/([^\/]+)\.git$/
      @group_name = $1
      @repo_name = $2
    else
      exit_with_error "Unable to determine GIT repository for '#{Dir.pwd}'"
    end
  end

end

