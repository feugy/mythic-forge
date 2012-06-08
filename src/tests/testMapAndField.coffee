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
###

Map = require '../main/model/Map'
Field = require '../main/model/Field'
watcher = require('../main/model/ModelWatcher').get()

map = null

module.exports = 
  setUp: (end) ->
    Map.collection.drop -> Field.collection.drop -> end()

  'should map be created': (test) -> 
    # given a new map
    map = new Map {name: 'map1'}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      test.equal 'Map', className
      test.equal 'creation', operation
      test.ok map.equals instance

    # when saving it
    map.save (err) ->
      throw new Error "Can't save map: #{err}" if err?

      # then it is in mongo
      Map.find {}, (err, docs) ->
        throw new Error "Can't find map: #{err}" if err?
        # then it's the only one document
        test.equal docs.length, 1
        # then it's values were saved
        test.equal 'map1', docs[0].get 'name'
        test.expect 5
        test.done()

  'given a map': 
    setUp: (end) ->
      map = new Map {name: 'map2'}
      map.save -> end()

    'should map be removed': (test) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        test.equal 'Map', className
        test.equal 'deletion', operation
        test.ok map.equals instance

      # when removing a map
      map.remove ->

        # then it's not in mongo anymore
        Map.find {}, (err, docs) ->
          test.equal docs.length, 0
          test.expect 4
          test.done()

    'should map be updated': (test) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        test.equal 'Map', className
        test.equal 'update', operation
        test.ok map.equals instance
        test.equal 'map3', instance.name

      # when modifying and saving an item
      map.set 'name', 'map3'
      map.save ->

        Map.find {}, (err, docs) ->
          # then it's the only one document
          test.equal docs.length, 1
          # then only the relevant values were modified
          test.equal 'map3', docs[0].get 'name'
          test.expect 6
          test.done()

    'should field be created': (test) ->
      # when creating a field on the map
      field = new Field {map:map, x:0, y:0}
      field.save (err)->
        throw new Error "Can't save field: #{err}" if err?
        # then its retrievable by map
        Field.find {map: map._id}, (err, fields) ->
          throw new Error "Can't find field by map: #{err}" if err?
          test.equal 1, fields.length
          test.ok field.equals fields[0]
          test.ok map.equals fields[0].get 'map'
          test.equal 0, fields[0].get 'x'
          test.equal 0, fields[0].get 'y'
          test.done()

    'should field be removed': (test) ->
      # given an exiting a field on the map
      field = new Field {map:map, x:10, y:10}
      field.save (err)->
        throw new Error "Can't save field: #{err}" if err?
        # when removing it
        field.remove (err) ->
          throw new Error "Can't remove field: #{err}" if err?
          # then it's not in the map anymore
          Field.findOne {_id: field._id}, (err, field) ->
            throw new Error "Can't find field by id: #{err}" if err?
            test.ok field is null
            test.done()

    'should field be updated': (test) ->
      # given an exiting a field on the map
      field = new Field {map:map, x:10, y:10}
      field.save (err)->
        throw new Error "Can't save field: #{err}" if err?
        # when updating it
        field.set 'x', 20
        field.save (err) ->
          throw new Error "Can't update field: #{err}" if err?
          # then it's not in the map anymore
          Field.findOne {_id: field._id}, (err, result) ->
            throw new Error "Can't find field by id: #{err}" if err?
            test.ok field?
            test.equal 20, result.get('x')
            test.equal 10, result.get('y')
            test.ok map.equals result.get 'map'
            test.done()