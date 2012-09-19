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
git = require 'gift'
assert = require('chai').assert
service = require('../src/service/AuthoringService').get()
notifier = require('../src/service/Notifier').get()

port = utils.confKey 'server.staticPort'
rootUrl = "http://localhost:#{port}"
root = utils.confKey 'game.dev'
repository = pathUtils.resolve pathUtils.dirname root
repo = null
notifications = []

describe 'Deployement tests', -> 

  before (done) ->
    # given a clean game source
    fs.remove repository, (err) ->
      return done err if err?
      fs.mkdir root, done

  beforeEach (done) ->
    # given a registered notification listener
    notifications = []
    notifier.on notifier.NOTIFICATION, (event, type, number) ->
      return unless event is 'deployement'
      notifications.push type
      # then notifications are received in the right order
      assert.equal number, notifications.length, 'unexpected notification number' unless type.match /FAILED$/
    done()

  afterEach (done) ->
    notifier.removeAllListeners notifier.NOTIFICATION
    done()

  version = '1.0.0'

  describe 'given a brand new game folder', ->

    beforeEach (done) ->
      # given a clean game source
      fs.remove root, ->
        fs.mkdir root, (err) ->
          return done err if err?
          # given a valid game client in it
          fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'working-client'), root, done

    it 'should coffee compilation errors be reported', (done) ->
      # given a non-compiling coffee script
      fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'Router.coffee.error'), pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, "Parse error on line 50: Unexpected 'STRING'", "Unexpected error: #{err}"
          # then notifications were properly received
          assert.deepEqual notifications, [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'DEPLOY_FAILED'
          ]
          done()
    
    it 'should stylus compilation errors be reported', (done) ->
      # given a non-compiling stylus sheet
      fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'rheia.styl.error'), pathUtils.join(root, 'style', 'rheia.styl'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, "@import 'unexisting'", "Unexpected error: #{err}"
          # then notifications were properly received
          assert.deepEqual notifications, [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'DEPLOY_FAILED'
          ]
          done()

    it 'should no main html file be detected', (done) ->
      # given no main file
      fs.remove pathUtils.join(root, 'index.html'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'no html page including requirej found', "Unexpected error: #{err}"
          # then notifications were properly received
          assert.deepEqual notifications, [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'OPTIMIZE_JS'
            'DEPLOY_FAILED'
          ]
          done()

    it 'should main html file without requirejs be detected', (done) ->
      # given a main file without requirejs
      fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'index.html.norequire'), pathUtils.join(root, 'index.html'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'no html page including requirej found', "Unexpected error: #{err}"
          # then notifications were properly received
          assert.deepEqual notifications, [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'OPTIMIZE_JS'
            'DEPLOY_FAILED'
          ]
          done()

    it 'should no requirejs configuration be detected', (done) ->
      # given a requirejs entry file without configuration
      fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'Router.js.noconfigjs'), pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'no requirejs configuration file found', "Unexpected error: #{err}"
          # then notifications were properly received
          assert.deepEqual notifications, [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'OPTIMIZE_JS'
            'DEPLOY_FAILED'
          ]
          done()

    it 'should requirejs optimization error be detected', (done) ->

      # given a requirejs entry file without error
      fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'Router.coffee.requirejserror'), pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, 'admin', (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'optimized.out\\js\\backbone.js', "Unexpected error: #{err}"
          # then notifications were properly received
          assert.deepEqual notifications, [
            'DEPLOY_START'
            'COMPILE_STYLUS'
            'COMPILE_COFFEE'
            'OPTIMIZE_JS'
            'DEPLOY_FAILED'
          ]
          done()

  describe 'given a started static server', ->

    before (done) ->
      # given a valid game client in it
      fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'working-client'), root, (err) ->
        return done err if err?
        # given a initiazed git repository
        git.init repository, (err) ->
          return done err if err?
          repo = git repository
          repo.add [], all:true, (err) ->
            return done err if err?
            repo.commit 'initial', all:true, (err, stdout, stderr) ->
              return done err if err?
              server.listen port, 'localhost', done
      
    after (done) ->
      server.close()
      done()

    it 'should no version be registerd', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        assert.isNull state?.current
        assert.equal 0, state?.versions?.length
        done()

    it 'should file be correctly compiled and deployed', (done) ->
      @timeout 20000
      # when deploying the game client
      service.deploy version, 'admin', (err) ->
        return done "Failed to deploy valid client: #{err}" if err?
        # then notifications were properly received
        assert.deepEqual notifications, [
          'DEPLOY_START'
          'COMPILE_STYLUS'
          'COMPILE_COFFEE'
          'OPTIMIZE_JS'
          'OPTIMIZE_HTML'
          'DEPLOY_FILES'
          'DEPLOY_END'
        ]
        # then the client was deployed
        browser = new Browser silent: true
        browser.visit("#{rootUrl}/game").then( ->
          # then the resultant url is working, with template rendering and i18n usage
          body = browser.body.textContent.trim()
          assert.match body, new RegExp "#{version}\\s*Edition du monde"
          done()
        ).fail done

    it 'should deploy, save, remove, move and restoreVersion be disabled while deploying', (done) ->
      async.forEach [
        {method: 'deploy', args: ['2.0.0', 'admin']}
        {method: 'save', args: ['index.html', 'admin']}
        {method: 'remove', args: ['index.html', 'admin']}
        {method: 'move', args: ['index.html', 'index.html2', 'admin']}
        {method: 'restoreVersion', args: [version]}
      ], (spec, next) ->
        # when invoking the medhod
        spec.args.push (err) ->
          assert.isDefined err
          assert.include err, ' in progress', "unexpected error #{err}"
          assert.include err, version, "unexpected error #{err}"
          next()
        service[spec.method].apply service, spec.args
      , done

    it 'should state indicates deploy by admin from no version', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        assert.equal state?.author, 'admin'
        assert.equal state?.deployed, version
        assert.isFalse state?.inProgress
        assert.isNull state?.current
        assert.deepEqual state?.versions, []
        done()

    it 'should no other author commit or rollback', (done) ->
      async.forEach ['Commit', 'Rollback'], (method, next) ->
        # when invoking the medhod
        service[method.toLowerCase()] 'admin2', (err) ->
          # then error is throwned
          assert.isDefined err
          assert.equal err, "#{method} can only be performed be deployement author admin", "unexpected error #{err}"
          next()
      , done

    it 'should commit be successful', (done) ->
      # when commiting the deployement
      service.commit 'admin', (err) ->
        return done "Failed to commit deployement: #{err}" if err?
        # then notifications were properly received
        assert.deepEqual notifications, ['COMMIT_START', 'VERSION_CREATED', 'COMMIT_END']

        # then a git version was created
        repo.tags (err, tags) ->
          return done "Failed to consult tags: #{err}" if err?
          assert.equal 1, tags.length
          assert.equal tags[0].name, version

          # then no more save folder exists
          save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.save'
          fs.exists save, (exists) ->
            assert.isFalse exists, "#{save} still exists"
            done()

    it 'should state indicates no deployement from version 1.0.0', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        assert.isNull state?.author
        assert.isNull state?.deployed
        assert.isFalse state?.inProgress
        assert.deepEqual state?.versions, [version]
        assert.equal state?.current, version
        done()

    it 'should commit and rollback not invokable outside deploy', (done) ->
      async.forEach ['Commit', 'Rollback'], (method, next) ->
        # when invoking the medhod
        service[method.toLowerCase()] 'admin', (err) ->
          # then error is throwned
          assert.isDefined err
          assert.equal err, "#{method} can only be performed after deploy", "unexpected error #{err}"
          next()
      , done

    it 'should version not be reused', (done) ->
      service.deploy version, 'admin', (err) ->
        assert.isDefined err
        assert.equal err, "Version #{version} already used", "unexpected error #{err}"
        done()

    version2 = '2.0.0'

    it 'should another deployement be possible', (done) ->
      @timeout 20000

      # given a modification on a file
      fs.copy pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'common.coffee.v2'), pathUtils.join(root, 'nls', 'common.coffee'), (err) ->
        return done err if err?
        repo.commit 'change to v2', all:true, (err, stdout, stderr) ->
          return done err if err?

          # when deploying the game client
          service.deploy version2, 'admin', (err) ->
            return done "Failed to deploy valid client: #{err}" if err?
            # then the client was deployed
            browser = new Browser silent: true
            browser.visit("#{rootUrl}/game").then( ->
              # then the resultant url is working, with template rendering and i18n usage
              body = browser.body.textContent.trim()
              assert.match body, new RegExp "#{version2}\\s*Edition du monde 2"
              # then the deployement can be commited
              notifications = []
              service.commit 'admin', done
            ).fail done

    it 'should state indicates no deployement from version 2.0.0', (done) ->
      service.deployementState (err, state) ->
        return done err if err?
        assert.isNull state?.author
        assert.isNull state?.deployed
        assert.isFalse state?.inProgress
        assert.deepEqual state?.versions, [version2, version]
        assert.equal state?.current, version2
        done()

    it 'should previous version be restored', (done) ->
      # when restoring version 1
      service.restoreVersion version, (err) ->
        return done err if err?
        
        # then file common.coffee was restored
        fs.readFile pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'working-client', 'nls', 'common.coffee'), 'utf-8', (err, originalContent) ->
          fs.readFile pathUtils.join(root, 'nls', 'common.coffee'), 'utf-8', (err, content) ->
            assert.equal content, originalContent, 'Version was not restored'

            # then notifications were properly received
            assert.deepEqual notifications, ['VERSION_RESTORED']
            
            # then version is now version 1
            service.deployementState (err, state) ->
              return done err if err?
              assert.isNull state?.author
              assert.isNull state?.deployed
              assert.isFalse state?.inProgress
              assert.equal state?.current, version
              assert.deepEqual state?.versions, [version2, version]
              done()

    it 'should last version be restored', (done) ->
      # when restoring version 2
      service.restoreVersion version2, (err) ->
        return done err if err?
        # then file common.coffee was restored
        fs.readFile pathUtils.join('.', 'hyperion', 'test', 'fixtures', 'common.coffee.v2'), 'utf-8', (err, originalContent) ->
          fs.readFile pathUtils.join(root, 'nls', 'common.coffee'), 'utf-8', (err, content) ->
            assert.equal content, originalContent, 'Version was not restored'

            # then notifications were properly received
            assert.deepEqual notifications, ['VERSION_RESTORED']

            # then version is now version 2
            service.deployementState (err, state) ->
              return done err if err?
              assert.isNull state?.author
              assert.isNull state?.deployed
              assert.isFalse state?.inProgress
              assert.equal state?.current, version2
              assert.deepEqual state?.versions, [version2, version]
              done()
    
    version3 = '3.0.0'

    it 'should deployement be rollbacked', (done) ->
      @timeout 20000

      # given a modification on game files
      labels = pathUtils.join root, 'nls', 'common.coffee'
      original = pathUtils.join '.', 'hyperion', 'test', 'fixtures', 'common.coffee.v3'
      fs.copy original, labels, (err) ->
        return done err if err?

        # given a commit
        repo.commit 'change to v3', all:true, (err, stdout, stderr) ->
          return done err if err?

          # given a deployed game client
          service.deploy version3, 'admin', (err) ->
            return done err if err?
            notifications = []
            
            # when rollbacking
            service.rollback 'admin', (err) ->
              return done "Failed to rollback: #{err}" if err?

              # then notifications were properly received
              assert.deepEqual notifications, ['ROLLBACK_START', 'ROLLBACK_END']

              # then no version was made
              repo.tags (err, tags) ->
                return done err if err?
                return assert.fail "Version #{version2} has been tagged" for tag in tags when tag.name is version3

                # then file still modified
                fs.readFile labels, 'utf8', (err, newContent) ->
                  return done err if err?
                  fs.readFile original, 'utf8', (err, content) ->
                    return done err if err?
                    assert.equal newContent, content, "File was modified"

                    # then version is still version 2
                    service.deployementState (err, state) ->
                      return done err if err?
                      assert.isNull state?.author
                      assert.isNull state?.deployed
                      assert.isFalse state?.inProgress
                      assert.equal state?.current, version2
                      assert.deepEqual state?.versions, [version2, version]

                      # then the save folder do not exists anymore 
                      save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.save'
                      fs.exists save, (exists) ->
                        assert.isFalse exists, "#{save} still exists"

                        # then the previous client was deployed
                        browser = new Browser silent: true
                        browser.visit("#{rootUrl}/game").then( ->
                          # then the resultant url is working, with template rendering and i18n usage
                          body = browser.body.textContent.trim()
                          assert.match body, new RegExp "#{version2}\\s*Edition du monde 2"
                          done()
                        ).fail done

    it 'should version be created', (done) ->
      # when creating version 3
      service.createVersion version3, (err) ->
        return done err if err?

        # then notifications were properly received
        assert.deepEqual notifications, ['VERSION_CREATED']

        # then a git version was created
        repo.tags (err, tags) ->
          return done "Failed to consult tags: #{err}" if err?
          assert.equal 3, tags.length
          assert.equal tags[0].name, version
          done()

    it 'should existing version not be created', (done) ->
      # when creating version 3 another time
      service.createVersion version3, (err) ->
        assert.isDefined err
        assert.equal err, "Cannot reuse existing version #{version3}", "unexpected error #{err}"
        done()
