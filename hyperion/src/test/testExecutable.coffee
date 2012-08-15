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

Executable = require '../main/model/Executable'
testUtils = require './utils/testUtils'
utils = require '../main/utils'
path = require 'path'
fs = require 'fs'
assert = require('chai').assert

executable = null
   
root =  utils.confKey 'executable.source'

describe 'Executable tests', -> 

  beforeEach (done) ->
    # Empty the source and compilation folders content
    testUtils.cleanFolder root, (err) -> 
      throw new Error err if err?
      Executable.resetAll (err) -> 
        throw new Error err if err?
        done()
      
  it 'should executable be created', (done) -> 
    # given a new executable
    content = 'console.log "hello world"'
    name = 'test1'
    executable = new Executable {_id: name, content: content}
    
    # when saving it
    executable.save (err) ->
      throw new Error "Can't save executable: #{err}" if err?

      # then it is in the file system
      Executable.find (err, executables) ->
        throw new Error "Can't find executable: #{err}" if err?

        # then it's the only one executable
        assert.equal executables.length, 1
        # then it's values were saved
        assert.equal executables[0]._id, name
        assert.equal executables[0].content, content
        done()

  describe 'given an executable', -> 

    beforeEach (done) ->
      executable = new Executable {_id:'test2', content:'console.log("hello world 2");'}
      executable.save (err) ->
        done()

    it 'should executable be removed', (done) ->
      # when removing an executable
      executable.remove ->
        # then it's in the folder anymore
        Executable.find (err, executables) -> 
          throw new Error "Can't find executable file: #{err}" if err?
          assert.equal executables.length, 0
          done()

    it 'should executable be updated', (done) ->
      # when modifying and saving a executable
      newContent = '# I have accents ! ééàà'
      executable.content = newContent
      executable.save ->
        Executable.find (err, executables) ->
          throw new Error "Can't find executable file: #{err}" if err?
          # then it's the only one executable
          assert.equal executables.length, 1
          # then only the relevant values were modified
          assert.equal executables[0].content, newContent
          assert.equal executables[0]._id, 'test2'
          done()