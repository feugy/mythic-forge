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

Executable = require '../hyperion/src/model/Executable'
watcher = require('../hyperion/src/model/ModelWatcher').get()
utils = require '../hyperion/src/util/common'
pathUtils = require 'path'
fs = require 'fs'
{expect} = require 'chai'

executable = null
listener = null
root =  utils.confKey 'game.executable.source'

describe 'Executable tests', -> 

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
    content = 'greetings = "hello world"'
    id = 'test1'
    executable = new Executable id: id, content: content
    
    awaited = false

    # then a creation event was issued
    listener = (operation, className, instance) ->
      if operation is 'creation' and className is 'Executable'
        expect(executable).to.satisfy (o) => o.equals instance
        awaited = true
    watcher.on 'change', listener

    # when saving it
    executable.save (err) ->
      return done "Can't save executable: #{err}" if err?

      # then it is in the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then it's the only one executable
        expect(executables).to.have.lengthOf 1
        # then it's values were saved
        expect(executables[0]).to.have.property('id').that.equal id
        expect(executables[0]).to.have.property('content').that.equal content
        expect(executables[0]).to.have.property('lang').that.equal 'coffee'
        expect(executables[0]).to.have.property 'updated'
        expect(executables[0].updated.getTime()).to.be.equal new Date().setMilliseconds 0
        expect(executables[0].meta).to.deep.equal kind: 'Script'
        expect(awaited, 'watcher was\'nt invoked for new executable').to.be.true
        done()

  it 'should js executable be created', (done) ->
    # given a JS new executable
    content = '(function() {var greetings = "hello world";})()'
    id = 'test5'
    executable = new Executable id: id, lang: 'js', content: content

    awaited = false

    # then a creation event was issued
    listener = (operation, className, instance) ->
      if operation is 'creation' and className is 'Executable'
        expect(executable).to.satisfy (o) => o.equals instance
        awaited = true
    watcher.on 'change', listener

    # when saving it
    executable.save (err) ->
      return done "Can't save executable: #{err}" if err?

      # then it is in the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then it's the only one executable
        expect(executables).to.have.lengthOf 1
        # then it's values were saved
        expect(executables[0]).to.have.property('id').that.equal id
        expect(executables[0]).to.have.property('content').that.equal content
        expect(executables[0]).to.have.property('lang').that.equal 'js'
        expect(executables[0]).to.have.property 'updated'
        expect(executables[0].updated.getTime()).to.be.equal new Date().setMilliseconds 0
        expect(executables[0].meta).to.deep.equal kind: 'Script'
        expect(awaited, 'watcher was\'nt invoked for new executable').to.be.true
        done()
        
  it 'should executable compilation error be reported', (done) -> 
    # given a new executable with compilation error
    content = 'console. "hello world"'
    id = 'test3'
    executable = new Executable id: id, content: content
    
    # when saving it
    executable.save (err) ->
      # then an error is reported
      expect(err).to.include 'unexpected "hello world"'

      # then it's not on the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then no executables found
        expect(executables).to.have.lengthOf 0
        done()

  it 'should js executable compilation error be reported', (done) -> 
    # given a new executable with compilation error
    content = 'console.("hello world");'
    id = 'test3'
    executable = new Executable id: id, lang:'js', content: content
    
    # when saving it
    executable.save (err) ->
      # then an error is reported
      expect(err).to.include "Expected an identifier and instead saw '('."

      # then it's not on the file system
      Executable.find (err, executables) ->
        return done "Can't find executable: #{err}" if err?

        # then no executables found
        expect(executables).to.have.lengthOf 0
        done()
      
  it 'should resetAll recompile all in once', (done) ->
    # given two interdependant scripts
    new Executable(id: 'first', content: 'module.exports = -> console.log "hello world"').save (err) ->
      return done "Can't save first executable: #{err}" if err?

      new Executable(id: 'second', content: 'require("./first")()').save (err) ->
        return done "Can't save second executable: #{err}" if err?

        # when reseting
        Executable.resetAll true, (err) ->
          return done "Failed to reset all executable: #{err}" if err?
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
      executable.save (err) ->
        # wait a little to avoid to fast save+update that prevent 'updated' to be detected as modified
        setTimeout (-> done err), 10

    it 'should executable be removed', (done) ->
      # when removing an executable
      executable.remove ->
        # then it's in the folder anymore
        Executable.find (err, executables) -> 
          return done "Can't find executable file: #{err}" if err?
          expect(executables).to.have.lengthOf 0
          done()

    it 'should executable be updated', (done) ->
      execChanges = null

      # then a creation event was issued
      listener = (operation, className, changes) ->
        if operation is 'update' and className is 'Executable'
          execChanges = changes
      watcher.on 'change', listener

      # when modifying and saving a executable
      newContent = '# I have accents ! ééàà'
      executable.content = newContent
      creation = executable.updated
      executable.save ->
        Executable.find (err, executables) ->
          return done "Can't find executable file: #{err}" if err?
          # then it's the only one executable
          expect(executables).to.have.lengthOf 1
          # then only the relevant values were modified
          expect(executables[0]).to.have.property('id').that.equal 'test2'
          expect(executables[0]).to.have.property('content').that.equal newContent
          expect(executables[0].meta).to.deep.equal kind: 'Script'
          # then update date was modified
          expect(executables[0].updated).not.to.equal creation
          expect(executables[0].updated.getTime()).to.be.equal new Date().setMilliseconds 0
          expect(execChanges, "watcher was't invoked for executable: #{execChanges}").to.exist
          done()

    it 'should executable be removed', (done) ->
      # when removing an executable
      executable.remove ->
        # then it's in the folder anymore
        Executable.find (err, executables) -> 
          return done "Can't find executable file: #{err}" if err?
          expect(executables).to.have.lengthOf 0
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
        expect(result).to.equal 20
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
          expect(result).to.equal 30
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
        expect(result).to.have.property 'findCached'
        expect(new result()).to.have.property('_className').that.equal 'Item'
        done()

    it 'should executable meta for Rule contains category and active', (done) ->
      # given an executable with an inactive Rule 'cat3' category
      executable = new Executable 
        id: 'test5'
        content: """Rule = require 'hyperion/model/Rule'
            module.exports = new (class Dumb extends Rule
              constructor: ->
                @category = 'cat3'
                @active = false
            )() """
      executable.save (err) ->
        return done err if err?
        expect(executable.meta).to.deep.equal 
          kind: 'Rule'
          category: 'cat3'
          active: false
        done()

    it 'should executable meta for TurnRule contains rank and active', (done) ->
      # given an executable with an active TurnRule rank 10
      executable = new Executable 
          id:'test6', 
          content: """TurnRule = require 'hyperion/model/TurnRule'
            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @rank = 10
            )() """
      executable.save (err) ->
        return done err if err?
        expect(executable.meta).to.deep.equal 
          kind: 'TurnRule'
          rank: 10
          active: true
        done()

    it 'should executable meta for be updated', (done) ->
      # given an executabl with metas
      executable = new Executable 
          id:'test7', 
          content: """TurnRule = require 'hyperion/model/TurnRule'
            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @active = false
            )() """
      executable.save (err) ->
        return done err if err?
        expect(executable.meta).to.deep.equal 
          kind: 'TurnRule'
          rank: 0
          active: false
        execChanges = null

        # then a update event was issued
        listener = (operation, className, changes) ->
          execChanges = changes if operation is 'update' and className is 'Executable'
        watcher.on 'change', listener
        # when saving content new values
        executable.content = """TurnRule = require 'hyperion/model/TurnRule'
            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @active = true
                @rank = 5
            )() """

        executable.save (err) ->
          return done err if err?

          # then metas were updated
          expect(executable.meta).to.deep.equal 
            kind: 'TurnRule'
            rank: 5
            active: true
          expect(execChanges, "watcher was't invoked for executable: #{execChanges}").to.exist
          expect(execChanges).to.have.property 'meta'
          done()