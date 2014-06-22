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

Field = require '../hyperion/src/model/Field'
FieldType = require '../hyperion/src/model/FieldType'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
assert = require('chai').assert

type = null

describe 'FieldType tests', -> 

  beforeEach (done) ->
    # empty fields and types.
    Field.collection.drop -> FieldType.collection.drop -> FieldType.loadIdCache done

  it 'should type be created', (done) -> 
    # given a new FieldType
    id = 'montain'
    type = new FieldType id: id

    # when saving it
    type.save (err, saved) ->
      throw new Error "Can't save type: #{err}" if err?

      # then it is in mongo
      FieldType.find {}, (err, types) ->
        # then it's the only one document
        assert.equal types.length, 1
        # then it's values were saved
        assert.equal types[0].id, id
        done()

  describe 'given a type', ->
    beforeEach (done) ->
      # creates a type with a property color which is a string.
      new FieldType({id: 'river'}).save (err, saved) -> 
        return done err if err?
        type = saved
        done()

    afterEach (done) ->
      # removes the type at the end.
      FieldType.collection.drop -> Field.collection.drop -> FieldType.loadIdCache done

    it 'should type be removed', (done) ->
      # when removing an field
      type.remove (err) ->
        return done err if err?
        # then it's in mongo anymore
        FieldType.find {}, (err, types) ->
          return done err if err?
          assert.equal types.length, 0
          done()