# Herewego Rails Template

Rails starter pack

Thanks to [Chris Oliver](https://twitter.com/excid3/) and [Jumpstart](https://github.com/excid3/jumpstart) for inpiring me to create this, credits to him.

**Note:** Requires Rails 5.2 or higher

## Getting Started

Herewego is a Rails template to start an application quickly with an extra punch.

#### Requirements

You'll need the following installed to run the template successfully:

* Ruby 2.5 or higher
* bundler - `gem install bundler`
* rails - `gem install rails`
* Yarn - `brew install yarn` or [Install Yarn](https://yarnpkg.com/en/docs/install)
* Foreman (optional) - `gem install foreman` - helps run all your
  processes in development

#### Creating a new app

```bash
rails new myapp -d postgresql -m https://raw.githubusercontent.com/Sanchezdav/herewego/master/template.rb
```

Or if you have downloaded this repo, you can reference template.rb locally:

```bash
rails new myapp -d postgresql -m template.rb
```

To run your app, use `foreman start`.

This will run `Procfile.dev` via `foreman start -f Procfile.dev` as configured by the `.foreman` file and will launch the development processes `rails server` and `webpack-dev-server` processes. You can also run them in separate terminals manually if you prefer.
