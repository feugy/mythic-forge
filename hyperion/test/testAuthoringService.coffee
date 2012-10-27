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
pathUtils = require 'path'
fs = require 'fs-extra'
gift = require 'gift'
FSItem = require '../src/model/FSItem'
utils = require '../src/utils'
service = require('../src/service/AuthoringService').get()
notifier = require('../src/service/Notifier').get()
assert = require('chai').assert

root = utils.confKey 'game.dev'
repo = pathUtils.resolve pathUtils.dirname root
gitRoot = pathUtils.basename root
git = gift repo
notifications = []
        
describe 'AuthoringService tests', -> 

  before (done) ->
    fs.remove repo, (err) ->
      return done err if err?
      service.init done

  beforeEach (done) ->
    # given a registered notification listener
    notifications = []
    notifier.on notifier.NOTIFICATION, (event, args...) ->
      notifications.push args if event is 'authoring'
    done()

  afterEach (done) ->
    notifier.removeAllListeners notifier.NOTIFICATION
    done()

  it 'should file be created', (done) -> 
    # given a new file
    item = new FSItem 'file.txt', false
    # when saving it 
    service.save item, 'admin', (err, saved) ->
      return done "Cannot save file: #{err}" if err?
      # then the file was saved
      assert.ok item.equals saved
      fs.exists pathUtils.join(root, item.path), (exists) ->
        assert.ok exists, "file #{item.path} wasn't created"
        # then it was added to version control
        git.commits (err, history) ->
          return done "Failed to check git log: #{err}" if err?
          assert.equal 1, history.length
          commit = history[0]
          assert.equal commit.author.name, 'admin'
          assert.equal commit.author.email, 'admin@unknown.org'
          assert.equal commit.message, 'save'

          # then a notification was issued
          assert.equal 1, notifications.length
          notif = notifications[0]
          assert.equal notif[0], 'committed'
          assert.equal notif[1], item.path
          assert.equal notif[2].author, commit.author.name
          assert.equal notif[2].date?.getTime(), commit.committed_date?.getTime()
          assert.equal notif[2].id, commit.id
          assert.equal notif[2].message, commit.message

          commit.tree().find "#{gitRoot}/#{item.path}", (err, obj) ->
            return done "Failed to check git details: #{err}" if err?
            assert.isNotNull obj
            assert.equal obj.name, item.path
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
      fs.exists pathUtils.join(root, item.path), (exists) ->
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
      fs.remove root, ->
        # and some file in it
        async.forEach ['file1.txt', 'file2.txt', 'folder/file3.txt', 'folder/file4.txt'], (file, next) ->
          file = pathUtils.join root, file
          fs.mkdirs pathUtils.dirname(file), (err) ->
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
    file = null
    oldPath = null

    before (done) ->
      fs.remove repo, (err) ->
        return done err if err?
        service.init (err) ->
          return done err if err?
          fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
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
        fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
          return done err if err?
          assert.equal read.content, data.toString('base64')
          done()

    it 'should file content be read at last version', (done) -> 
      service.history file, (err, read, history) ->
        return done err if err?

        # when reading the file at last version
        service.readVersion file, history[0].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
            return done err if err?
            assert.equal content, data.toString('base64')
            done()
        
    it 'should file content be updated', (done) -> 
      # given a binary content
      fs.readFile './hyperion/test/fixtures/image2.png', (err, data) ->
        return done err if err?
        file.content = data
        # when saving it 
        service.save file, 'admin', (err, saved) ->
          return done "Cannot save existing file: #{err}" if err?
          # then the file was saved
          assert.ok file.equals saved
          assert.equal saved.content, data.toString('base64'),
          # then the saved content is equals
          fs.readFile pathUtils.join(root, saved.path), (err, readData) ->
            return done err if err?
            assert.equal readData.toString('base64'), data.toString('base64')
            # then it was the object of two entries in version control
            git.commits (err, history) ->
              return done "Failed to check git log: #{err}" if err?
              assert.equal 2, history.length

              # then a notification was issued
              assert.equal 1, notifications.length
              notif = notifications[0]
              assert.equal notif[0], 'committed'
              assert.equal notif[1], saved.path
              assert.equal notif[2].author, history[0].author.name
              assert.equal notif[2].date?.getTime(), history[0].committed_date?.getTime()
              assert.equal notif[2].id, history[0].id
              assert.equal notif[2].message, history[0].message

              async.forEach history, (commit, next) ->
                assert.equal commit.author.name, 'admin'
                assert.equal commit.author.email, 'admin@unknown.org'
                assert.equal commit.message, 'save'
                commit.tree().find "#{gitRoot}/#{file.path.replace '\\', '/'}", (err, obj) ->
                  return done "Failed to check git details: #{err}" if err?
                  assert.isNotNull obj
                  assert.equal obj.name, pathUtils.dirname file.path
                  next()
              , done

    it 'should file content be read at first version', (done) -> 
      service.history file, (err, read, history) ->
        return done err if err?

        # when reading the file at first version
        service.readVersion file, history[1].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
            return done err if err?
            assert.equal content, data.toString('base64')
            done()

    it 'should file history be consulted', (done) ->
      # when consulting history for this file
      service.history file, (err, read, history) ->
        return done "Cannot get history: #{err}" if err?
        assert.equal 2, history.length
        assert.ok file.equals read
        for i in [0..1]
          assert.instanceOf history[i].date, Date
          assert.equal 'admin', history[i].author
        assert.deepEqual ['save', 'save'], _.pluck history, 'message'
        done()

    it 'should file content be moved', (done) -> 
      # when reading the folder
      oldPath = "#{file.path}"
      service.move file, 'folder5/newFile', 'admin', (err, moved) ->
        return done "Cannot move file: #{err}" if err?
        # then new file is created and old one removed
        assert.notEqual moved.path, oldPath
        fs.exists pathUtils.join(root, moved.path), (exists) ->
          assert.isTrue exists, "file #{file.path} wasn't moved"
          # then content is correct
          fs.readFile pathUtils.join(root, moved.path), (err, data) ->
            assert.equal moved.content, data.toString('base64'),
            fs.exists pathUtils.join(root, oldPath), (exists) ->
              assert.isFalse exists, "file #{oldPath} wasn't removed"
              file = moved
              # then it was registered into version control
              git.commits (err, history) ->
                return done "Failed to check git log: #{err}" if err?
                assert.equal 3, history.length
                commit = history[0]
                assert.equal commit.author.name, 'admin'
                assert.equal commit.author.email, 'admin@unknown.org'
                assert.equal commit.message, 'move'

                # then a notification was issued
                assert.equal 1, notifications.length
                notif = notifications[0]
                assert.equal notif[0], 'committed'
                assert.equal notif[1], moved.path
                assert.equal notif[2].author, commit.author.name
                assert.equal notif[2].date?.getTime(), commit.committed_date?.getTime()
                assert.equal notif[2].id, commit.id
                assert.equal notif[2].message, commit.message

                # then the new path was created
                commit.tree().find "#{gitRoot}/#{moved.path.replace '\\', '/'}", (err, obj) ->
                  return done "Failed to check git details: #{err}" if err?
                  assert.isNotNull obj
                  assert.equal obj.name, pathUtils.dirname moved.path

                  # then the old path was removed
                  commit.tree().find "#{gitRoot}/#{oldPath.replace '\\', '/'}", (err, obj) ->
                    return done "Failed to check git details: #{err}" if err?
                    assert.isNull obj
                    done()

    it 'should file history be be kept after move', (done) ->
      # when consulting history for this file
      service.history file, (err, read, history) ->
        return done "Cannot get history: #{err}" if err?
        assert.equal 3, history.length
        assert.ok file.equals read
        for i in [0..1]
          assert.instanceOf history[i].date, Date
          assert.equal 'admin', history[i].author
        assert.deepEqual ['move', 'save', 'save'], _.pluck history, 'message'
        done()

    it 'should file be removed', (done) -> 
      # when removing the file
      service.remove file, 'admin', (err, removed) ->
        return done "Cannot remove file: #{err}" if err?
        # then the file was removed
        assert.ok file.equals removed
        fs.exists pathUtils.join(root, file.path), (exists) ->
          assert.isFalse exists, "file #{file.path} wasn't removed"

          # then nonotification issued
          assert.equal 0, notifications.length

          # then it was removed from version control
          git.commits (err, history) ->
            return done "Failed to check git log: #{err}" if err?
            assert.equal 4, history.length
            commit = history[0]
            assert.equal commit.author.name, 'admin'
            assert.equal commit.author.email, 'admin@unknown.org'
            assert.equal commit.message, 'remove'
            commit.tree().find "#{gitRoot}/#{file.path.replace '\\', '/'}", (err, obj) ->
              return done "Failed to check git details: #{err}" if err?
              assert.isNull obj
              done()

    it 'should removed file appears in restorable list', (done) ->
      # when consulting history for this file
      service.restorables (err, restorables) ->
        return done "Cannot get restorables: #{err}" if err?
        assert.equal 2, restorables.length
        assert.ok restorables[0].item.equals file, 'deleted file not found as first restorable'
        assert.ok restorables[1].item.equals {path: oldPath}, 'moved file not found as second restorable'
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
          item = new FSItem pathUtils.join(folder.path, file), false
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
        fs.exists pathUtils.join(root, moved.path), (exists) ->
          assert.isTrue exists, "folder #{folder.path} wasn't moved"
          fs.exists pathUtils.join(root, oldPath), (exists) ->
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
        fs.exists pathUtils.join(root, folder.path), (exists) ->
          assert.isFalse exists, "folder #{folder.path} wasn't removed"
          done()