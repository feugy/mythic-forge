###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

async = require 'async'
pathUtils = require 'path'
fs = require 'fs-extra'
FSItem = require '../src/model/FSItem'
utils = require '../src/utils'
util = require 'util'
server = require '../src/web/proxy'
Browser = require 'zombie'
assert = require('chai').assert
service = require('../src/service/AuthoringService').get()

port = utils.confKey 'server.staticPort'
rootUrl = "http://localhost:#{port}"
root = utils.confKey 'game.dev'

describe 'Optimization tests', -> 

  beforeEach (done) ->
    # given a clean game source
    fs.remove root, ->
      fs.mkdir root, (err) ->
        throw new Error err if err?
        # and a valid game client in it
        fs.copy './hyperion/test/fixtures/working-client', root, (err) ->
          throw new Error err if err?
          done()

  it 'should coffee compilation errors be reported', (done) ->
    # given a non-compiling coffee script
    fs.copy './hyperion/test/fixtures/Router.coffee.error', pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
      throw new Error err if err?

      # when optimizing the game client
      service.optimize (err) ->
        # then an error is reported
        assert.isNotNull err
        assert.include err, "Parse error on line 50: Unexpected 'STRING'", "Unexpected error: #{err}"
        done()
  
  it 'should stylus compilation errors be reported', (done) ->
    # given a non-compiling stylus sheet
    fs.copy './hyperion/test/fixtures/rheia.styl.error', pathUtils.join(root, 'style', 'rheia.styl'), (err) ->
      throw new Error err if err?

      # when optimizing the game client
      service.optimize (err) ->
        # then an error is reported
        assert.isNotNull err
        assert.include err, "@import 'unexisting'", "Unexpected error: #{err}"
        done()

  it 'should no main html file be detected', (done) ->
    # given no main file
    fs.remove pathUtils.join(root, 'index.html'), (err) ->
      throw new Error err if err?

      # when optimizing the game client
      service.optimize (err) ->
        # then an error is reported
        assert.isNotNull err
        assert.include err, 'no html page including requirej found', "Unexpected error: #{err}"
        done()

  it 'should main html file without requirejs be detected', (done) ->
    # given a main file without requirejs
    fs.copy './hyperion/test/fixtures/index.html.norequire', pathUtils.join(root, 'index.html'), (err) ->
      throw new Error err if err?

      # when optimizing the game client
      service.optimize (err) ->
        # then an error is reported
        assert.isNotNull err
        assert.include err, 'no html page including requirej found', "Unexpected error: #{err}"
        done()

  it 'should no requirejs configuration be detected', (done) ->
    # given a requirejs entry file without configuration
    fs.copy './hyperion/test/fixtures/Router.js.noconfigjs', pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
      throw new Error err if err?

      # when optimizing the game client
      service.optimize (err) ->
        # then an error is reported
        assert.isNotNull err
        assert.include err, 'no requirejs configuration file found', "Unexpected error: #{err}"
        done()

  it 'should requirejs optimization error be detected', (done) ->

    # given a requirejs entry file without error
    fs.copy './hyperion/test/fixtures/Router.coffee.requirejserror', pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
      throw new Error err if err?

      # when optimizing the game client
      service.optimize (err) ->
        # then an error is reported
        assert.isNotNull err
        assert.include err, 'optimized.out\\js\\backbone.js', "Unexpected error: #{err}"
        done()

  describe 'given a started static server', ->

    before (done) ->
      server.listen port, 'localhost', done
      
    after (done) ->
      server.close()
      done()

    it 'should file be correctly compiled and optimized', (done) ->
      @timeout 20000

      # when optimizing the game client
      service.optimize (err) ->
        throw new Error "Failed to optimize valid client: #{err}" if err?
        # then the client was optimized
        browser = new Browser silent: true
        browser.visit("#{rootUrl}/game").then( ->
          # then the resultant url is working, with template rendering and i18n usage
          body = browser.body.textContent.trim()
          assert.equal body, 'Edition du monde'
          done()
        ).fail done