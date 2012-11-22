#!/usr/bin/env ruby

require 'optparse'
require 'find'
require 'etc'
require 'rubygems'

Version = "1.4"
SUPPORTED_SCM = %w( Subversion Darcs Mercurial Bazaar Git Filesystem )

$verbose      = 0
$quiet        = false
$redmine_host = ''
$repos_base   = ''
$svn_owner    = 'root'
$svn_group    = 'root'
$use_groupid  = true
$svn_url      = false
$test         = false
$force        = false
$scm          = 'Subversion'

def log(text, options={})
  level = options[:level] || 0
  puts text unless $quiet or level > $verbose
  exit 1 if options[:exit]
end

def system_or_raise(command)
  raise "\"#{command}\" failed" unless system command
end

module SCM

  module Subversion
    def self.create(path)
      system_or_raise "svnadmin create #{path}"
    end
  end

  module Git
    def self.create(path)
      Dir.mkdir path
      Dir.chdir(path) do
        system_or_raise "git --bare init --shared"
        system_or_raise "git update-server-info"
      end
    end
  end

end

def read_key_from_file(filename)
  begin
    $api_key = File.read(filename).strip
  rescue Exception => e
    $stderr.puts "Unable to read the key from #{filename}: #{e.message}"
    exit 1
  end
end

def set_scm(scm)
  $scm = scm.capitalize
  unless SUPPORTED_SCM.include?($scm)
    log("Invalid SCM: #{$scm}\nValid SCM are: #{SUPPORTED_SCM.join(', ')}", :exit => true)
  end
end

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: reposman.rb [OPTIONS...] -s [DIR] -r [HOST] -k [KEY]"
  opts.separator("")
  opts.separator("Manages your repositories with Redmine.")
  opts.separator("")
  opts.separator("Required arguments:") 
  opts.on("-s", "--svn-dir DIR",      "use DIR as base directory for svn repositories") {|v| $repos_base = v}
  opts.on("-r", "--redmine-host HOST","assume Redmine is hosted on HOST. Examples:",
                                       " -r redmine.example.net",
                                       " -r http://redmine.example.net",
                                       " -r https://redmine.example.net") {|v| $redmine_host = v}
  opts.on("-k", "--key KEY",           "use KEY as the Redmine API key",
                                       "(you can use --key-file option as an alternative)") {|v| $api_key = v}
  opts.separator("")
  opts.separator("Options:")
  opts.on("-o", "--owner OWNER",       "owner of the repository. using the rails login", 
                                       "allows users to browse the repository within",
                                       "Redmine even for private projects. If you want to",
                                       "share repositories through Redmine.pm, you need",
                                       "to use the apache owner.") {|v| $svn_owner = v; $use_groupid = false}
  opts.on("-g", "--group GROUP",       "group of the repository (default: root)") {|v| $svn_group = v; $use_groupid = false}
  opts.on("-u", "--url URL",           "the base url Redmine will use to access your",
                                       "repositories. This option is used to register",
                                       "the repositories in Redmine automatically. The",
                                       "project identifier will be appended to this url.",
                                       "Examples:",
                                       " -u https://example.net/svn",
                                       " -u file:///var/svn/",
                                       "if this option isn't set, reposman won't register",
                                       "the repositories in Redmine") {|v| $svn_url = v}
  opts.on(      "--scm SCM",           "the kind of SCM repository you want to create",
                                       "(and register) in Redmine (default: Subversion).",
                                       "reposman is able to create Git and Subversion",
                                       "repositories.",
                                       "For all other kind, you must specify a --command",
                                       "option") {|v| set_scm(v)}
  opts.on("-c", "--command COMMAND",   "use this command instead of `svnadmin create` to",
                                       "create a repository. This option can be used to",
                                       "create repositories other than subversion and git",
                                       "kind.",
                                       "This command override the default creation for",
                                       "git and subversion.") {|v| $command = v}
  opts.on(      "--key-file FILE",     "path to a file that contains the Redmine API key",
                                       "(use this option instead of --key if you don't", 
                                       "want the key to appear in the command line)") {|v| read_key_from_file(v)}
  opts.on("-t", "--test",              "only show what should be done") {$test = true}
  opts.on("-f", "--force",             "force repository creation even if the project", "repository is already declared in Redmine") {$force = true}
  opts.on("-v", "--verbose",           "verbose") {$verbose += 1}
  opts.on("-V", "--version",           "show version and exit") {puts Version; exit}
  opts.on("-h", "--help",              "show help and exit") {puts opts; exit 1}
  opts.on("-q", "--quiet",             "no log") {$quiet = true}
  opts.separator("")
  opts.separator("Examples:")
  opts.separator("  reposman.rb --svn-dir=/var/svn --redmine-host=redmine.host")
  opts.separator("  reposman.rb -s /var/git -r redmine.host -u http://git.host --scm git")
  opts.separator("")
  opts.separator("You can find more information on the redmine's wiki:\nhttp://www.redmine.org/projects/redmine/wiki/HowTos")

  opts.summary_width = 25
end
optparse.parse!

if $test
  log("running in test mode")
end

# Make sure command is overridden if SCM vendor is not handled internally (for the moment Subversion and Git)
if $command.nil?
  begin
    scm_module = SCM.const_get($scm)
  rescue
    log("Please use --command option to specify how to create a #{$scm} repository.", :exit => true)
  end
end

$svn_url += "/" if $svn_url and not $svn_url.match(/\/$/)

if ($redmine_host.empty? or $repos_base.empty?)
  puts "Some arguments are missing. Use reposman.rb --help for getting help."
  exit 1
end

unless File.directory?($repos_base)
  log("directory '#{$repos_base}' doesn't exists", :exit => true)
end

begin
  require 'active_resource'
rescue LoadError
  log("This script requires activeresource.\nRun 'gem install activeresource' to install it.", :exit => true)
end

class Project < ActiveResource::Base
  self.headers["User-agent"] = "Redmine repository manager/#{Version}"
  self.format = :xml
end

log("querying Redmine for projects...", :level => 1);

$redmine_host.gsub!(/^/, "http://") unless $redmine_host.match("^https?://")
$redmine_host.gsub!(/\/$/, '')

Project.site = "#{$redmine_host}/sys";

begin
  # Get all active projects that have the Repository module enabled
  projects = Project.find(:all, :params => {:key => $api_key})
rescue ActiveResource::ForbiddenAccess
  log("Request was denied by your Redmine server. Make sure that 'WS for repository management' is enabled in application settings and that you provided the correct API key.")
rescue => e
  log("Unable to connect to #{Project.site}: #{e}", :exit => true)
end

if projects.nil?
  log('No project found, perhaps you forgot to "Enable WS for repository management"', :exit => true)
end

log("retrieved #{projects.size} projects", :level => 1)

def set_owner_and_rights(project, repos_path, &block)
  if mswin?
    yield if block_given?
  else
    uid, gid = Etc.getpwnam($svn_owner).uid, ($use_groupid ? Etc.getgrnam(project.identifier).gid : Etc.getgrnam($svn_group).gid)
    right = project.is_public ? 0775 : 0770
    yield if block_given?
    Find.find(repos_path) do |f|
      File.chmod right, f
      File.chown uid, gid, f
    end
  end
end

def other_read_right?(file)
  (File.stat(file).mode & 0007).zero? ? false : true
end

def owner_name(file)
  mswin? ?
    $svn_owner :
    Etc.getpwuid( File.stat(file).uid ).name
end

def mswin?
  (RUBY_PLATFORM =~ /(:?mswin|mingw)/) || (RUBY_PLATFORM == 'java' && (ENV['OS'] || ENV['os']) =~ /windows/i)
end

projects.each do |project|
  log("treating project #{project.name}", :level => 1)

  if project.identifier.empty?
    log("\tno identifier for project #{project.name}")
    next
  elsif not project.identifier.match(/^[a-z0-9\-_]+$/)
    log("\tinvalid identifier for project #{project.name} : #{project.identifier}");
    next;
  end

  repos_path = File.join($repos_base, project.identifier).gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)

  if File.directory?(repos_path)
    # we must verify that repository has the good owner and the good
    # rights before leaving
    other_read = other_read_right?(repos_path)
    owner      = owner_name(repos_path)
    next if project.is_public == other_read and owner == $svn_owner

    if $test
      log("\tchange mode on #{repos_path}")
      next
    end

    begin
      set_owner_and_rights(project, repos_path)
    rescue Errno::EPERM => e
      log("\tunable to change mode on #{repos_path} : #{e}\n")
      next
    end

    log("\tmode change on #{repos_path}");

  else
    # if repository is already declared in redmine, we don't create
    # unless user use -f with reposman
    if $force == false and project.respond_to?(:repository)
      log("\trepository for project #{project.identifier} already exists in Redmine", :level => 1)
      next
    end

    project.is_public ? File.umask(0002) : File.umask(0007)

    if $test
      log("\tcreate repository #{repos_path}")
      log("\trepository #{repos_path} registered in Redmine with url #{$svn_url}#{project.identifier}") if $svn_url;
      next
    end

    begin
      set_owner_and_rights(project, repos_path) do
        if scm_module.nil?
          system_or_raise "#{$command} #{repos_path}"
        else
          scm_module.create(repos_path)
        end
      end
    rescue => e
      log("\tunable to create #{repos_path} : #{e}\n")
      next
    end

    if $svn_url
      begin
        project.post(:repository, :vendor => $scm, :repository => {:url => "#{$svn_url}#{project.identifier}"}, :key => $api_key)
        log("\trepository #{repos_path} registered in Redmine with url #{$svn_url}#{project.identifier}");
      rescue => e
        log("\trepository #{repos_path} not registered in Redmine: #{e.message}");
      end
    end
    log("\trepository #{repos_path} created");
  end
end
