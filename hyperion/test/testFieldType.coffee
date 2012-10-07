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

Field = require '../src/model/Field'
FieldType = require '../src/model/FieldType'
watcher = require('../src/model/ModelWatcher').get()
assert = require('chai').assert

type = null

describe 'FieldType tests', -> 

  beforeEach (done) ->
    # empty fields and types.
    Field.collection.drop -> FieldType.collection.drop -> done()

  it 'should type be created', (done) -> 
    # given a new FieldType
    type = new FieldType()
    name = 'montain'
    type.set 'name', name

    # when saving it
    type.save (err, saved) ->
      throw new Error "Can't save type: #{err}" if err?

      # then it is in mongo
      FieldType.find {}, (err, types) ->
        # then it's the only one document
        assert.equal types.length, 1
        # then it's values were saved
        assert.equal types[0].get('name'), name
        done()

  it 'should name and desc be internationalizables', (done) -> 
    # given a new FieldType with translated name
    type = new FieldType()
    name = 'dust'
    type.set 'name', name
    type.locale = 'fr'
    nameFr = 'poussière'
    type.set 'name', nameFr

    # when saving it
    type.save (err, saved) ->
      throw new Error "Can't save type: #{err}" if err?

      # then translations are available
      saved.locale = null
      assert.equal saved.get('name'), name
      saved.locale = 'fr'
      assert.equal saved.get('name'), nameFr

      # when setting the tanslated description and saving it
      saved.locale = null
      desc = 'another one bites the dust'
      saved.set 'desc', desc
      saved.locale = 'fr'
      descFr = 'encore un qui mort la poussière' 
      saved.set 'desc', descFr

      saved.save (err, saved) ->
        throw new Error "Can't save type: #{err}" if err?

        # then it is in mongo
        FieldType.find {}, (err, types) ->
          # then it's the only one document
          assert.equal 1, types.length
          # then it's values were saved
          assert.equal types[0].get('name'), name
          assert.equal types[0].get('desc'), desc
          types[0].locale = 'fr'
          assert.equal types[0].get('name'), nameFr
          assert.equal types[0].get('desc'), descFr
          done()

  describe 'given a type', ->
    beforeEach (done) ->
      # creates a type with a property color which is a string.
      new FieldType({name: 'river'}).save (err, saved) -> 
        type = saved
        done()

    afterEach (done) ->
      # removes the type at the end.
      FieldType.collection.drop -> Field.collection.drop -> done()

    it 'should type be removed', (done) ->
      # when removing an field
      type.remove (err) ->
        return done err if err?
        # then it's in mongo anymore
        FieldType.find {}, (err, types) ->
          return done err if err?
          assert.equal types.length, 0
          done()