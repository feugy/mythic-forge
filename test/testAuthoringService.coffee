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

_ = require 'underscore'
async = require 'async'
{join, dirname, resolve, normalize, sep} = require 'path'
{expect} = require 'chai'
fs = require 'fs-extra'
FSItem = require '../hyperion/src/model/FSItem'
Executable = require '../hyperion/src/model/Executable'
utils = require '../hyperion/src/util/common'
versionService = require('../hyperion/src/service/VersionService').get()
service = require('../hyperion/src/service/AuthoringService').get()
notifier = require('../hyperion/src/service/Notifier').get()

repoRoot = resolve normalize utils.confKey 'game.repo'
gameFiles = resolve normalize utils.confKey 'game.client.dev'
gameRules = resolve normalize utils.confKey 'game.executable.source'
file = null
oldPath = null
notifications = []
        
describe 'AuthoringService tests', -> 

  before (done) ->
    @timeout 3000
    # re-initialize game repository
    versionService.init true, (err) ->
      return done err if err?
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
    service.save item, (err, saved) ->
      return done "Cannot save file: #{err}" if err?
      # then the file was saved
      expect(saved).to.satisfy (o) -> item.equals o
      fs.exists join(gameFiles, item.path), (exists) ->
        expect(exists, "file #{item.path} wasn't created").to.be.true
        done()

  it 'should folder be created', (done) -> 
    # given a new file
    item = new FSItem "folder", true
    # when saving it 
    service.save item, (err, saved) ->
      return done "Cannot save folder: #{err}" if err?
      # then nonotification issued
      expect(notifications).to.have.lengthOf 0

      # then the file was saved
      expect(saved).to.satisfy (o) -> item.equals o
      fs.exists join(gameFiles, item.path), (exists) ->
        expect(exists, "folder #{item.path} wasn't created").to.be.true
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
        expect(folder).to.have.property('content').that.has.lengthOf content.length
        for file in content
          found = false
          for result in folder.content when result.equals file
            found = true
            break
          expect(found, "file #{file.path} was not read").to.be.true
        done()

  describe 'given an existing file', ->

    before (done) ->
      fs.readFile join(__dirname, 'fixtures', 'image1.png'), (err, data) ->
        return done err if err?
        file = new FSItem 'folder/image1.png', false
        file.content = data
        service.save file, (err, saved) ->
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
          expect(read).to.have.property('content').that.is.equal data.toString 'base64'
          done()
        
    it 'should file content be updated', (done) -> 
      # given a binary content
      fs.readFile join(__dirname, 'fixtures', 'image2.png'), (err, data) ->
        return done err if err?
        file.content = data
        # when saving it 
        service.save file, (err, saved) ->
          return done "Cannot save existing file: #{err}" if err?
          # then the file was saved
          expect(saved).to.satisfy (o) -> file.equals o
          expect(saved).to.have.property('content').that.is.equal data.toString 'base64'
          # then the saved content is equals
          fs.readFile join(gameFiles, saved.path), (err, readData) ->
            return done err if err?
            expect(readData.toString 'base64').to.equal data.toString 'base64'
            done()

    it 'should file content be moved', (done) -> 
      # when reading the folder
      oldPath = "#{file.path}"
      service.move file, 'folder5/newFile', (err, moved) ->
        return done "Cannot move file: #{err}" if err?
        # then new file is created
        expect(moved).to.have.property('path').that.is.not.equal oldPath
        fs.exists join(gameFiles, moved.path), (exists) ->
          expect(exists, "file #{file.path} wasn't moved").to.be.true
          # then content is correct
          fs.readFile join(gameFiles, moved.path), (err, data) ->
            expect(moved).to.have.property('content').that.is.equal data.toString('base64'),
            # then old one removed
            fs.exists join(gameFiles, oldPath), (exists) ->
              expect(exists, "file #{oldPath} wasn't removed").to.be.false
              file = moved
              done()

    it 'should file be removed', (done) -> 
      # when removing the file
      service.remove file, (err, removed) ->
        return done "Cannot remove file: #{err}" if err?
        # then the file was removed
        expect(removed).to.satisfy (o) -> file.equals o
        fs.exists join(gameFiles, file.path), (exists) ->
          expect(exists, "file #{file.path} wasn't removed").to.be.false
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
            service.save file, (err, saved) ->
              return done err if err?
              executable = new Executable id: 'test', content: exeContent1
              executable.save (err) ->
                return done err if err?
                # first commit
                versionService.repo.add [gameFiles.replace(repoRoot+sep, ''), gameRules.replace(repoRoot+sep, '')], {A: true}, (err) ->
                  return done err if err?
                  versionService.repo.commit 'first commit', (err) ->
                    return done err if err?
                    # second version of file and executable
                    fs.readFile join(__dirname, 'fixtures', 'common.coffee.v2'), (err, data) ->
                      return done err if err?
                      file.content = data
                      service.save file, (err, saved) ->
                        return done err if err?
                        executable.content = exeContent2
                        executable.save (err) ->
                          return done err if err?
                          # second commit
                          versionService.repo.add [gameFiles.replace(repoRoot+sep, ''), gameRules.replace(repoRoot+sep, '')], {A: true}, (err) ->
                            return done err if err?
                            versionService.repo.commit 'second commit', done

    it 'should file content be read at last version', (done) -> 
      service.history file, (err, read, history) ->
        return done err if err?
        expect(history).to.have.lengthOf 2
        expect(history[0]).to.have.property('message').that.is.equal 'second commit'

        # when reading the file at last version
        service.readVersion file, history[0].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          fs.readFile join(__dirname, 'fixtures', 'common.coffee.v2'), (err, data) ->
            return done err if err?
            expect(content).to.equal data.toString 'base64'
            done()

    it 'should executable content be read at last version', (done) -> 
      service.history executable, (err, read, history) ->
        return done err if err?
        expect(history).to.have.lengthOf 2
        expect(history[0]).to.have.property('message').that.is.equal 'second commit'

        # when reading the executable at last version
        service.readVersion executable, history[0].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          expect(read).to.satisfy (o) -> executable.equals o
          expect(content).to.equal new Buffer(exeContent2).toString 'base64'
          done()

    it 'should file content be read at first version', (done) -> 
      service.history file, (err, read, history) ->
        return done err if err?
        expect(history).to.have.lengthOf 2
        expect(history[1]).to.have.property('message').that.is.equal 'first commit'

        # when reading the file at first version
        service.readVersion file, history[1].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          fs.readFile join(__dirname, 'fixtures', 'common.coffee.v1'), (err, data) ->
            return done err if err?
            expect(content).to.equal data.toString 'base64'
            done()

    it 'should executable content be read at first version', (done) -> 
      service.history executable, (err, read, history) ->
        return done err if err?
        expect(history).to.have.lengthOf 2
        expect(history[1]).to.have.property('message').that.is.equal 'first commit'

        # when reading the file at first version
        service.readVersion executable, history[1].id, (err, read, content) ->
          return done "Cannot read file at version: #{err}" if err?
          # then read data is correct
          expect(read).to.satisfy (o) -> executable.equals o
          expect(content).to.equal new Buffer(exeContent1).toString 'base64'
          done()

    it 'should file history be consulted', (done) ->
      # when consulting history for this file
      service.history file, (err, read, history) ->
        return done "Cannot get history: #{err}" if err?
        expect(history).to.have.lengthOf 2
        expect(read).to.satisfy (o) -> file.equals o
        for i in [0..1]
          expect(history[i]).to.have.property('date').that.is.an.instanceOf Date
          expect(history[i]).to.have.property('author').that.is.equal 'mythic-forge'
        expect(_.pluck history, 'message').to.deep.equal ['second commit', 'first commit'], 
        done()

    it 'should executable history be consulted', (done) ->
      # when consulting history for this file
      service.history executable, (err, read, history) ->
        return done "Cannot get history: #{err}" if err?
        expect(read).to.satisfy (o) -> executable.equals o
        expect(history).to.have.lengthOf 2
        for i in [0..1]
          expect(history[i]).to.have.property('date').that.is.an.instanceOf Date
          expect(history[i]).to.have.property('author').that.is.equal 'mythic-forge'
        expect(_.pluck history, 'message').to.deep.equal ['second commit', 'first commit'], 
        done()

    it 'should removed file and executable appears in restorable list', (done) ->
      # given a removed file
      service.remove file, (err) ->
        return done err if err?
        executable.remove (err) ->
          return done err if err?
          versionService.repo.add [gameFiles.replace(repoRoot+sep, ''), gameRules.replace(repoRoot+sep, '')], {A: true}, (err) ->
            return done err if err?
            versionService.repo.commit 'third commit', (err) ->
              return done err if err?
              # when consulting history for this file
              service.restorables [], (err, restorables) ->
                return done "Cannot get restorables: #{err}" if err?
                expect(restorables).to.have.lengthOf 2
                expect(restorables[1], 'deleted file not found as second restorable').to.have.property('item').that.satisfy (o) -> file.equals o
                expect(restorables[0], 'deleted executable not found as first restorable').to.have.property('item').that.satisfy (o) -> executable.equals o
                done()

  describe 'given an existing folder', ->
    folder = null
    files = []

    before (done) ->
      folder = new FSItem 'folder/folder2', true
      service.save folder, (err, saved) ->
        return done err if err?
        folder = saved
        async.forEachSeries ['file1.txt', 'file2.txt'], (file, next) ->
          item = new FSItem join(folder.path, file), false
          files.push item
          service.save item, next
        , (err) ->
          return done err if err?
          done()

    it 'should folder content be read', (done) -> 
      folder.content = null
      # when reading the folder
      service.read folder, (err, read) ->
        return done "Cannot read folder: #{err}" if err?
        # then read data is correct
        expect(read).to.have.property('content').that.has.lengthOf files.length
        for file in read.content
          found = false
          for content in read.content when content.equals file
            found = true
            break
          expect(found, "file #{file.path} was not read").to.be.true
        done()

    it 'should folder content be moved', (done) -> 
      # when reading the folder
      oldPath = "#{folder.path}"
      service.move folder, 'folder3/folder4', (err, moved) ->
        return done "Cannot move folder: #{err}" if err?
        # then new folder is created and old one removed
        expect(moved).to.have.property('path').that.is.not.equal oldPath
        fs.exists join(gameFiles, moved.path), (exists) ->
          expect(exists, "folder #{folder.path} wasn't moved").to.be.true
          fs.exists join(gameFiles, oldPath), (exists) ->
            expect(exists, "folder #{oldPath} wasn't removed").to.be.false
            folder = moved
            done()

    it 'should folder be removed', (done) -> 
      # when removing the folder
      service.remove folder, (err, removed) ->
        return done "Cannot remove folder: #{err}" if err?
        # then nonotification issued
        expect(notifications).to.have.lengthOf 0

        # then the file was removed
        expect(removed).to.satisfy (o) -> folder.equals o
        fs.exists join(gameFiles, folder.path), (exists) ->
          expect(exists, "folder #{folder.path} wasn't removed").to.be.false
          done()