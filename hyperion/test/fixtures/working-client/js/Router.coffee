'use strict'

requirejs.config  
  config:
    i18n:
      locale: 'fr'

  paths:
    'backbone': 'lib/backbone-0.9.2-min'
    'underscore': 'lib/underscore-1.3.3-min'
    'underscore.string': 'lib/unserscore.string-2.2.0rc-min'
    'jquery': 'lib/jquery-1.7.2-min'
    'jquery-ui': 'lib/jquery-ui-1.8.21-min'
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
    'jquery-ui':
      deps: ['jquery']
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
  'jquery-ui' 
  ], (_, $, Backbone, i18n, utils, template) ->

  class Router extends Backbone.Router

    constructor: ->

      super()
      rheia.router = @

      @route '*route', '_showTemplate'

      $('body').empty()

      Backbone.history.start
        pushState: true
        root: conf.basePath

    _showTemplate: =>
      $('body').empty().append(template).find('h1').html i18n.titles.editionPerspective

  new Router()