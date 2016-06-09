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
async = require 'async'
pathUtils = require 'path'
fs = require 'fs-extra'
http = require 'http'
FSItem = require '../hyperion/src/model/FSItem'
Executable = require '../hyperion/src/model/Executable'
utils = require '../hyperion/src/util/common'
front = require '../hyperion/src/web/front'
Horseman = require 'node-horseman'
git = require 'gift'
{expect} = require 'chai'
service = require('../hyperion/src/service/DeployementService').get()
authoringService = require('../hyperion/src/service/AuthoringService').get()
versionService = require('../hyperion/src/service/VersionService').get()
notifier = require('../hyperion/src/service/Notifier').get()

port = utils.confKey 'server.staticPort'
rootUrl = "http://localhost:#{port}"
root = utils.confKey 'game.client.dev'
exeRoot = utils.confKey 'game.executable.source'
notifications = []
browser = null
listener = null

describe 'Deployement tests', ->

  before (done) ->
    @timeout 5000
    # clean destination folder
    fs.remove utils.confKey('game.client.production'), ->
      # reset game git repository
      versionService.init true, done

  beforeEach (done) ->
    # given a registered notification listener
    notifications = []
    notifier.on notifier.NOTIFICATION, listener = (event, type, number) ->
      return unless event is 'deployement'
      notifications.push type
      # then notifications are received in the right order
      unless type.match /FAILED$/
        expect(notifications).to.have.lengthOf number
    done()

  afterEach (done) ->
    notifier.removeListener notifier.NOTIFICATION, listener
    return done() unless browser?
    browser.close()
    done()

  version = '1.0.0'

  describe 'given a brand new game folder', ->

    beforeEach (done) ->
      # given a clean game source
      utils.remove root, (err) ->
        return done err if err?
        utils.remove exeRoot, (err) ->
          return done err if err?
          fs.mkdirs root, (err) ->
            return done err if err?
            fs.mkdirs exeRoot, (err) ->
              return done err if err?
              fs.mkdirs utils.confKey('game.executable.target'), (err) ->
                return done err if err?
                # given an executable
                new Executable(id: 'test', content: 'msg = "hello world"').save (err) ->
                  return done err if err?
                  # given a valid game client in it
                  fs.copy pathUtils.join(__dirname, 'fixtures', 'working-client'), root, done

    it 'should coffee compilation errors be reported', (done) ->
      # given a non-compiling coffee script
      fs.copy pathUtils.join('.', 'test', 'fixtures', 'Router.coffee.error'), pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          expect(err).to.include "46:23: error: unexpected string"
          # then notifications were properly received
          expect(notifications).to.deep.equal [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'DEPLOY_FAILED'
          ]
          done()

    it 'should stylus compilation errors be reported', (done) ->
      # given a non-compiling stylus sheet
      fs.copy pathUtils.join(__dirname, 'fixtures', 'rheia.styl.error'), pathUtils.join(root, 'style', 'rheia.styl'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          expect(err).to.include "@import 'unexisting'"
          # then notifications were properly received
          expect(notifications).to.deep.equal [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'DEPLOY_FAILED'
          ]
          done()

    it 'should no main html file be detected', (done) ->
      # given no main file
      utils.remove pathUtils.join(root, 'index.html'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          expect(err).to.include 'no html page including requirejs found'
          # then notifications were properly received
          expect(notifications).to.deep.equal [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'OPTIMIZE_JS'
            'DEPLOY_FAILED'
          ]
          done()

    it 'should main html file without requirejs be detected', (done) ->
      # given a main file without requirejs
      fs.copy pathUtils.join(__dirname, 'fixtures', 'index.html.norequire'), pathUtils.join(root, 'index.html'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          expect(err).to.include 'no html page including requirejs found'
          # then notifications were properly received
          expect(notifications).to.deep.equal [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'OPTIMIZE_JS'
            'DEPLOY_FAILED'
          ]
          done()

    # Do not test on Travis: callback is never called ?
    unless process.env.TRAVIS
      it 'should requirejs optimization error be detected', (done) ->
        @timeout 5000

        # given a requirejs entry file without error
        fs.copy pathUtils.join(__dirname, 'fixtures', 'Router.coffee.requirejserror'), pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
          return done err if err?

          # when optimizing the game client
          service.deploy version, 'admin', (err) ->
            # then an error is reported
            expect(err).to.include 'optimized.out\\js\\backbone.js'
            # then notifications were properly received
            expect(notifications).to.deep.equal [
              'DEPLOY_START'
              'COMPILE_STYLUS'
              'COMPILE_COFFEE'
              'OPTIMIZE_JS'
              'DEPLOY_FAILED'
            ]
            done()

    it 'should no requirejs configuration be detected', (done) ->
      # given a requirejs entry file without configuration
      fs.copy pathUtils.join(__dirname, 'fixtures', 'Router.js.noconfigjs'), pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          expect(err).to.include 'no requirejs configuration file found'
          # then notifications were properly received
          expect(notifications).to.deep.equal [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'OPTIMIZE_JS'
            'DEPLOY_FAILED'
          ]
          done()

  describe 'given a started static server', ->

    server = null

    before (done) ->
      # given a valid game client in it
      fs.copy pathUtils.join(__dirname, 'fixtures', 'working-client'), root, (err) ->
        return done err if err?
        # given a initiazed git repository
        versionService.init (err) ->
          return done err if err?
          server = http.createServer front()
          server.listen port, 'localhost', done

    after (done) ->
      server.close()
      done()

    it 'should no version be registerd', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        expect(state).to.have.property('current').that.is.null
        expect(state).to.have.property('versions').that.have.lengthOf 0
        done()

    it 'should file be correctly compiled and deployed', (done) ->
      @timeout 20000
      # when deploying the game client
      service.deploy version, 'admin', (err) ->
        return done "Failed to deploy valid client: #{err}" if err?
        page = null
        # then notifications were properly received
        expect(notifications).to.deep.equal [
          'DEPLOY_START'
          'COMPILE_STYLUS'
          'COMPILE_COFFEE'
          'OPTIMIZE_JS'
          'OPTIMIZE_HTML'
          'DEPLOY_FILES'
          'DEPLOY_END'
        ]
        # then the client was deployed
        browser = new Horseman()
        browser.on 'error', done
        browser.on 'consoleMessage', (message) -> console.log message
        browser.open "#{rootUrl}/game/"
          # then the resultant url is working, with template rendering and i18n usage
          .waitForSelector '.container'
          .text 'body'
          .then (body) ->
            expect(body).to.include version
            expect(body).to.include 'Edition du monde'
            done()
          .catch done

    it 'should deploy, save, remove, move and restoreVersion be disabled while deploying', (done) ->
      async.forEach [
        {method: 'deploy', args: ['2.0.0', 'admin'], service: service}
        {method: 'save', args: ['index.html'], service: authoringService}
        {method: 'remove', args: ['index.html'], service: authoringService}
        {method: 'move', args: ['index.html', 'index.html2'], service: authoringService}
        {method: 'restoreVersion', args: [version], service: service}
      ], (spec, next) ->
        # when invoking the medhod
        spec.args.push (err) ->
          expect(err).to.include ' in progress'
          expect(err).to.include version
          next()
        spec.service[spec.method].apply spec.service, spec.args
      , done

    it 'should state indicates deploy by admin from no version', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        expect(state).to.have.property('author').that.equal 'admin'
        expect(state).to.have.property('deployed').that.equal version
        expect(state).to.have.property('inProgress').that.equal false
        expect(state).to.have.property('current').that.is.null
        expect(state).to.have.property('versions').that.is.deep.equal []
        done()

    it 'should no other author commit or rollback', (done) ->
      async.forEach ['Commit', 'Rollback'], (method, next) ->
        # when invoking the medhod
        service[method.toLowerCase()] 'admin2', (err) ->
          # then error is throwned
          expect(err).to.include "#{method} can only be performed be deployement author admin"
          next()
      , done

    it 'should commit be successful', (done) ->
      @timeout 10000

      # when commiting the deployement
      service.commit 'admin', (err) ->
        return done "Failed to commit deployement: #{err}" if err?
        # then notifications were properly received
        expect(notifications).to.deep.equal ['COMMIT_START', 'VERSION_CREATED', 'COMMIT_END']

        # then a git version was created
        versionService.repo.tags (err, tags) ->
          return done "Failed to consult tags: #{err}" if err?
          expect(tags).to.have.lengthOf 1
          expect(tags[0]).to.have.property('name').that.equal version

          # then no more save folder exists
          save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.save'
          fs.exists save, (exists) ->
            expect(exists).to.be.false
            done()

    it 'should state indicates no deployement from version 1.0.0', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        expect(state).to.have.property('author').that.is.null
        expect(state).to.have.property('deployed').that.is.null
        expect(state).to.have.property('inProgress').that.equal false
        expect(state).to.have.property('versions').that.is.deep.equal [version]
        expect(state).to.have.property('current').that.equal version
        done()

    it 'should commit and rollback not invokable outside deploy', (done) ->
      async.each ['Commit', 'Rollback'], (method, next) ->
        # when invoking the medhod
        service[method.toLowerCase()] 'admin', (err) ->
          # then error is throwned
          expect(err).to.include "#{method} can only be performed after deploy"
          next()
      , done

    it 'should version not be reused', (done) ->
      service.deploy version, 'admin', (err) ->
        expect(err).to.include "Version #{version} already used"
        done()

    version2 = '2.0.0'

    it 'should another deployement be possible', (done) ->
      @timeout 20000

      # given a modification on a file
      fs.copy pathUtils.join(__dirname, 'fixtures', 'common.coffee.v2'), pathUtils.join(root, 'nls', 'common.coffee'), (err) ->
        return done err if err?
        # given a modification on an executable
        new Executable(id: 'test').remove (err) ->
          return done err if err?
          new Executable(id: 'test2', content: 'msg2 = "hi there !"').save (err) ->
            return done err if err?
            # when deploying the game client
            service.deploy version2, 'admin', (err) ->
              return done "Failed to deploy valid client: #{err}" if err?
              # then the client was deployed
              browser = new Horseman()
              browser.on 'error', done
              browser.on 'consoleMessage', (message) -> console.log message
              browser.open "#{rootUrl}/game/"
                # then the resultant url is working, with template rendering and i18n usage
                .waitForSelector '.container'
                .text 'body'
                .then (body) ->
                  expect(body).to.include version2
                  expect(body).to.include 'Edition du monde 2'
                  # then the deployement can be commited
                  notifications = []
                  service.commit 'admin', done
                .catch done

    it 'should state indicates no deployement from version 2.0.0', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        expect(state).to.have.property('author').that.is.null
        expect(state).to.have.property('deployed').that.is.null
        expect(state).to.have.property('inProgress').that.equal false
        expect(state).to.have.property('versions').that.is.deep.equal [version2, version]
        expect(state).to.have.property('current').that.equal version2
        done()

    it 'should previous version be restored', (done) ->
      # when restoring version 1
      service.restoreVersion version, (err) ->
        return done err if err?

        # then file common.coffee was restored
        fs.readFile pathUtils.join(__dirname, 'fixtures', 'working-client', 'nls', 'common.coffee'), 'utf-8', (err, originalContent) ->
          fs.readFile pathUtils.join(root, 'nls', 'common.coffee'), 'utf-8', (err, content) ->
            expect(content, 'Version was not restored').to.equal originalContent

            # then test executable is there and not test2
            fs.readFile pathUtils.join(exeRoot, 'test.coffee'), (err, content) ->
              expect(err).not.to.exist
              expect(content.toString()).to.equal 'msg = "hello world"'

              expect(fs.existsSync pathUtils.join exeRoot, 'test2.coffee').to.be.false

              # then notifications were properly received
              expect(notifications).to.deep.equal ['VERSION_RESTORED']

              # then version is now version 1
              service.deployementState (err, state) ->
                return done err if err?
                expect(state).to.have.property('author').that.is.null
                expect(state).to.have.property('deployed').that.is.null
                expect(state).to.have.property('inProgress').that.equal false
                expect(state).to.have.property('current').that.equal version
                expect(state).to.have.property('versions').that.is.deep.equal [version2, version]
                done()

    it 'should last version be restored', (done) ->
      # when restoring version 2
      service.restoreVersion version2, (err) ->
        return done err if err?
        # then file common.coffee was restored
        fs.readFile pathUtils.join(__dirname, 'fixtures', 'common.coffee.v2'), 'utf-8', (err, originalContent) ->
          fs.readFile pathUtils.join(root, 'nls', 'common.coffee'), 'utf-8', (err, content) ->
            expect(content, 'Version was not restored').to.equal originalContent

            # then test executable was removed and test2 is there
            fs.readFile pathUtils.join(exeRoot, 'test2.coffee'), (err, content) ->
              expect(err).not.to.exist
              expect(content.toString()).to.equal 'msg2 = "hi there !"'

              expect(fs.existsSync pathUtils.join exeRoot, 'test.coffee').to.be.false

              # then notifications were properly received
              expect(notifications).to.deep.equal ['VERSION_RESTORED']

              # then version is now version 2
              service.deployementState (err, state) ->
                return done err if err?
                expect(state).to.have.property('author').that.is.null
                expect(state).to.have.property('deployed').that.is.null
                expect(state).to.have.property('inProgress').that.equal false
                expect(state).to.have.property('current').that.equal version2
                expect(state).to.have.property('versions').that.is.deep.equal [version2, version]
                done()

    version3 = '3.0.0'

    it 'should deployement be rollbacked', (done) ->
      @timeout 20000

      # given a modification on game files
      labels = pathUtils.join root, 'nls', 'common.coffee'
      original = pathUtils.join __dirname, 'fixtures', 'common.coffee.v3'
      fs.copy original, labels, (err) ->
        return done err if err?

        # given a deployed game client
        service.deploy version3, 'admin', (err) ->
          return done err if err?
          notifications = []

          # when rollbacking
          service.rollback 'admin', (err) ->
            return done "Failed to rollback: #{err}" if err?

            # then notifications were properly received
            expect(notifications).to.deep.equal ['ROLLBACK_START', 'ROLLBACK_END']

            # then no version was made
            versionService.repo.tags (err, tags) ->
              return done err if err?
              for tag in tags when tag.name is version3
                throw new Error "Version #{version2} has been tagged"

              # then file still modified
              fs.readFile labels, 'utf8', (err, newContent) ->
                return done err if err?
                fs.readFile original, 'utf8', (err, content) ->
                  return done err if err?
                  expect(newContent, "File was modified").to.equal content

                  # then version is still version 2
                  service.deployementState (err, state) ->
                    return done err if err?
                    expect(state).to.have.property('author').that.is.null
                    expect(state).to.have.property('deployed').that.is.null
                    expect(state).to.have.property('inProgress').that.equal false
                    expect(state).to.have.property('current').that.equal version2
                    expect(state).to.have.property('versions').that.is.deep.equal [version2, version]

                    # then the save folder do not exists anymore
                    save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.save'
                    fs.exists save, (exists) ->
                      expect(exists, "#{save} still exists").to.be.false

                      # then the client was deployed
                      browser = new Horseman()
                      browser.on 'error', done
                      browser.on 'consoleMessage', (message) -> console.log message
                      browser.open "#{rootUrl}/game/"
                        # then the resultant url is working, with template rendering and i18n usage
                        .waitForSelector '.container'
                        .text 'body'
                        .then (body) ->
                          expect(body).to.include version2
                          expect(body).to.include 'Edition du monde 2'
                          done()
                        .catch done

    it 'should version be created', (done) ->
      @timeout 5000

      # given a modification on game files
      labels = pathUtils.join root, 'nls', 'common.coffee'
      original = pathUtils.join __dirname, 'fixtures', 'common.coffee.v3'
      fs.copy original, labels, (err) ->
        return done err if err?

        # when creating version 3
        service.createVersion version3, 'admin', (err) ->
          return done err if err?

          # then notifications were properly received
          expect(notifications).to.deep.equal ['VERSION_CREATED']

          # then a git version was created
          versionService.repo.tags (err, tags) ->
            return done "Failed to consult tags: #{err}" if err?
            expect(tags).to.have.lengthOf 3
            expect(tags[0]).to.have.property('name').that.equal version
            done()

    it 'should existing version not be created', (done) ->
      # when creating version 3 another time
      service.createVersion version3, 'admin', (err) ->
        expect(err).to.include "Cannot reuse existing version #{version3}"
        done()