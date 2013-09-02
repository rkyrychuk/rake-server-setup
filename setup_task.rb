require 'ostruct'
require 'net/ssh'
require 'net/sftp'
require 'yaml'
require 'tempfile'
require 'fileutils'

class SetupTask < Rake::Task
  class RecursiveOpenStruct < OpenStruct
    def new_ostruct_member(name)
      name = name.to_sym
      unless self.respond_to?(name)
        class << self; self; end.class_eval do
          define_method(name) {
            v = @table[name]
            v.is_a?(Hash) ? RecursiveOpenStruct.new(v) : v
          }
          define_method("#{name}=") { |x| modifiable[name] = x }
          define_method("#{name}_as_hash") { @table[name] }
        end
      end
      name
    end
  end
  
  class << self
    def configuration
      unless @config
        config_path =  File.expand_path("config.yml", File.dirname(__FILE__))
        @config = RecursiveOpenStruct.new(YAML.load_file(config_path))
      end
      @config
    end
  end
  
  attr_accessor :setup_config
  def execute(args=nil)
    @setup_config = self.class.configuration
    super(args)
  end

  def connect_remote(args = {}, &block)
    server_config = self.setup_config.server
    options = args.dup.update(keys: [server_config.key])
    Net::SSH.start(server_config.ip, server_config.username, options) do |ssh|
      @ssh = ssh
      yield ssh
      @ssh = nil
    end
  end

  def run_remote!(command)
    printf("#{command}\n")
    @ssh.exec!(command)
  end

  def run_remote(command)
    printf("#{command}\n")
    current_channel = @ssh.open_channel do |channel|
      channel.exec command do |ch, success|
        #abort "could not execute command" unless success
        channel.on_data do |ch, data|
          print data
        end
        channel.on_extended_data do |ch, type, data|
          print data
        end
      end
    end
    current_channel.wait
  end

  def upload!(local_path, remote_path)
    print("uploading #{local_path} to #{remote_path}\n")
    sftp = Net::SFTP::Session.new(@ssh).connect!
    sftp.upload!(local_path, remote_path)
  end

  def download!(remote_path, local_path)
    print("downloading #{remote_path} to #{local_path}\n")
    sftp = Net::SFTP::Session.new(@ssh).connect!
    sftp.download!(remote_path, local_path)
  end

  def resolve_path(relative_path)
    File.expand_path(relative_path, File.dirname(__FILE__))
  end

  def modify_remote_file(path, &block)
    print("modify remote #{path}\n")
    tmp_path = Tempfile.new(File.basename(path)).path
    self.download!(path, tmp_path)
    File.write(tmp_path, yield(File.read(tmp_path)))
    self.upload!(tmp_path, path)
  end

  def upload_modified_file(local_path, remote_path, &block)
    print("modify #{local_path} with upload to #{remote_path}\n")
    tmp_path = Tempfile.new(File.basename(remote_path)).path
    File.write(tmp_path, yield(File.read(local_path)))
    self.upload!(tmp_path, remote_path)
  end

  def upload_modified_yaml(local_path, remote_path, &block)
    upload_modified_file(local_path, remote_path) do |content|
      yaml = YAML.load(content)
      yaml = yield(yaml)
      yaml.to_yaml
    end
  end
end

