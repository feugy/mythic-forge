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
async = require 'async'
{join, dirname, resolve, normalize} = require 'path'
fs = require 'fs-extra'
FSItem = require '../hyperion/src/model/FSItem'
Executable = require '../hyperion/src/model/Executable'
utils = require '../hyperion/src/util/common'
versionUtils = require '../hyperion/src/util/versionning'
service = require('../hyperion/src/service/AuthoringService').get()
notifier = require('../hyperion/src/service/Notifier').get()
logger = require('../hyperion/src/util/logger').getLogger 'test'
assert = require('chai').assert

repoRoot = resolve normalize utils.confKey 'game.repo'
gameFiles = resolve normalize utils.confKey 'game.client.dev'
gameRules = resolve normalize utils.confKey 'game.executable.source'
repo = null
file = null
oldPath = null
notifications = []
        
describe 'AuthoringService tests', -> 

  before (done) ->
    @timeout 3000
    # re-initialize game repository
    versionUtils.initGameRepo logger, true, (err, _root, _repo) ->
      return done err if err?
      repo = _repo
      Executable.resetAll false, (err) ->
        return done err if err?
        service.init done

  notifListener = (event, args...) ->
    notifications.push args if event is 'authoring'

  beforeEach (done) ->
    # given a registered notification listener
    notifications = []
    notifier.on notifier.NOTIFICATION, notifListener
    done()

  afterEach (done) ->
    notifier.removeListener notifier.NOTIFICATION, notifListener
    done()

  it 'should file be created', (done) -> 
    # given a new file
    item = new FSItem 'file.txt', false
    # when saving it 
    service.save item, 'admin', (err, saved) ->
      return done "Cannot save file: #{err}" if err?
      # then the file was saved
      assert.ok item.equals saved
      fs.exists join(gameFiles, item.path), (exists) ->
        assert.ok exists, "file #{item.path} wasn't created"
        done()

  it 'should folder be created', (done) -> 
    # given a new file
    item = new FSItem "folder", true
    # when saving it 
    service.save item, 'admin', (err, saved) ->
      return done "Cannot save folder: #{err}" if err?
      # then nonotification issued
      assert.equal 0, notifications.length

      # then the file was saved
      assert.ok item.equals saved
      fs.exists join(gameFiles, item.path), (exists) ->
        assert.ok exists, "folder #{item.path} wasn't created"
        done()

  describe 'given an non-empty root', ->
    content = [
      new FSItem 'file1.txt', false
      new FSItem 'file2.txt', false
      new FSItem 'folder', true
    ]
    before (done) ->
      # given a clean game source
      utils.remove gameFiles, ->
        # and some file in it
        async.forEach ['file1.txt', 'file2.txt', 'folder/file3.txt', 'folder/file4.txt'], (file, next) ->
          file = join gameFiles, file
          fs.mkdirs dirname(file), (err) ->
            return next err if err?
            fs.writeFile file, '', next
        , done

    it 'should root retrieve populated root folder', (done) ->
      # when retrieving root folder
      service.readRoot (err, folder) ->
        return done "Cannot retrieve root folder: #{err}" if err?
        # then all awaited subitems are present.
        assert.equal folder.content.length, content.length
        for file in content
          found = false
          for result in folder.content when result.equals file
            found = true
            break
          assert.isTrue found, "file #{file.path} was not read"
        done()

  describe 'given an existing file', ->

    before (done) ->
      fs.readFile join(__dirname, 'fixtures', 'image1.png'), (err, data) ->
        return done err if err?
        file = new FSItem 'folder/image1.png', false
        file.content = data
        service.save file, 'admin', (err, saved) ->
          return done err if err?
          file = saved
          done()

    it 'should file content be read', (done) -> 
      file.content = null
      # when reading the file
      service.read file, (err, read) ->
        return done "Cannot read file: #{err}" if err?
        # then read data is correct
        fs.readFile join(__dirname, 'fixtures', 'image1.png'), (err, data) ->
          return done err if err?
          assert.equal read.content, data.toString('base64')
          done()
        
    it 'should file content be updated', (done) -> 
      # given a binary content
      fs.readFile join(__dirname, 'fixtures', 'image2.png'), (err, data) ->
        return done err if err?
        file.content = data
        # when saving it 
        service.save file, 'admin', (err, saved) ->
          return done "Cannot save existing file: #{err}" if err?
          # then the file was saved
          assert.ok file.equals saved
          assert.equal saved.content, data.toString('base64'),
          # then the saved content is equals
          fs.readFile join(gameFiles, saved.path), (err, readData) ->
            return done err if err?
            assert.equal readData.toString('base64'), data.toString('base64')
            done()

    it 'should file content be moved', (done) -> 
      # when reading the folder
      oldPath = "#{file.path}"
      service.move file, 'folder5/newFile', 'admin', (err, moved) ->
        return done "Cannot move file: #{err}" if err?
        # then new file is created
        assert.notEqual moved.path, oldPath
        fs.exists join(gameFiles, moved.path), (exists) ->
          assert.isTrue exists, "file #{file.path} wasn't moved"
          # then content is correct
          fs.readFile join(gameFiles, moved.path), (err, data) ->
            assert.equal moved.content, data.toString('base64'),
            # then old one removed
            fs.exists join(gameFiles, oldPath), (exists) ->
              assert.isFalse exists, "file #{oldPath} wasn't removed"
              file = moved
              done()

    it 'should file be removed', (done) -> 
      # when removing the file
      service.remove file, 'admin', (err, removed) ->
        return done "Cannot remove file: #{err}" if err?
        # then the file was removed
        assert.ok file.equals removed
        fs.exists join(gameFiles, file.path), (exists) ->
          assert.isFalse exists, "file #{file.path} wasn't removed"
          done()

  describe 'given a version controled file and executable', ->
    executable = null
    exeContent1 = 'greetings = "hello world"'
    exeContent2 = 'greetings = "hello world v2"'

    before (done) ->
      # cleaning executables and client files
      utils.empty gameFiles, (err) -> 
        return done err if err?
        utils.empty gameRules, (err) -> 
          return done err if err?
          # first version of file and executable
          fs.readFile join(__dirname, 'fixtures', 'common.coffee.v1'), (err, data) ->
            return done err if err?
            file = new FSItem 'common.coffee', false
            file.content = data
            service.save file, 'admin', (err, saved) ->
              return done err if err?
              executable = new Executable id: 'test', content: exeContent1
              executable.save (err) ->
               return done err if err?
               # first commit
               repo.add [gameFiles.replace(repoRoot, ''), gameRules.replace(repoRoot, '')], {A: true}, (err) ->
                return done err if err?
                repo.commit 'first commit', (err) ->
                  return done err if err?
                  # second version of file and executable
                  fs.readFile join(__dirname, 'fixtures', 'common.coffee.v2'), (err, data) ->
                    return done err if err?
                    file.content = data
                    service.save file, 'admin', (err, saved) ->
                      return done err if err?
                      executable.content = exeContent2
                      executable.save (err) ->
                        return done err if err?
                        # second commit
                        repo.add [gameFiles.replace(repoRoot, ''), gameRules.replace(repoRoot, '')], {A: true}, (err) ->
                          return done err if err?
                          repo.commit 'second commit', done

    it 'should file content be read at last version', (done) -> 
      service.history file, (err, read, history) ->
        return done err if err?
        assert.equal history.length, 2
        assert.equal history[0].message, 'second commit'

        # when reading the file at last version
        service.readVersion file, history[0].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          fs.readFile join(__dirname, 'fixtures', 'common.coffee.v2'), (err, data) ->
            return done err if err?
            assert.equal content, data.toString('base64')
            done()

    it 'should executable content be read at last version', (done) -> 
      service.history executable, (err, read, history) ->
        return done err if err?
        assert.equal history.length, 2
        assert.equal history[0].message, 'second commit'

        # when reading the executable at last version
        service.readVersion executable, history[0].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          assert.ok executable.equals read
          assert.equal content, new Buffer(exeContent2).toString('base64')
          done()

    it 'should file content be read at first version', (done) -> 
      service.history file, (err, read, history) ->
        return done err if err?
        assert.equal history.length, 2
        assert.equal history[1].message, 'first commit'

        # when reading the file at first version
        service.readVersion file, history[1].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          fs.readFile join(__dirname, 'fixtures', 'common.coffee.v1'), (err, data) ->
            return done err if err?
            assert.equal content, data.toString('base64')
            done()

    it 'should executable content be read at first version', (done) -> 
      service.history executable, (err, read, history) ->
        return done err if err?
        assert.equal history.length, 2
        assert.equal history[1].message, 'first commit'

        # when reading the file at first version
        service.readVersion executable, history[1].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          assert.ok executable.equals read
          assert.equal content, new Buffer(exeContent1).toString('base64')
          done()

    it 'should file history be consulted', (done) ->
      # when consulting history for this file
      service.history file, (err, read, history) ->
        return done "Cannot get history: #{err}" if err?
        assert.equal 2, history.length
        assert.ok file.equals read
        for i in [0..1]
          assert.instanceOf history[i].date, Date
          assert.equal 'mythic-forge', history[i].author
        assert.deepEqual ['second commit', 'first commit'], _.pluck history, 'message'
        done()

    it 'should executable history be consulted', (done) ->
      # when consulting history for this file
      service.history executable, (err, read, history) ->
        return done "Cannot get history: #{err}" if err?
        assert.ok executable.equals read
        assert.equal 2, history.length
        for i in [0..1]
          assert.instanceOf history[i].date, Date
          assert.equal 'mythic-forge', history[i].author
        assert.deepEqual ['second commit', 'first commit'], _.pluck history, 'message'
        done()

    it 'should removed file and executable appears in restorable list', (done) ->
      # given a removed file
      service.remove file, 'admin', (err) ->
        return done err if err?
        executable.remove (err) ->
          return done err if err?
          repo.add [gameFiles.replace(repoRoot, ''), gameRules.replace(repoRoot, '')], {A: true}, (err) ->
            return done err if err?
            repo.commit 'third commit', (err) ->
              return done err if err?
              # when consulting history for this file
              service.restorables (err, restorables) ->
                return done "Cannot get restorables: #{err}" if err?
                assert.equal 2, restorables.length
                assert.ok restorables[1].item.equals(file), 'deleted file not found as second restorable'
                assert.ok restorables[0].item.equals(executable), 'deleted executable not found as first restorable'
                done()

  describe 'given an existing folder', ->
    folder = null
    files = []

    before (done) ->
      folder = new FSItem 'folder/folder2', true
      service.save folder, 'admin', (err, saved) ->
        return done err if err?
        folder = saved
        async.forEachSeries ['file1.txt', 'file2.txt'], (file, next) ->
          item = new FSItem join(folder.path, file), false
          files.push item
          service.save item, 'admin', next
        , (err) ->
          return done err if err?
          done()

    it 'should folder content be read', (done) -> 
      folder.content = null
      # when reading the folder
      service.read folder, (err, read) ->
        return done "Cannot read folder: #{err}" if err?
        # then read data is correct
        assert.equal read.content.length, files.length
        for file in read.content
          found = false
          for content in read.content when content.equals file
            found = true
            break
          assert.isTrue found, "file #{file.path} was not read"
        done()

    it 'should folder content be moved', (done) -> 
      # when reading the folder
      oldPath = "#{folder.path}"
      service.move folder, 'folder3/folder4', 'admin', (err, moved) ->
        return done "Cannot move folder: #{err}" if err?
        # then new folder is created and old one removed
        assert.notEqual moved.path, oldPath
        fs.exists join(gameFiles, moved.path), (exists) ->
          assert.isTrue exists, "folder #{folder.path} wasn't moved"
          fs.exists join(gameFiles, oldPath), (exists) ->
            assert.isFalse exists, "folder #{oldPath} wasn't removed"
            folder = moved
            done()

    it 'should folder be removed', (done) -> 
      # when removing the folder
      service.remove folder, 'admin', (err, removed) ->
        return done "Cannot remove folder: #{err}" if err?
        # then nonotification issued
        assert.equal 0, notifications.length

        # then the file was removed
        assert.ok folder.equals removed
        fs.exists join(gameFiles, folder.path), (exists) ->
          assert.isFalse exists, "folder #{folder.path} wasn't removed"
          done()