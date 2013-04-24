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

_ = require 'underscore'
fs = require 'fs-extra'
moment = require 'moment'
{join, resolve} = require 'path'
Phantom = require 'phantom-proxy'
utils = require '../hyperion/src/util/common'
front = require '../hyperion/src/web/front'
middle = require '../hyperion/src/web/middle'
utils = require '../hyperion/src/util/common'

port = utils.confKey 'server.apiPort'
rootUrl = "http://localhost:#{port}"
root = utils.confKey 'game.dev'

describe 'Atlas browser tests', ->

  results = {}

  before (done) ->
    @timeout 30000
    # given test fixtures
    fs.copy join(__dirname, 'fixtures', 'atlas-client'), root, (err) ->
      return done "Failed to init atlas client: #{err}" if err?
      fs.copy resolve(__dirname, '..', 'atlas', 'atlas.coffee'), join(root, 'js', 'atlas.coffee'), (err) ->
        return done "Failed to copy atlas library: #{err}" if err?
        # given a started server
        front middle.app
        middle.server.listen port, 'localhost', (err) ->
          return done "Failed to start server: #{err}" if err

          Phantom.create {debug:false}, (proxy) ->
            browser = proxy.page

            browser.on 'error', (err, stack)->
              return done "#{err}\n#{_.map(stack, (s) -> "#{s.file}:#{s.line}").join '\n'}"
            browser.on 'consoleMessage', (message) -> console.log message

            browser.open "#{rootUrl}/dev/", ->
              browser.waitForSelector '#mocha-results', -> 
                browser.evaluate ->
                  $('#mocha-results').text()
                , (serialized) ->
                  results = JSON.parse serialized
                  done()

  after (done) ->
    middle.server.close()
    Phantom.end -> done() 

  it 'should tests all passed', (done) ->
    for test in results
      return done "#{test.name} failed: #{test.error}" if 'fail' in test.state
    done()