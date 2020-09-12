// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.

require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()
require("channels")
require.context('../images', true)

import 'stylesheets/application'

document.addEventListener('turbolinks:load', function () {
  let notification = document.querySelector('.alert')

  if (notification) {
    setTimeout(function () {
      document.querySelector('.alert').classList.add('hidden')
    }, 3000)
  }
})
