'use strict'

requirejs.onError = (err) -> throw err

requirejs.config  
  paths:
    'async': 'async-0.2.7-min'
    'chai': 'chai-1.5.0'
    'backbone': 'backbone-1.0.0-min'
    'jquery': 'jquery-2.0.0-min'
    'mocha': 'mocha-1.9.0'
    'socket.io': 'socket.io-0.9.10'
    'underscore': 'underscore-1.4.4-min'
    'underscore.string': 'underscore.string-2.3.0-min'
    
  shim:
    'async':
      exports: 'async'
    'atlas':
      deps: ['async', 'jquery', 'socket.io', 'underscore']
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
    'socket.io':
      exports: 'io'
    'underscore': 
      exports: '_'
      
require [
  'require'
  'mocha'
  'async'
], (require, mocha, async) ->

  mocha.setup ui:'bdd', bail:true
  window.async = async
  
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