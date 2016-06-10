###
  Copyright 2010~2014 Damien Feugas

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

_ = require 'lodash'
middle = require '../hyperion/src/web/middle'
front = require '../hyperion/src/web/front'
Player = require '../hyperion/src/model/Player'
utils = require '../hyperion/src/util/common'
request = require('request').defaults jar:true
parseUrl = require('url').parse
{expect} = require 'chai'

port = utils.confKey 'server.apiPort'
staticPort = utils.confKey 'server.staticPort'
rootUrl = "http://localhost:#{port}"

describe 'Authentication tests', ->

  before (done) ->
    Player.remove {}, (err)->
      front middle.app
      middle.server.listen port, 'localhost', done

  # Restore admin player for further tests
  after (done) ->
    middle.server.close()
    new Player(email:'admin', password: 'admin', isAdmin:true).save done

  describe 'given a started server', ->

    token = null
    lastConnection = null

    describe 'given a Twitter account', ->

      twitterUser = "MythicForgeTest"
      twitterPassword = "toto1818"

      it 'should Twitter user be enrolled', (done) ->
        @timeout 20000

        # when requesting the twitter authentication page
        request "#{rootUrl}/auth/twitter", (err, res, body) ->
          return done err if err?
          # then the twitter authentication page is displayed
          expect(res).to.have.deep.property('request.uri.host').that.equal 'api.twitter.com'
          expect(body, 'No email found in response').to.include 'id="username_or_email"'
          expect(body, 'No password found in response').to.include 'id="password"'

          # forge form to log-in
          form =
            'session[username_or_email]': twitterUser
            'session[password]': twitterPassword
            authenticity_token: body.match(/name\s*=\s*"authenticity_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
            oauth_token: body.match(/name\s*=\s*"oauth_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]

          # when registering with test account
          request
            uri: 'https://api.twitter.com/oauth/authenticate'
            method: 'POST'
            form: form
          , (err, res, body) ->
            return done err if err?

            # manually follows redirection to localhost
            redirect = body.match(/\s+href\s*=\s*"(http:\/\/localhost:[^"]*oauth_token=[^"]*)">/)[1]
            request redirect, (err, res, body) ->
              return done err if err?

              # then the success page is displayed
              expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
              token = parseUrl(res.request.uri.href).query.replace 'token=', ''
              expect(token).to.exist
              # then account has been created and populated
              Player.findOne {email:twitterUser}, (err, saved) ->
                return done "Failed to find created account in db: #{err}" if err? or !saved?
                expect(saved).to.have.property('firstName').that.equal 'Bauer'
                expect(saved).to.have.property('lastName').that.equal 'Jack'
                expect(saved).to.have.property('token').that.equal token
                expect(saved).to.have.property 'lastConnection'
                lastConnection = saved.lastConnection
                done()

      it 'should existing logged-in Twitter user be immediately authenticated', (done) ->
        @timeout 10000

        # when requesting the twitter authentication page while a twitter user is already logged-in
        request "#{rootUrl}/auth/twitter", (err, res, body) ->
          return done "Failed to be redirected on twitter page: #{err}" if err?
          # then the twitter temporary page is displayed
          expect(res).to.have.deep.property('request.uri.host').that.equal 'api.twitter.com'
          expect(body, "Twitter user is not logged-in").to.include 'auth/twitter/callback?oauth_token'

          # manually follow redirection to localhost
          redirect = body.match(/\s+href\s*=\s*"(http:\/\/localhost:[^"]*oauth_token=[^"]*)">/)[1]
          request redirect, (err, res, body) ->
            return done "Failed to be redirected on localhost target page: #{err}" if err?

            # then the success page is displayed
            expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
            token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
            expect(token2).to.exist
            expect(token2).not.to.equal token
            token = token2
            # then account has been updated with new token
            Player.findOne {email:twitterUser}, (err, saved) ->
              return done "Failed to find created account in db: #{err}" if err?
              expect(saved).to.have.property('token').that.equal token2
              expect(saved).to.have.property 'lastConnection'
              expect(lastConnection.getTime()).not.to.equal saved.lastConnection.getTime()
              done()

      it 'should existing Twitter user be authenticated after log-in', (done) ->
        @timeout 20000

        # given an existing but not logged in Twitter account
        request 'http://twitter.com/logout', (err, res, body) ->
          return done err if err?

          request
            uri: 'https://twitter.com/logout'
            method: 'POST'
            form:
              authenticity_token: body.match(/value\s*=\s*"([^"]*)"\s+name\s*=\s*"authenticity_token"/)[1]
          , (err, res, body) ->
            return done err if err?

            # when requesting the twitter authentication page
            request "#{rootUrl}/auth/twitter", (err, res, body) ->
              return done err if err?
              # then the twitter authentication page is displayed
              expect(res).to.have.deep.property('request.uri.host').that.equal 'api.twitter.com'
              expect(body, 'No email found in response').to.include 'id="username_or_email"'
              expect(body, 'No password found in response').to.include 'id="password"'

              # forge form to log-in
              form =
                'session[username_or_email]': twitterUser
                'session[password]': twitterPassword
                authenticity_token: body.match(/name\s*=\s*"authenticity_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
                oauth_token: body.match(/name\s*=\s*"oauth_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
                forge_login: 1

              # when registering with test account
              request
                uri: 'https://api.twitter.com/oauth/authenticate'
                method: 'POST'
                form: form
              , (err, res, body) ->
                return done err if err?

                # manually follw redirection
                redirect = body.match(/\s+href\s*=\s*"(http:\/\/localhost:[^"]*oauth_token=[^"]*)">/)[1]
                request redirect, (err, res, body) ->
                  return done err if err?

                  # then the success page is displayed
                  expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
                  token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
                  expect(token2).to.exist
                  expect(token2).not.to.equal token
                  # then account has been updated with new token
                  Player.findOne {email:twitterUser}, (err, saved) ->
                    return done "Failed to find created account in db: #{err}" if err?
                    expect(saved).to.have.property('token').that.equal token2
                    expect(saved).to.have.property 'lastConnection'
                    expect(lastConnection.getTime()).not.to.equal saved.lastConnection.getTime()
                    done()

    # Do not test on Travis, because Google get's mad on VM's Ip
    unless process.env.TRAVIS
      describe 'given a Google account', ->

        googleUser = "mythic.forge.test@gmail.com"
        googlePassword = "toto1818"

        it 'should Google user be enrolled', (done) ->
          @timeout 20000

          # when requesting the google authentication page
          request "#{rootUrl}/auth/google", (err, res, body) ->
            return done err if err?

            # then the google authentication page is displayed
            expect(res).to.have.deep.property('request.uri.host').that.equal 'accounts.google.com'
            expect(body, 'No email found in response').to.include 'id="Email'
            expect(body, 'No password found in response').to.include 'id="Passwd'

            # forge form to enter email
            form =
              Email: googleUser
              Passwd: googlePassword
              GALX: body.match(/name\s*=\s*"GALX"\s+value\s*=\s*"([^"]*)"/)[1]
              gxf: body.match(/name\s*=\s*"gxf"\s+value\s*=\s*"([^"]*)"/)[1]
              checkConnection: 'youtube:248:1'
              checkedDomains: 'youtube'
              continue: body.match(/name\s*=\s*"continue"\s+value\s*=\s*"([^"]*)"/)[1]
              pstMsg: 1
              scc: 1
              service: 'lso'

            # when registering with test account
            request
              uri: 'https://accounts.google.com/ServiceLoginAuth'
              method: 'POST'
              form: form
            , (err, res, body) ->
              return done err if err?

              # manually follows redirection
              return done "Failed to login with google account because Google want your phone !" if -1 is body.indexOf 'window.__CONTINUE_URL'
              redirect = body.match(/window.__CONTINUE_URL\s*=\s*'([^']*)'/)[1].replace(/\\x2F/g, '/').replace(/\\x26amp%3B/g, '&')

              request redirect, (err, res, body) ->
                return done err if err?

                # accepts to give access to account informations
                request
                  uri: body.match(/<form\s+.*action="([^"]*)"/)[1].replace(/&amp;/g, '&')
                  method: 'POST'
                  followAllRedirects: true
                  form:
                    _utf8: body.match(/name\s*=\s*"_utf8"\s+value\s*=\s*"([^"]*)"/)[1]
                    state_wrapper: body.match(/name\s*=\s*"state_wrapper"\s+value\s*=\s*"([^"]*)"/)[1]
                    submit_access: true

                , (err, res, body) ->
                  return done err if err?

                  # then the success page is displayed
                  expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
                  token = parseUrl(res.request.uri.href).query.replace 'token=', ''
                  expect(token).to.exist

                  # then account has been created and populated
                  Player.findOne {email:googleUser}, (err, saved) ->
                    return done "Failed to find created account in db: #{err}" if err? or saved is null
                    expect(saved).to.have.property('firstName').that.equal 'John'
                    expect(saved).to.have.property('lastName').that.equal 'Doe'
                    expect(saved).to.have.property('token').that.equal token
                    expect(saved).to.have.property 'lastConnection'
                    lastConnection = saved.lastConnection
                    done()

        it 'should existing logged-in Google user be immediately authenticated', (done) ->
          @timeout 10000
          # give Google some time to update its state before retrying
          _.delay ->
            # when requesting the google authentication page while a google user is already logged-in
            request "#{rootUrl}/auth/google", (err, res, body) ->
              return done err if err?
              # then the success page is displayed
              expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
              expect(JSON.stringify(body), "Wrong credentials during authentication").not.to.include 'Invalid Credentials'
              token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
              expect(token2).to.exist
              expect(token2).not.to.equal token
              token = token2
              # then account has been updated with new token
              Player.findOne {email:googleUser}, (err, saved) ->
                return done "Failed to find created account in db: #{err}" if err?
                expect(saved).to.have.property('token').that.equal token2
                expect(saved).to.have.property 'lastConnection'
                expect(lastConnection.getTime()).not.to.equal saved.lastConnection.getTime()
                done()
          , 500

        it 'should existing Google user be authenticated after log-in', (done) ->
          @timeout 20000

          # given an existing but not logged in Google account
          request "https://accounts.google.com/Logout?service=cloudconsole", (err, res, body) ->
            return done err if err?

            # when requesting the google authentication page
            request "#{rootUrl}/auth/google", (err, res, body) ->
              return done err if err?
              # then the google authentication page is displayed
              expect(res).to.have.deep.property('request.uri.host').that.equal 'accounts.google.com'
              expect(body, 'No email found in response').to.include 'id="Email'
              expect(body, 'No password found in response').to.include 'id="Passwd'

              # forge form to log-in
              form =
                Email: googleUser
                Passwd: googlePassword
                GALX: body.match(/name\s*=\s*"GALX"\s+value\s*=\s*"([^"]*)"/)[1]
                gxf: body.match(/name\s*=\s*"gxf"\s+value\s*=\s*"([^"]*)"/)[1]
                checkConnection: 'youtube:248:1'
                checkedDomains: 'youtube'
                continue: body.match(/name\s*=\s*"continue"\s+value\s*=\s*"([^"]*)"/)[1]
                pstMsg: 1
                scc: 1
                service: 'lso'

              # when registering with test account
              request
                uri: 'https://accounts.google.com/ServiceLoginAuth'
                method: 'POST'
                form: form
              , (err, res, body) ->
                return done err if err?

                # manually follw redirection
                redirect = body.match(/window.__CONTINUE_URL\s*=\s*'([^']*)'/)[1].replace(/\\x2F/g, '/').replace(/\\x26amp%3B/g, '&')
                request redirect, (err, res, body) ->
                  return done err if err?

                  # then the success page is displayed
                  expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
                  token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
                  expect(token2).to.exist
                  expect(token2).not.to.equal token
                  # then account has been updated with new token
                  Player.findOne {email:googleUser}, (err, saved) ->
                    return done "Failed to find created account in db: #{err}" if err?
                    expect(saved).to.have.property('token').that.equal token2
                    expect(saved).to.have.property 'lastConnection'
                    expect(lastConnection.getTime()).not.to.equal saved.lastConnection.getTime()
                    done()

    describe 'given a Github account', ->

      githubUser = 'mythic.forge.test@gmail.com'
      githubPassword = 'toto1818'

      it 'should Github user be enrolled', (done) ->
        @timeout 20000

        # when requesting the github authentication page
        request "#{rootUrl}/auth/github", (err, res, body) ->
          return done err if err?
          # then the github authentication page is displayed
          expect(res).to.have.deep.property('request.uri.host').that.equal 'github.com'
          expect(body, 'No login found in response').to.include 'id="login_field"'
          expect(body, 'No password found in response').to.include 'id="password"'

          # forge form to log-in
          form =
            authenticity_token: body.match(/name\s*=\s*"authenticity_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
            login: githubUser
            password: githubPassword
            commit: 'Sign in'

          # when registering with test account
          request
            uri: 'https://github.com/session'
            method: 'POST'
            form: form
            followAllRedirects: true
          , (err, res, body) ->
            return done err if err?

            # manually follows redirection
            redirect = body.match(/<a href="(http:\/\/localhost:[^"]*code=[^"]*)">/)[1].replace(/\\x26amp%3B/g, '&')

            request redirect, (err, res, body) ->
              return done err if err?
              # then the success page is displayed
              expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
              token = parseUrl(res.request.uri.href).query.replace 'token=', ''
              expect(token).to.exist

              # then account has been created and populated
              Player.findOne {lastName: 'mythic-forge-test'}, (err, saved) ->
                return done "Failed to find created account in db: #{err}" if err? or saved is null
                expect(saved).to.have.property('firstName').that.is.null
                expect(saved).to.have.property 'id'
                expect(saved).to.have.property('provider').that.equal 'Github'
                expect(saved).to.have.property('lastName').that.equal 'mythic-forge-test'
                expect(saved).to.have.property('token').that.equal token
                expect(saved).to.have.property 'lastConnection'
                lastConnection = saved.lastConnection
                done()

      it 'should existing logged-in Github user be immediately authenticated', (done) ->
        @timeout 10000
        # give github some time to update its state before retrying
        _.delay ->
          # when requesting the github authentication page while a github user is already logged-in
          request "#{rootUrl}/auth/github", (err, res, body) ->
            return done err if err?
            # then the success page is displayed
            expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
            expect(JSON.stringify(body), "Wrong credentials during authentication").not.to.include 'Invalid Credentials'
            token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
            expect(token2).to.exist
            expect(token2).not.to.equal token
            token = token2
            # then account has been updated with new token
            Player.findOne {lastName: 'mythic-forge-test'}, (err, saved) ->
              return done "Failed to find created account in db: #{err}" if err?
              expect(saved).to.have.property('provider').that.equal 'Github'
              expect(saved).to.have.property('token').that.equal token2
              expect(saved).to.have.property 'lastConnection'
              expect(lastConnection.getTime()).not.to.equal saved.lastConnection.getTime()
              done()
        , 500

      it 'should existing Github user be authenticated after log-in', (done) ->
        @timeout 20000

        # given an existing but not logged in github account
        request 'https://github.com/logout', (err, res, body) ->
          return done err if err?

          request
            uri: 'https://github.com/logout'
            method: 'POST'
            form:
              authenticity_token: body.match(/name\s*=\s*"authenticity_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
          , (err, res, body) ->
            return done err if err?

            # when requesting the github authentication page
            request "#{rootUrl}/auth/github", (err, res, body) ->
              return done err if err?
              # then the github authentication page is displayed
              expect(res).to.have.deep.property('request.uri.host').that.equal 'github.com'
              expect(body, 'No login found in response').to.include 'id="login_field"'
              expect(body, 'No password found in response').to.include 'id="password"'

              # forge form to log-in
              form =
                authenticity_token: body.match(/name\s*=\s*"authenticity_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
                login: githubUser
                password: githubPassword
                commit: 'Sign in'

              # when registering with test account
              request
                uri: 'https://github.com/session'
                method: 'POST'
                form: form
                followAllRedirects: true
              , (err, res, body) ->
                return done err if err?

                # manually follows redirection
                redirect = body.match(/<a href="(http:\/\/localhost:[^"]*code=[^"]*)/)[1].replace(/\\x26amp%3B/g, '&')

                request redirect, (err, res, body) ->
                  return done err if err?

                  # then the success page is displayed
                  expect(res).to.have.deep.property('request.uri.host').that.equal "localhost:#{staticPort}"
                  token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
                  expect(token2).to.exist
                  expect(token2).not.to.equal token

                  # then account has been created and populated
                  Player.findOne {lastName: 'mythic-forge-test'}, (err, saved) ->
                    return done "Failed to find created account in db: #{err}" if err? or saved is null
                    expect(saved).to.have.property('provider').that.equal 'Github'
                    expect(saved).to.have.property('token').that.equal token2
                    expect(saved).to.have.property 'lastConnection'
                    expect(lastConnection.getTime()).not.to.equal saved.lastConnection.getTime()
                    done()

    describe 'given a manually created player', ->

      player = null
      clearPassword = 'dams'

      before (done) ->
        new Player(
          email: 'dams@test.com'
          password: clearPassword
        ).save (err, saved) ->
          return done err if err?
          player = saved
          done()

      it 'should user be authenticated', (done) ->

        # when sending a correct authentication form
        request
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          form:
            username: player.email
            password: clearPassword
        , (err, res, body) ->
          return done err if err?
          # then the success page is displayed
          url = parseUrl res.headers.location
          expect(url.host).to.equal "localhost:#{staticPort}"
          expect(url.query, "Unexpected server error: #{url.query}").not.to.include 'error='
          token = url.query.replace 'token=', ''
          expect(token).to.exist
          # then account has been populated with new token
          Player.findOne {email:player.email}, (err, saved) ->
            return done "Failed to find created account in db: #{err}" if err?
            expect(saved).to.have.property('token').that.equal token
            expect(saved).to.have.property 'lastConnection'
            lastConnection = saved.lastConnection
            done()

      it 'should user not be authenticated with wrong password', (done) ->

        # when sending a wrong password authentication form
        request
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          form:
            username: player.email
            password: 'toto'
        , (err, res, body) ->
          return done err if err?
          # then the success page is displayed
          url = parseUrl res.headers.location
          expect(url.host).to.equal "localhost:#{staticPort}"
          expect(url.query, "unexpected error #{url.query}").to.include 'wrongCredentials'
          done()

      it 'should unknown user not be authenticated', (done) ->

        # when sending an unknown account authentication form
        request
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          form:
            username: 'toto'
            password: 'titi'
        , (err, res, body) ->
          return done err if err?
          # then the success page is displayed
          url = parseUrl res.headers.location
          expect(url.host).to.equal "localhost:#{staticPort}"
          expect(url.query).to.include 'wrongCredentials'
          done()

      it 'should user not be authenticated without password', (done) ->

        # when sending a wrong password authentication form
        request
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          form:
            username: player.email
        , (err, res, body) ->
          return done err if err?
          # then the success page is displayed
          url = parseUrl res.headers.location
          expect(url.host).to.equal "localhost:#{staticPort}"
          expect(url.query, "unexpected error #{url.query}").to.include 'missingCredentials'
          done()