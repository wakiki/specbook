require "rails/generators"

module Specbook
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install Specbook: copies an initializer and prints next steps."

      def copy_initializer
        template "specbook.rb", "config/initializers/specbook.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
