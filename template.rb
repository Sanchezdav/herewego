=begin
Template Name: Herewego Rails Template
Author: David Sanchez
Author URI: https://codeando.dev
Instructions: $ rails new myapp -d <postgresql, mysql, sqlite> -m template.rb
=end

require "fileutils"
require "shellwords"

# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("herewego-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/Sanchezdav/herewego.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{herewego/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def rails_version
  @rails_version ||= Gem::Version.new(Rails::VERSION::STRING)
end

def rails_5?
  Gem::Requirement.new(">= 5.2.0", "< 6.0.0.beta1").satisfied_by? rails_version
end

def rails_6?
  Gem::Requirement.new(">= 6.0.0.beta1", "< 7").satisfied_by? rails_version
end

def add_gems
  gem 'administrate', git: 'https://github.com/thoughtbot/administrate.git'
  gem 'devise', '~> 4.7', '>= 4.7.1'
  gem 'friendly_id', '~> 5.2', '>= 5.2.5'
  gem 'name_of_person', '~> 1.1'
  gem 'gravatar_image_tag', github: 'mdeering/gravatar_image_tag'
end

def set_application_name
  environment "config.application_name = Rails.application.class.module_parent_name"

  puts "You can change application name inside: ./config/application.rb"
end

def add_users
  # Install Devise
  generate "devise:install"

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  content = <<-CODE

    unauthenticated :user do
      devise_scope :user do
        root to: 'unauthenticated#index', as: :unauthenticated_root
      end
    end

    authenticated :user do
      root to: 'home#index', as: :authenticated_root
    end
  CODE

  # Generate Devise views via Bootstrap	
  generate "devise:views"

   # Create Devise User
  generate :devise, "User",
           "first_name",
           "last_name",
           "admin:boolean"

  insert_into_file 'config/routes.rb', content + "\n", after: "Rails.application.routes.draw do"

  # Set admin default to false
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end

  if Gem::Requirement.new("> 5.2").satisfied_by? rails_version
    gsub_file "config/initializers/devise.rb",
      /  # config.secret_key = .+/,
      "  config.secret_key = Rails.application.credentials.secret_key_base"
  end
end

def add_fontawesome
  run "yarn add @fortawesome/fontawesome-free"
end

def add_tailwindcss
  run "yarn add tailwindcss"

  content = <<-JS
    require('tailwindcss'),
    require('autoprefixer'),
  JS

  insert_into_file './postcss.config.js', content, before: "require('postcss-import'),"
end

def copy_templates
  remove_file "app/assets/stylesheets/application.css"

  copy_file "Procfile.dev"
  copy_file ".foreman"

  directory "app", force: true
  directory "lib", force: true
end

def add_administrate
  generate "administrate:install"

  gsub_file "app/controllers/admin/application_controller.rb",
    /# TODO Add authentication logic here\./,
    "redirect_to '/', alert: 'Not authorized.' unless user_signed_in? && current_user.admin?"

  environment do <<-RUBY

    # Expose our application's helpers to Administrate
    config.to_prepare do
      Administrate::ApplicationController.helper #{@app_name.camelize}::Application.helpers
    end
  RUBY

  end
end

def add_friendly_id
  generate "friendly_id"

  insert_into_file(
    Dir["db/migrate/**/*friendly_id_slugs.rb"].first,
    "[5.2]",
    after: "ActiveRecord::Migration"
  )
end

def stop_spring
  run "spring stop"
end

# Main setup
add_template_repository_to_source_path

add_gems

after_bundle do
  set_application_name
  stop_spring
  add_users
  add_fontawesome
  add_tailwindcss
  add_friendly_id

  copy_templates

  # Migrate
  rails_command "db:create"
  rails_command "db:migrate"

  # Migrations must be done before this
  add_administrate

  # Commit everything to git
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }

  say
  say "Herewego!", :green
  say
  say "To get started with your new app:", :green
  say "cd #{app_name} - Switch to your new app's directory."
  say "foreman start - Run Rails and webpack-dev-server."
end
