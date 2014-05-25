'use strict'

requirejs.onError = (err) -> throw err

requirejs.config  
  paths:
    'async': 'async-0.2.10'
    'chai': 'chai-1.9.0'
    'backbone': 'backbone-1.0.0-min'
    'jquery': 'jquery-2.1.0-min'
    'mocha': 'mocha-1.17.1'
    'socket.io': 'socket.io-1.0.0-pre2'
    'underscore': 'underscore-1.5.2-min'
    'underscore.string': 'underscore.string-2.3.3-min'
    
  shim:
    'async':
      exports: 'async'
    'atlas':
      deps: ['jquery', 'underscore']
      exports: 'factory'
    'chai':
      exports: 'chai'
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'jquery': 
      exports: '$'
    'mocha':
      exports: 'mocha'
    'underscore': 
      exports: '_'
      
require [
  'require'
  'mocha'
  'async'
  'socket.io'
], (require, mocha, async, io) ->

  mocha.setup ui:'bdd'
  window.async = async
  window.io = io

  # now require tests
  require [
   'test/atlas'
  ], -> 
    mocha.run ->
      # parse results
      results = []
      $('.test').each ->
        elem = $(@)
        suites = []
        elem.parents('.suite').find('> h1').each ->
          suites.push "#{$(@).text()}, "
        results.push
          name: "#{suites.join ''} #{elem.find('> h2').clone().children().remove().end().text()}"
          state: elem.attr('class').replace('test ', '').split(' ') or []
          error: elem.find('.error').text()

      $('body').append("<div id='mocha-results'>#{JSON.stringify results}</div>")