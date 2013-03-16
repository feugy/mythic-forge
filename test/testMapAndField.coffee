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

Map = require '../hyperion/src/model/Map'
Field = require '../hyperion/src/model/Field'
FieldType = require '../hyperion/src/model/FieldType'
watcher = require('../hyperion/src/model/ModelWatcher').get()
testUtils = require './utils/testUtils'
typeFactory = require '../hyperion/src/model/typeFactory'
assert = require('chai').assert

awaited = false

fieldType = null
map = null

describe 'Map and Field tests', -> 

  beforeEach (done) ->
    Map.collection.drop -> Field.collection.drop -> FieldType.collection.drop -> Map.loadIdCache -> 
      new FieldType({id: 'plain'}).save (err, saved) ->
        return done err if err?
        fieldType = saved
        done()

  it 'should map be created', (done) -> 
    # given a new map
    map = new Map {id: 'map1'}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal 'Map', className
      assert.equal 'creation', operation
      assert.ok map.equals instance
      awaited = true

    # when saving it
    awaited = false
    map.save (err) ->
      return done "Can't save map: #{err}" if err?

      # then it is in mongo
      Map.find {}, (err, docs) ->
        return done "Can't find map: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal docs[0].id,  'map1'
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  describe 'given a map', ->

    beforeEach (done) ->
      map = new Map {id: 'map2'}
      map.save -> done()

    it 'should map be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Map'
        assert.equal operation, 'deletion'
        assert.ok map.equals instance
        awaited = true

      # when removing a map
      awaited = false
      map.remove ->

        # then it's not in mongo anymore
        Map.find {}, (err, docs) ->
          assert.equal docs.length, 0
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should map be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Map'
        assert.equal operation, 'update'
        assert.ok map.equals instance
        assert.equal instance.id, 'map2'
        assert.equal instance.kind, 'square'
        awaited = true

      # when modifying and saving an item
      map.kind= 'square'
      awaited = false
      map.save ->

        Map.find {}, (err, docs) ->
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal docs[0].id, 'map2'
          assert.equal docs[0].kind, 'square'
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should field be created', (done) ->
      # when creating a field on the map
      field = new Field {mapId:map.id, typeId:fieldType.id, x:0, y:0}
      field.save (err)->
        return done "Can't save field: #{err}" if err?
        # then its retrievable by map
        Field.find {mapId: map.id}, (err, fields) ->
          return done "Can't find field by map: #{err}" if err?
          assert.equal fields.length, 1
          assert.ok field.equals fields[0]
          assert.equal fields[0].mapId, map.id
          assert.equal fields[0].x, 0
          assert.equal fields[0].y, 0
          done()

    it 'should field be removed', (done) ->
      # given an exiting a field on the map
      field = new Field {mapId:map.id, typeId:fieldType.id, x:10, y:10}
      field.save (err)->
        return done "Can't save field: #{err}" if err?
        # when removing it
        field.remove (err) ->
          return done "Can't remove field: #{err}" if err?
          # then it's not in the map anymore
          Field.findOne {_id: field.id}, (err, field) ->
            return done "Can't find field by id: #{err}" if err?
            assert.ok field is null
            done()

    it 'should field cannot be updated', (done) ->
      # given an exiting a field on the map
      field = new Field {mapId:map.id, typeId:fieldType.id, x:10, y:10}
      field.save (err)->
        return done "Can't save field: #{err}" if err?
        # when updating it
        field.x= 20
        field.save (err) ->
          assert.ok err isnt null
          assert.equal err.message, 'only creations are allowed on fields', "Unexpected error: #{err}"
          done()

    it 'should field be removed with map', (done) ->
      # given some fields on the map
      new Field(mapId:map.id, typeId:fieldType.id, x:10, y:10).save (err) ->
        return done err if err?
        new Field(mapId:map.id, typeId:fieldType.id, x:5, y:5).save (err) ->
          return done err if err?
          Field.find {mapId: map.id}, (err, fields) ->
            return done err if err?
            assert.equal fields.length, 2

            changes = []
            # then only a removal event was issued
            watcher.on 'change', listener = (operation, className, instance)->
              changes.push arguments

            # when removing the map
            map.remove (err) ->
              return done "Failed to remove map: #{err}" if err?

              # then fields are not in mongo anymore
              Field.find {mapId: map.id}, (err, fields) ->
                return done err if err?
                assert.equal fields.length, 0
                assert.equal 1, changes.length, 'watcher wasn\'t invoked'
                assert.equal changes[0][1], 'Map'
                assert.equal changes[0][0], 'deletion'
                watcher.removeListener 'change', listener
                done()