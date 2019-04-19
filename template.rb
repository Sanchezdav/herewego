=begin
Template Name: Herewego Rails Template
Author: David Sanchez
Author URI: https://code-ando.com/
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
  gem 'administrate', '~> 0.11.0'
  gem 'bootstrap', '~> 4.3', '>= 4.3.1'
  gem 'devise', '~> 4.6', '>= 4.6.2'
  gem 'devise-bootstrapped', github: 'king601/devise-bootstrapped', branch: 'bootstrap4'
  gem 'font-awesome-sass', '~> 5.8', '>= 5.8.1'
  gem 'friendly_id', '~> 5.2', '>= 5.2.5'
  gem 'name_of_person', '~> 1.1'

  if rails_5?
    gsub_file "Gemfile", /gem 'sqlite3'/, "gem 'sqlite3', '~> 1.3.0'"
    gem 'webpacker', '~> 4.0.1'
  end
end

def set_application_name
  if rails_5?
    environment "config.application_name = Rails.application.class.parent_name"
  else
    environment "config.application_name = Rails.application.class.module_parent_name"
  end

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
        root to: 'unauthenticated#index'
      end
    end

    authenticated :user do
      root 'home#index'
    end
  CODE

  # Generate Devise views via Bootstrap
  generate "devise:views:bootstrapped"

   # Create Devise User
  generate :devise, "User",
           "first_name",
           "last_name",
           "admin:boolean"

  insert_into_file 'config/routes.rb', content + "\n", before: "# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html"

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

def add_webpack
  # Rails 6+ comes with webpacker by default, so we can skip this step
  return if rails_6?

  # Our application layout already includes the javascript_pack_tag,
  # so we don't need to inject it
  rails_command 'webpacker:install'
end

def add_javascript
  run "yarn add expose-loader jquery popper.js bootstrap data-confirm-modal local-time"

  if rails_5?
    run "yarn add turbolinks @rails/actioncable@pre @rails/actiontext@pre @rails/activestorage@pre @rails/ujs@pre"
  end

  content = <<-JS
    const webpack = require('webpack')
    environment.plugins.append('Provide', new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
      Rails: '@rails/ujs'
    }))
  JS

  insert_into_file 'config/webpack/environment.js', content + "\n", before: "module.exports = environment"
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

  gsub_file "app/dashboards/user_dashboard.rb",
    /email: Field::String/,
    "email: Field::String,\n    password: Field::String.with_options(searchable: false)"

  gsub_file "app/dashboards/user_dashboard.rb",
    /FORM_ATTRIBUTES = \[/,
    "FORM_ATTRIBUTES = [\n    :password,"

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
  add_webpack
  add_javascript
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
  say "Herewego!", :blue
  say
  say "To get started with your new app:", :green
  say "cd #{app_name} - Switch to your new app's directory."
  say "foreman start - Run Rails and webpack-dev-server."
end
