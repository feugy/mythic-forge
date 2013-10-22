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

Executable = require '../hyperion/src/model/Executable'
ClientConf = require '../hyperion/src/model/ClientConf'
watcher = require('../hyperion/src/model/ModelWatcher').get()
utils = require '../hyperion/src/util/common'
pathUtils = require 'path'
fs = require 'fs'
assert = require('chai').assert

executable = null
listener = null
root =  utils.confKey 'executable.source'

describe.only 'Executable tests', -> 

  beforeEach (done) ->
    # Empty the source and compilation folders content
    utils.empty root, (err) -> 
      return done err if err?
      Executable.resetAll true, (err) ->
        return done err if err?
        done()

  afterEach (done) ->
    # remove all listeners
    watcher.removeListener 'change', listener if listener?
    done()

  it 'should executable be created', (done) -> 
    # given a new executable
    content = 'console.log "hello world"'
    id = 'test1'
    executable = new Executable id: id, content: content
    
    awaited = false
    confChanged = false

    # then a creation event was issued
    listener = (operation, className, instance) ->
      if operation is 'update' and className is 'ClientConf'
        confChanged = true
      else if operation is 'creation' and className is 'Executable'
        assert.ok executable.equals instance
        awaited = true
    watcher.on 'change', listener

    # when saving it
    executable.save (err) ->
      return done "Can't save executable: #{err}" if err?

      # then it is in the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then it's the only one executable
        assert.equal executables.length, 1
        # then it's values were saved
        assert.equal executables[0].id, id
        assert.equal executables[0].content, content
        assert.equal executables[0].lang, 'coffee'
        # then a new configuration key was added
        ClientConf.findById 'default', (err, conf) ->
          err = 'not found' unless err? or conf?
          return done "Failed to get conf: #{err}" if err?
          assert.equal conf.values?.names?[id], id
          assert.isTrue awaited, 'watcher was\'nt invoked for new executable'
          assert.isTrue confChanged, 'watcher was\'nt invoked for configuration'
          done()

  it 'should js executable be created', (done) ->
    # given a JS new executable
    content = '(function() {console.log("hello world");})()'
    id = 'test5'
    executable = new Executable id: id, lang: 'js', content: content

    awaited = false
    confChanged = false

    # then a creation event was issued
    listener = (operation, className, instance) ->
      if operation is 'update' and className is 'ClientConf'
        confChanged = true
      else if operation is 'creation' and className is 'Executable'
        assert.ok executable.equals instance
        awaited = true
    watcher.on 'change', listener

    # when saving it
    executable.save (err) ->
      return done "Can't save executable: #{err}" if err?

      # then it is in the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then it's the only one executable
        assert.equal executables.length, 1
        # then it's values were saved
        assert.equal executables[0].id, id
        assert.equal executables[0].content, content
        assert.equal executables[0].lang, 'js'
        # then a new configuration key was added
        ClientConf.findById 'default', (err, conf) ->
          err = 'not found' unless err? or conf?
          return done "Failed to get conf: #{err}" if err?
          assert.equal conf.values?.names?[id], id
          assert.isTrue awaited, 'watcher was\'nt invoked for new executable'
          assert.isTrue confChanged, 'watcher was\'nt invoked for configuration'
          done()
        
  it 'should executable compilation error be reported', (done) -> 
    # given a new executable with compilation error
    content = 'console. "hello world"'
    id = 'test3'
    executable = new Executable id: id, content: content
    
    # when saving it
    executable.save (err) ->
      # then an error is reported
      assert.include err, "Unexpected 'STRING'"

      # then it's not on the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then no executables found
        assert.equal executables.length, 0
        done()

  it 'should js executable compilation error be reported', (done) -> 
    # given a new executable with compilation error
    content = 'console.("hello world");'
    id = 'test3'
    executable = new Executable id: id, lang:'js', content: content
    
    # when saving it
    executable.save (err) ->
      # then an error is reported
      assert.include err, "Expected an identifier and instead saw '('."

      # then it's not on the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then no executables found
        assert.equal executables.length, 0
        done()
      
  describe 'given an executable', -> 

    beforeEach (done) ->
      executable = new Executable 
        id: 'test2'
        content:"""
          constant = 10
          module.exports = 
            constant: constant, 
            utility: (num) -> constant+num"""
      executable.save done

    it 'should executable be removed', (done) ->
      # when removing an executable
      executable.remove ->
        # then it's in the folder anymore
        Executable.find (err, executables) -> 
          return done "Can't find executable file: #{err}" if err?
          assert.equal executables.length, 0
          done()

    it 'should executable be updated', (done) ->      
      confChanged = false

      # then a creation event was issued
      listener = (operation, className, instance) ->
        return unless operation is 'update' and className is 'ClientConf'
        confChanged = true 
      watcher.on 'change', listener

      # when modifying and saving a executable
      newContent = '# I have accents ! ééàà'
      executable.content = newContent
      executable.save ->
        Executable.find (err, executables) ->
          return done "Can't find executable file: #{err}" if err?
          # then it's the only one executable
          assert.equal executables.length, 1
          # then only the relevant values were modified
          assert.equal executables[0].content, newContent
          assert.equal executables[0].id, 'test2'
          assert.isFalse confChanged, 'watcher was invoked for client configuration'
          done()

    it 'should executable be removed', (done) ->
      # when removing an executable
      executable.remove ->
        # then it's in the folder anymore
        Executable.find (err, executables) -> 
          return done "Can't find executable file: #{err}" if err?
          assert.equal executables.length, 0
          done()

    it 'should depending executable show updates', (done) ->
      # given another executable depending on the existing one
      ex2 = new Executable 
        id: 'test3'
        content:"""
          ex1 = require './test2'
          module.exports = ex1.utility 10
        """
      ex2.save (err) ->
        return done err if err?
        result = require pathUtils.relative __dirname, ex2.compiledPath
        assert.equal result, 20
        # when modifying existing executable
        newContent = """
          constant = 20
          module.exports = 
            constant: constant, 
            utility: (num) -> constant+num
          """
        executable.content = newContent
        executable.save (err) ->
          return done err if err?
          # then depending executable was reloaded
          result = require pathUtils.relative __dirname, ex2.compiledPath
          assert.equal result, 30
          done()

    it 'should dependencies to hyperion modules be replaced', (done) ->
      # given another executable depending on the existing one
      executable = new Executable 
        id: 'test4'
        content:"""
          require('hyperion/util/logger').getLogger 'rule'
          module.exports = require 'hyperion/model/Item'
        """
      executable.save (err) ->
        return done err if err?
        result = require pathUtils.relative __dirname, executable.compiledPath
        assert.property result, 'findCached'
        assert.equal new result()._className, 'Item'
        done()