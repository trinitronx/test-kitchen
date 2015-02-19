# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
#
# Copyright (C) 2014, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative "../../spec_helper"

require "kitchen"
require "kitchen/provisioner/chef_base"

describe Kitchen::Provisioner::ChefBase do

  let(:logged_output)   { StringIO.new }
  let(:logger)          { Logger.new(logged_output) }

  let(:config) do
    { :test_base_path => "/basist", :kitchen_root => "/rooty" }
  end

  let(:suite) do
    stub(:name => "fries")
  end

  let(:instance) do
    stub(:name => "coolbeans", :logger => logger, :suite => suite)
  end

  let(:provisioner) do
    Class.new(Kitchen::Provisioner::ChefBase) {
      def calculate_path(path, _opts = {})
        "<calculated>/#{path}"
      end
    }.new(config).finalize_config!(instance)
  end

  describe "configuration" do

    it ":require_chef_omnibus defaults to true" do
      provisioner[:require_chef_omnibus].must_equal true
    end

    it ":chef_omnibus_url has a default" do
      provisioner[:chef_omnibus_url].
        must_equal "https://www.chef.io/chef/install.sh"
    end

    it ":chef_omnibus_root has a default" do
      provisioner[:chef_omnibus_root].must_equal "/opt/chef"
    end

    it ":chef_omnibus_install_options defaults to nil" do
      provisioner[:chef_omnibus_install_options].must_equal nil
    end

    it ":run_list defaults to an empty array" do
      provisioner[:run_list].must_equal []
    end

    it ":attributes defaults to an empty hash" do
      provisioner[:attributes].must_equal Hash.new
    end

    it ":log_file defaults to nil" do
      provisioner[:log_file].must_equal nil
    end

    it ":cookbook_files_glob includes recipes" do
      provisioner[:cookbook_files_glob].must_match %r{,recipes/}
    end

    it ":data_path uses calculate_path and is expanded" do
      provisioner[:data_path].must_equal "/rooty/<calculated>/data"
    end

    it ":data_bags_path uses calculate_path and is expanded" do
      provisioner[:data_bags_path].must_equal "/rooty/<calculated>/data_bags"
    end

    it ":environments_path uses calculate_path and is expanded" do
      provisioner[:environments_path].
        must_equal "/rooty/<calculated>/environments"
    end

    it ":nodes_path uses calculate_path and is expanded" do
      provisioner[:nodes_path].must_equal "/rooty/<calculated>/nodes"
    end

    it ":roles_path uses calculate_path and is expanded" do
      provisioner[:roles_path].must_equal "/rooty/<calculated>/roles"
    end

    it ":clients_path uses calculate_path and is expanded" do
      provisioner[:clients_path].must_equal "/rooty/<calculated>/clients"
    end

    it "...secret_key_path uses calculate_path and is expanded" do
      provisioner[:encrypted_data_bag_secret_key_path].
        must_equal "/rooty/<calculated>/encrypted_data_bag_secret_key"
    end
  end

  describe "#install_command" do

    it "returns nil if :require_chef_omnibus is falsey" do
      config[:require_chef_omnibus] = false

      provisioner.install_command.must_equal nil
    end

    it "uses bourne shell (sh)" do
      provisioner.install_command.must_match(/\Ash -c '$/)
    end

    it "ends with a single quote" do
      provisioner.install_command.must_match(/'\Z/)
    end

    it "installs chef using :chef_omnibus_url, if necessary" do
      config[:chef_omnibus_url] = "FROM_HERE"

      provisioner.install_command.must_match regexify(
        "do_download FROM_HERE /tmp/install.sh")
    end

    it "will install a specific version of chef, if necessary" do
      config[:require_chef_omnibus] = "1.2.3"

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh -v 1.2.3")
      provisioner.install_command.must_match regexify(
        "Installing Chef Omnibus (1.2.3)", :partial_line)
    end

    it "will install a major/minor version of chef, if necessary" do
      config[:require_chef_omnibus] = "11.10"

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh -v 11.10")
      provisioner.install_command.must_match regexify(
        "Installing Chef Omnibus (11.10)", :partial_line)
    end

    it "will install a major version of chef, if necessary" do
      config[:require_chef_omnibus] = "12"

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh -v 12")
      provisioner.install_command.must_match regexify(
        "Installing Chef Omnibus (12)", :partial_line)
    end

    it "will install a downcaased version string of chef, if necessary" do
      config[:require_chef_omnibus] = "10.1.0.RC.1"

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh -v 10.1.0.rc.1")
      provisioner.install_command.must_match regexify(
        "Installing Chef Omnibus (10.1.0.rc.1)", :partial_line)
    end

    it "will install the latest of chef, if necessary" do
      config[:require_chef_omnibus] = "latest"

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh ")
      provisioner.install_command.must_match regexify(
        "Installing Chef Omnibus (always install latest version)",
        :partial_line
      )
    end

    it "will install a of chef, unless it exists" do
      config[:require_chef_omnibus] = true

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh ")
      provisioner.install_command.must_match regexify(
        "Installing Chef Omnibus (install only if missing)", :partial_line)
    end

    it "will pass install options, when given" do
      config[:chef_omnibus_install_options] = "-P chefdk"

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh -P chefdk")
      provisioner.install_command.must_match regexify(
        "Installing Chef Omnibus (install only if missing)", :partial_line)
    end

    it "will pass install options and version info, when given" do
      config[:require_chef_omnibus] = "11"
      config[:chef_omnibus_install_options] = "-d /tmp/place"

      provisioner.install_command.must_match regexify(
        "sudo -E sh /tmp/install.sh -v 11 -d /tmp/place")
    end
  end

  describe "#init_command" do

    it "uses bourne shell" do
      provisioner.init_command.must_match(/\Ash -c '$/)
      provisioner.init_command.must_match(/'\Z/)
    end

    it "uses sudo for rm when configured" do
      config[:sudo] = true

      provisioner.init_command.
        must_match regexify("sudo -E rm -rf ", :partial_line)
    end

    it "does not use sudo for rm when configured" do
      config[:sudo] = false

      provisioner.init_command.
        must_match regexify("rm -rf ", :partial_line)
      provisioner.init_command.
        wont_match regexify("sudo -E rm -rf ", :partial_line)
    end

    %w[cookbooks data data_bags environments roles clients].each do |dir|
      it "removes the #{dir} directory" do
        config[:root_path] = "/route"

        provisioner.init_command.must_match %r{rm -rf\b.*\s+/route/#{dir}\s+}
      end
    end

    it "creates :root_path directory" do
      config[:root_path] = "/root/path"

      provisioner.init_command.must_match regexify("mkdir -p /root/path")
    end
  end

  describe "#create_sandbox" do

    before do
      @root = Dir.mktmpdir
      config[:kitchen_root] = @root
    end

    after do
      FileUtils.remove_entry(@root)
      begin
        provisioner.cleanup_sandbox
      rescue # rubocop:disable Lint/HandleExceptions
      end
    end

    let(:provisioner) do
      Class.new(Kitchen::Provisioner::ChefBase) {
        default_config :generic_rb, {}

        def create_sandbox
          super

          data = default_config_rb.merge(config[:generic_rb])
          File.open(File.join(sandbox_path, "generic.rb"), "wb") do |file|
            file.write(format_config_file(data))
          end
        end
      }.new(config).finalize_config!(instance)
    end

    describe "json file" do

      let(:json) { JSON.parse(IO.read(sandbox_path("dna.json"))) }

      it "creates a json file with node attributes" do
        config[:attributes] = { "one" => { "two" => "three" } }
        provisioner.create_sandbox

        json["one"].must_equal("two" => "three")
      end

      it "creates a json file with run_list" do
        config[:run_list] = %w[alpha bravo charlie]
        provisioner.create_sandbox

        json["run_list"].must_equal %w[alpha bravo charlie]
      end

      it "creates a json file with an empty run_list" do
        config[:run_list] = []
        provisioner.create_sandbox

        json["run_list"].must_equal []
      end

      it "logs a message on info" do
        provisioner.create_sandbox

        logged_output.string.must_match info_line("Preparing dna.json")
      end

      it "logs a message on debug" do
        config[:run_list] = ["yo"]
        provisioner.create_sandbox

        logged_output.string.
          must_match debug_line(%|Creating dna.json from {:run_list=>["yo"]}|)
      end
    end

    it "creates a cache directory" do
      provisioner.create_sandbox

      sandbox_path("cache").directory?.must_equal true
    end

    %w[data data_bags environments nodes roles clients].each do |thing|
      describe "#{thing} files" do

        before do
          create_files_under("#{config[:kitchen_root]}/my_#{thing}")
          config[:"#{thing}_path"] = "#{config[:kitchen_root]}/my_#{thing}"
        end

        it "skips directory creation if :#{thing}_path is not set" do
          config[:"#{thing}_path"] = nil
          provisioner.create_sandbox

          sandbox_path(thing).directory?.must_equal false
        end

        it "copies tree from :#{thing}_path into sandbox" do
          provisioner.create_sandbox

          sandbox_path("#{thing}/alpha.txt").file?.must_equal true
          IO.read(sandbox_path("#{thing}/alpha.txt")).must_equal "stuff"
          sandbox_path("#{thing}/sub").directory?.must_equal true
          sandbox_path("#{thing}/sub/bravo.txt").file?.must_equal true
          IO.read(sandbox_path("#{thing}/sub/bravo.txt")).must_equal "junk"
        end

        it "logs a message on info" do
          provisioner.create_sandbox

          logged_output.string.must_match info_line("Preparing #{thing}")
        end

        it "logs a message on debug" do
          provisioner.create_sandbox

          logged_output.string.must_match debug_line(
            "Using #{thing} from #{config[:kitchen_root]}/my_#{thing}")
        end
      end
    end

    describe "secret files" do

      before do
        config[:encrypted_data_bag_secret_key_path] =
          "#{config[:kitchen_root]}/my_secret"
        File.open("#{config[:kitchen_root]}/my_secret", "wb") do |file|
          file.write("p@ss")
        end
      end

      it "skips file if :encrypted_data_bag_secret_key_path is not set" do
        config[:encrypted_data_bag_secret_key_path] = nil
        provisioner.create_sandbox

        sandbox_path("encrypted_data_bag_secret").file?.must_equal false
      end

      it "copies file from :encrypted_data_bag_secret_key_path into sandbox" do
        provisioner.create_sandbox

        sandbox_path("encrypted_data_bag_secret").file?.must_equal true
        IO.read(sandbox_path("encrypted_data_bag_secret")).must_equal "p@ss"
      end

      it "logs a message on info" do
        provisioner.create_sandbox

        logged_output.string.must_match info_line("Preparing secret")
      end

      it "logs a message on debug" do
        provisioner.create_sandbox

        logged_output.string.must_match debug_line(
          "Using secret from #{config[:kitchen_root]}/my_secret")
      end
    end

    describe "cookbooks" do

      let(:kitchen_root) { config[:kitchen_root] }

      describe "with a cookbooks/ directory under kitchen_root" do

        it "copies cookbooks/" do
          create_cookbook("#{kitchen_root}/cookbooks/epache")
          create_cookbook("#{kitchen_root}/cookbooks/jahva")
          provisioner.create_sandbox

          sandbox_path("cookbooks/epache").directory?.must_equal true
          sandbox_path("cookbooks/epache/recipes/default.rb").
            file?.must_equal true
          sandbox_path("cookbooks/jahva").directory?.must_equal true
          sandbox_path("cookbooks/jahva/recipes/default.rb").
            file?.must_equal true
        end

        it "copies from kitchen_root as cookbook if it contains metadata.rb" do
          File.open("#{kitchen_root}/metadata.rb", "wb") do |file|
            file.write("name 'wat'")
          end
          create_cookbook("#{kitchen_root}/cookbooks/bk")
          provisioner.create_sandbox

          sandbox_path("cookbooks/bk").directory?.must_equal true
          sandbox_path("cookbooks/wat").directory?.must_equal true
          sandbox_path("cookbooks/wat/metadata.rb").file?.must_equal true
        end

        it "copies site-cookbooks/ if it exists" do
          create_cookbook("#{kitchen_root}/cookbooks/upstream")
          create_cookbook("#{kitchen_root}/site-cookbooks/mine")
          provisioner.create_sandbox

          sandbox_path("cookbooks/upstream").directory?.must_equal true
          sandbox_path("cookbooks/mine").directory?.must_equal true
          sandbox_path("cookbooks/mine/attributes/all.rb").file?.must_equal true
        end

        it "logs a message on info for cookbooks/ directory" do
          create_cookbook("#{kitchen_root}/cookbooks/epache")
          provisioner.create_sandbox

          logged_output.string.must_match info_line(
            "Preparing cookbooks from project directory")
        end

        it "logs a meesage on debug for cookbooks/ directory" do
          create_cookbook("#{kitchen_root}/cookbooks/epache")
          provisioner.create_sandbox

          logged_output.string.must_match debug_line(
            "Using cookbooks from #{kitchen_root}/cookbooks")
        end

        it "logs a message on info for site-cookbooks/ directory" do
          create_cookbook("#{kitchen_root}/cookbooks/epache")
          create_cookbook("#{kitchen_root}/site-cookbooks/mine")
          provisioner.create_sandbox

          logged_output.string.must_match info_line(
            "Preparing site-cookbooks from project directory")
        end

        it "logs a meesage on debug for site-cookbooks/ directory" do
          create_cookbook("#{kitchen_root}/cookbooks/epache")
          create_cookbook("#{kitchen_root}/site-cookbooks/mine")
          provisioner.create_sandbox

          logged_output.string.must_match debug_line(
            "Using cookbooks from #{kitchen_root}/site-cookbooks")
        end
      end

      describe "with a cookbook as the project" do

        before do
          File.open("#{kitchen_root}/metadata.rb", "wb") do |file|
            file.write("name 'wat'")
          end
        end

        it "copies from kitchen_root as cookbook if it contains metadata.rb" do
          provisioner.create_sandbox

          sandbox_path("cookbooks/wat").directory?.must_equal true
          sandbox_path("cookbooks/wat/metadata.rb").file?.must_equal true
        end

        it "logs a message on info" do
          provisioner.create_sandbox

          logged_output.string.must_match info_line(
            "Preparing current project directory as a cookbook")
        end

        it "logs a meesage on debug" do
          provisioner.create_sandbox

          logged_output.string.must_match debug_line(
            "Using metadata.rb from #{kitchen_root}/metadata.rb")
        end

        it "raises a UserError is name cannot be determined from metadata.rb" do
          File.open("#{kitchen_root}/metadata.rb", "wb") do |file|
            file.write("nameeeeee 'wat'")
          end

          proc { provisioner.create_sandbox }.must_raise Kitchen::UserError
        end
      end

      describe "with no referenced cookbooks" do

        it "makes a fake cookbook" do
          name = File.basename(@root)
          provisioner.create_sandbox

          sandbox_path("cookbooks/#{name}").directory?.must_equal true
          sandbox_path("cookbooks/#{name}/metadata.rb").file?.must_equal true
          IO.read(sandbox_path("cookbooks/#{name}/metadata.rb")).
            must_equal %{name "#{name}"\n}
        end

        it "logs a warning" do
          provisioner.create_sandbox

          logged_output.string.must_match regexify(
            "Berksfile, Cheffile, cookbooks/, or metadata.rb not found",
            :partial_line
          )
        end
      end

      describe "with a Berksfile under kitchen_root" do

        let(:resolver) { stub(:resolve => true) }

        before do
          File.open("#{kitchen_root}/Berksfile", "wb") do |file|
            file.write("cookbook 'wat'")
          end
          Kitchen::Provisioner::Chef::Berkshelf.stubs(:new).returns(resolver)
        end

        it "raises a UserError if Berkshelf library can't be loaded" do
          proc { provisioner }.must_raise Kitchen::UserError
        end

        it "logs on debug that Berkshelf is loading" do
          Kitchen::Provisioner::Chef::Berkshelf.stubs(:load!)
          provisioner

          logged_output.string.must_match debug_line(
            "Berksfile found at #{kitchen_root}/Berksfile, loading Berkshelf")
        end

        it "uses Berkshelf" do
          Kitchen::Provisioner::Chef::Berkshelf.stubs(:load!)
          resolver.expects(:resolve)

          provisioner.create_sandbox
        end

        it "uses Kitchen.mutex for resolving" do
          Kitchen::Provisioner::Chef::Berkshelf.stubs(:load!)
          Kitchen.mutex.expects(:synchronize)

          provisioner.create_sandbox
        end
      end

      describe "with a Cheffile under kitchen_root" do

        let(:resolver) { stub(:resolve => true) }

        before do
          File.open("#{kitchen_root}/Cheffile", "wb") do |file|
            file.write("cookbook 'wat'")
          end
          Kitchen::Provisioner::Chef::Librarian.stubs(:new).returns(resolver)
        end

        it "raises a UserError if Librarian library can't be loaded" do
          proc { provisioner }.must_raise Kitchen::UserError
        end

        it "logs on debug that Berkshelf is loading" do
          Kitchen::Provisioner::Chef::Librarian.stubs(:load!)
          provisioner

          logged_output.string.must_match debug_line(
            "Cheffile found at #{kitchen_root}/Cheffile, loading Librarian-Chef"
          )
        end

        it "uses Librarian" do
          Kitchen::Provisioner::Chef::Librarian.stubs(:load!)
          resolver.expects(:resolve)

          provisioner.create_sandbox
        end

        it "uses Kitchen.mutex for resolving" do
          Kitchen::Provisioner::Chef::Librarian.stubs(:load!)
          Kitchen.mutex.expects(:synchronize)

          provisioner.create_sandbox
        end
      end

      describe "filtering cookbooks files" do

        it "retains all useful cookbook files" do
          create_full_cookbook("#{kitchen_root}/cookbooks/full")
          provisioner.create_sandbox

          full_cookbook_files.each do |file|
            sandbox_path("cookbooks/full/#{file}").file?.must_equal true
          end
        end

        it "strips extra cookbook files" do
          extras = %w[
            .gitignore tmp/librarian chefignore .git/info/excludes
            cookbooks/another/metadata.rb CONTRIBUTING.md metadata.py
          ]

          create_full_cookbook("#{kitchen_root}/cookbooks/full")
          extras.each do |file|
            create_file("#{kitchen_root}/cookbooks/full/#{file}")
          end
          provisioner.create_sandbox

          extras.each do |file|
            sandbox_path("cookbooks/full/#{file}").file?.must_equal false
          end
        end

        it "logs on info" do
          create_full_cookbook("#{kitchen_root}/cookbooks/full")
          provisioner.create_sandbox

          logged_output.string.must_match info_line(
            "Removing non-cookbook files before transfer")
        end
      end

      describe "Chef config files" do

        let(:file) do
          IO.read(sandbox_path("generic.rb")).lines.map(&:chomp)
        end

        it "#create_sanbox creates a generic.rb" do
          provisioner.create_sandbox

          sandbox_path("generic.rb").file?.must_equal true
        end

        describe "defaults" do

          before { provisioner.create_sandbox }

          it "sets node_name to the instance name" do
            file.must_include %{node_name "#{instance.name}"}
          end

          it "sets checksum_path" do
            file.must_include %{checksum_path "/tmp/kitchen/checksums"}
          end

          it "sets file_backup_path" do
            file.must_include %{file_backup_path "/tmp/kitchen/backup"}
          end

          it "sets cookbook_path" do
            file.must_include %{cookbook_path } +
              %{["/tmp/kitchen/cookbooks", "/tmp/kitchen/site-cookbooks"]}
          end

          it "sets data_bag_path" do
            file.must_include %{data_bag_path "/tmp/kitchen/data_bags"}
          end

          it "sets environment_path" do
            file.must_include %{environment_path "/tmp/kitchen/environments"}
          end

          it "sets node_path" do
            file.must_include %{node_path "/tmp/kitchen/nodes"}
          end

          it "sets role_path" do
            file.must_include %{role_path "/tmp/kitchen/roles"}
          end

          it "sets client_path" do
            file.must_include %{client_path "/tmp/kitchen/clients"}
          end

          it "sets user_path" do
            file.must_include %{user_path "/tmp/kitchen/users"}
          end

          it "sets validation_key" do
            file.must_include %{validation_key "/tmp/kitchen/validation.pem"}
          end

          it "sets client_key" do
            file.must_include %{client_key "/tmp/kitchen/client.pem"}
          end

          it "sets chef_server_url" do
            file.must_include %{chef_server_url "http://127.0.0.1:8889"}
          end

          it "sets encrypted_data_bag_secret" do
            file.must_include %{encrypted_data_bag_secret } +
              %{"/tmp/kitchen/encrypted_data_bag_secret"}
          end
        end

        it "supports overwriting defaults" do
          config[:generic_rb] = {
            :node_name => "eagles",
            :user_path => "/a/b/c/u",
            :chef_server_url => "https://whereever.io"
          }
          provisioner.create_sandbox

          file.must_include %{node_name "eagles"}
          file.must_include %{user_path "/a/b/c/u"}
          file.must_include %{chef_server_url "https://whereever.io"}
        end

        it " supports adding new configuration" do
          config[:generic_rb] = {
            :dark_secret => "golang"
          }
          provisioner.create_sandbox

          file.must_include %{dark_secret "golang"}
        end
      end

      def create_cookbook(path)
        %w[metadata.rb attributes/all.rb recipes/default.rb].each do |file|
          create_file(File.join(path, file))
        end
      end

      def full_cookbook_files
        %w[
          README.org metadata.rb attributes/all.rb definitions/def.rb
          files/default/config.conf libraries/one.rb libraries/two.rb
          providers/sweet.rb recipes/default.rb resources/sweet.rb
          templates/ubuntu/12.04/nginx.conf.erb
        ]
      end

      def create_full_cookbook(path)
        full_cookbook_files.each { |file| create_file(File.join(path, file)) }
      end

      def create_file(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, "wb") { |f| f.write(path) }
      end
    end

    def sandbox_path(path)
      Pathname.new(provisioner.sandbox_path).join(path)
    end

    def create_files_under(path)
      FileUtils.mkdir_p(File.join(path, "sub"))
      File.open(File.join(path, "alpha.txt"), "wb") do |file|
        file.write("stuff")
      end
      File.open(File.join(path, "sub", "bravo.txt"), "wb") do |file|
        file.write("junk")
      end
    end

    def info_line(msg)
      %r{^I, .* : #{Regexp.escape(msg)}$}
    end

    def debug_line(msg)
      %r{^D, .* : #{Regexp.escape(msg)}$}
    end
  end

  def regexify(str, line = :whole_line)
    r = Regexp.escape(str)
    r = "^\s*#{r}$" if line == :whole_line
    Regexp.new(r)
  end
end
