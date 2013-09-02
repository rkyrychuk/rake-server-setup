require 'securerandom'
require 'rubygems'
require 'bundler/setup'
require_relative 'setup_task'

module Rake::DSL
  def setup_task(*args, &block) # :doc:
    SetupTask.define_task(*args, &block)
  end
end

task :default => ["setup:info"]

namespace :setup do
  task :info do
    printf "rake setup:access      #setup server access\n"
    printf "rake setup:environment #install environment\n"
    printf "rake setup:config      #install app config\n"
    printf "rake setup:app         #install app\n"
  end

  #task :all => [:environment, :config]
  task :environment => [:ruby, :nginx, :mysql]
  task :config => [:rails]

  desc "Setup access"
  setup_task :access do |t|
    server_config = t.setup_config.server

    print "Enter password: "
    password = $stdin.gets.strip
    public_key_data = File.read(server_config.public_key).strip
    t.connect_remote(password: password) do 
      t.run_remote("echo #{public_key_data} >> ~/.ssh/authorized_keys")
      t.run_remote("service ssh reload")
    end
    t.connect_remote do 
      t.modify_remote_file("/etc/ssh/sshd_config") do |content|
        content << "PasswordAuthentication no\n"
        content
      end
      t.run_remote("service ssh reload")
    end
  end
  
  desc "Setup ruby"
  setup_task :ruby do |t|
    ruby_config = t.setup_config.ruby
    file_name = File.basename(ruby_config.download_path).gsub(/\.tar\.gz$/, "")

    t.connect_remote do
      t.run_remote("apt-get install make gcc libssl-dev openssl libreadline6 libreadline6-dev -y")
      t.run_remote("wget #{ruby_config.download_path} -O #{file_name}.tar.gz")
      t.run_remote("tar -xf #{file_name}.tar.gz")
      t.run_remote("rm #{file_name}.tar.gz")
      t.run_remote("cd #{file_name} && ./configure --with-openssl-dir=/usr/lib/ssl")
      t.run_remote("cd #{file_name} && make")
      t.run_remote("cd #{file_name} && make install")
      t.run_remote("rm #{file_name} -Rf")
    end
  end

  desc "Setup nginx"
  setup_task :nginx do |t|
    nginx_config = t.setup_config.nginx
    file_name = File.basename(nginx_config.download_path).gsub(/\.tar\.gz$/, "")
    pcre_name = File.basename(nginx_config.pcre_path).gsub(/\.tar\.gz$/, "")
    
    t.connect_remote do
      pwd = t.run_remote!("pwd").strip

      t.run_remote("apt-get install g++ -y")
      t.run_remote("wget #{nginx_config.download_path} -O #{file_name}.tar.gz")
      t.run_remote("tar -xf #{file_name}.tar.gz")
      t.run_remote("rm #{file_name}.tar.gz")
      t.run_remote("cd #{file_name} && wget #{nginx_config.pcre_path} -O pcre.tar.gz")
      t.run_remote("cd #{file_name} && tar -xf pcre.tar.gz")
      t.run_remote("cd #{file_name} && ./configure --with-http_gzip_static_module --with-http_ssl_module --with-pcre=#{pwd}/#{file_name}/#{pcre_name}/ --conf-path=/etc/nginx/nginx.conf --conf-path=/etc/nginx/nginx.conf --prefix=/usr/local/nginx --sbin-path=/usr/local/sbin")
      t.run_remote("cd #{file_name} && make && make install")
      t.run_remote("rm #{file_name} -Rf")
    end
  end

  desc "Setup mysql"
  setup_task :mysql do |t|
    mysql_password = SecureRandom.hex(16)
    package_name = t.setup_config.mysql.package_name

    t.connect_remote do |ssh|
      t.run_remote("echo #{mysql_password} > .mysqlpwd")
      t.run_remote("debconf-set-selections <<< '#{package_name} mysql-server/root_password password #{mysql_password}'")
      t.run_remote("debconf-set-selections <<< '#{package_name} mysql-server/root_password_again password #{mysql_password}'")
      t.run_remote("apt-get update")
      t.run_remote("apt-get -y install #{package_name}")
    end
  end

  desc "Setup rails app"
  setup_task :rails do |t|
    rails_config = t.setup_config.rails
    app_path = "/var/www/#{rails_config.domain}" 
    server_name = rails_config.domain.gsub(/\./, "-")

    shared_files = rails_config.capistrano ? "#{app_path}/shared" : "#{app_path}"
    project_files = rails_config.capistrano ? "#{app_path}/current" : "#{app_path}"

    t.connect_remote do 
      pwd = t.run_remote!("cat .mysqlpwd").strip
      t.run_remote("mkdir -p #{shared_files}")
      t.run_remote("rm #{shared_files}/* -Rf")
      t.upload!(t.resolve_path("rails_app"), "#{shared_files}/")
      t.upload_modified_yaml(t.resolve_path("templates/database.yml"), "#{shared_files}/config/database.yml") do |yaml|
        yaml["production"]["password"] = pwd
        yaml
      end
      
      t.run_remote("mkdir -p /etc/thin")
      t.upload_modified_yaml(t.resolve_path("templates/thin.yml"), "/etc/thin/#{rails_config.domain}.yml") do |yaml|
        yaml["chdir"] = project_files
        yaml.update(rails_config.thin_as_hash) if rails_config.thin_as_hash
        yaml
      end

      t.run_remote("mkdir -p /var/log/nginx/")
      t.upload!(t.resolve_path("templates/nginx"), "/etc/nginx/")
      
      t.run_remote("mkdir -p /etc/nginx/sites-available")
      t.run_remote("mkdir -p /etc/nginx/sites-enabled")
      t.upload_modified_file(t.resolve_path("templates/nginx_site_config"), "/etc/nginx/sites-available/#{rails_config.domain}") do |site_config|
        sprintf(site_config, server_name: server_name, project_files: project_files, domain_name: rails_config.domain)
      end
      t.run_remote("ln -s /etc/nginx/sites-available/#{rails_config.domain} /etc/nginx/sites-enabled/#{rails_config.domain}")
      
      t.upload_modified_file(t.resolve_path("templates/app_start_script"), "/etc/init.d/#{rails_config.domain}") do |config|
        sprintf(config, project_files: project_files, domain_name: rails_config.domain)
      end
      
      t.upload!(t.resolve_path("templates/nginx_start_script"), "/etc/init.d/nginx")
      
      t.run_remote("chmod +x /etc/init.d/nginx")
      t.run_remote("chmod +x /etc/init.d/#{rails_config.domain}")

      t.run_remote("update-rc.d nginx defaults")
      t.run_remote("update-rc.d #{rails_config.domain} defaults")
    end
  end
end


