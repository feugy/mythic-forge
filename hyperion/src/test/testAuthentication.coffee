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

server = require '../main/web/server'
Player = require '../main/model/Player'
utils = require '../main/utils'
request = require 'request'
parseUrl = require('url').parse
assert = require('chai').assert

port = utils.confKey 'server.apiPort'
rootUrl = "http://localhost:#{port}"
googleEmail = "mythic.forge.test@gmail.com"
googlePassword = "toto1818"

describe 'Authentication tests', ->

  before (done) ->
    Player.collection.drop ->
      server.listen port, 'localhost', done

  after (done) ->
    server.close()
    done()

  describe 'given a started server', ->

    token = null

    it 'should Google user be enrolled', (done) ->
      this.timeout 5000

      # when requesting the google authentication page
      request "#{rootUrl}/auth/google", (err, res, body) ->
        throw new Error err if err?
        # then the google authentication page is displayed
        assert.equal 'accounts.google.com', res.request.uri.host, "Wrong host: #{res.request.uri.host}"
        assert.ok -1 != body.indexOf('id="Email"'), 'No email found in response'
        assert.ok -1 != body.indexOf('id="Passwd"'), 'No password found in response'

        # forge form to log-in
        form = 
          Email: googleEmail
          GALX: body.match(/name\s*=\s*"GALX"\s+value\s*=\s*"([^"]*)"/)[1]
          Passwd: googlePassword
          checkConnection: 'youtube:248:1'
          checkedDomains: 'youtube'
          continue: body.match(/id\s*=\s*"continue"\s+value\s*=\s*"([^"]*)"/)[1]
          pstMsg: 1
          scc: 1
          service: 'lso'

        # when registering with test account
        request 
          uri: 'https://accounts.google.com/ServiceLoginAuth'
          method: 'POST'
          form: form
        , (err, res, body) ->
          throw new Error err if err?

          # manually follw redirection
          redirect = body.match(/window.__CONTINUE_URL\s*=\s*'([^']*)'/)[1].replace(/\\x2F/g, '/').replace(/\\x26amp%3B/g, '&')
          request redirect, (err, res, body) ->
            throw new Error err if err?

            # accepts to give access to account informations
            request 
              uri: body.match(/<form action="([^"]*)"/)[1].replace(/&amp;/g, '&')
              method: 'POST'
              followAllRedirects: true
              form: 
                state_wrapper: body.match(/name\s*=\s*"state_wrapper"\s+value\s*=\s*"([^"]*)"/)[1]
                submit_access: true

            , (err, res, body) ->
              throw new Error err if err?

              # then the success page is displayed
              assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
              token = parseUrl(res.request.uri.href).query.replace 'token=', ''
              assert.isNotNull token
              # then account has been created and populated
              Player.findOne {email:googleEmail}, (err, saved) ->
                throw new Error "Failed to find created account in db: #{err}" if err?
                assert.equal saved.firstName, 'John'
                assert.equal saved.lastName, 'Doe'
                assert.equal saved.token, token
                done()     

    it 'should existing logged-in Google user be immediately authenticated', (done) ->

      # when requesting the google authentication page while a google user is already logged-in
      request "#{rootUrl}/auth/google", (err, res, body) ->
        throw new Error err if err?
        # then the success page is displayed
        assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
        token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
        assert.isNotNull token2
        assert.notEqual token2, token
        token = token2
        # then account has been updated with new token
        Player.findOne {email:googleEmail}, (err, saved) ->
          throw new Error "Failed to find created account in db: #{err}" if err?
          assert.equal saved.token, token2
          done()    

    it 'should existing Google user be authenticated after log-in', (done) ->
      this.timeout 5000

      # given an existing but not logged in Google account
      request "https://code.google.com/apis/console/logout", (err, res, body) ->
        throw new Error err if err?

        # when requesting the google authentication page
        request "#{rootUrl}/auth/google", (err, res, body) ->
          throw new Error err if err?
          # then the google authentication page is displayed
          assert.equal 'accounts.google.com', res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          assert.ok -1 != body.indexOf('id="Email"'), 'No email found in response'
          assert.ok -1 != body.indexOf('id="Passwd"'), 'No password found in response'

          # forge form to log-in
          form = 
            Email: googleEmail
            GALX: body.match(/name\s*=\s*"GALX"\s+value\s*=\s*"([^"]*)"/)[1]
            Passwd: googlePassword
            checkConnection: 'youtube:248:1'
            checkedDomains: 'youtube'
            continue: body.match(/id\s*=\s*"continue"\s+value\s*=\s*"([^"]*)"/)[1]
            pstMsg: 1
            scc: 1
            service: 'lso'

          # when registering with test account
          request 
            uri: 'https://accounts.google.com/ServiceLoginAuth'
            method: 'POST'
            form: form
          , (err, res, body) ->
            throw new Error err if err?

            # manually follw redirection
            redirect = body.match(/window.__CONTINUE_URL\s*=\s*'([^']*)'/)[1].replace(/\\x2F/g, '/').replace(/\\x26amp%3B/g, '&')
            request redirect, (err, res, body) ->
              throw new Error err if err?

              # then the success page is displayed
              assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
              token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
              assert.isNotNull token2
              assert.notEqual token2, token
              # then account has been updated with new token
              Player.findOne {email:googleEmail}, (err, saved) ->
                throw new Error "Failed to find created account in db: #{err}" if err?
                assert.equal saved.token, token2
                done()      