'use strict'

requirejs.onError = (err) ->
  $('body').empty "requireJS error #{err}"
  throw err

requirejs.config  
  config:
    i18n:
      locale: 'fr'

  paths:
    'backbone': 'lib/backbone-0.9.2-min'
    'underscore': 'lib/underscore-1.3.3-min'
    'underscore.string': 'lib/unserscore.string-2.2.0rc-min'
    'jquery': 'lib/jquery-1.7.2-min'
    'hogan': 'lib/hogan-2.0.0-min'
    'i18n': 'lib/i18n'
    'text': 'lib/text'
    'nls': '../nls'
    'tpl': '../templates'
    
  shim:
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'underscore': 
      exports: '_'
    'hogan':
      exports: 'Hogan'
    'jquery': 
      exports: '$'

window.rheia = {}

define [
  'underscore'
  'jquery' 
  'backbone'
  'i18n!nls/common'
  'utils/utilities'
  'text!tpl/login.html'
  'utils/extensions'
], (_, $, Backbone, i18n, utils, template) ->

  class Router extends Backbone.Router

    constructor: ->

      super()
      rheia.router = @

      @route '*route', '_showTemplate'

      Backbone.history.start
        pushState: true
        root: conf.basePath

    _showTemplate: =>
      $('body').append(template).find('h1').html i18n.titles.editionPerspective

  new Router()