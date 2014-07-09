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

Map = require '../hyperion/src/model/Map'
Field = require '../hyperion/src/model/Field'
FieldType = require '../hyperion/src/model/FieldType'
utils = require '../hyperion/src/util/common'
typeFactory = require '../hyperion/src/model/typeFactory'
{expect} = require 'chai'
watcher = require('../hyperion/src/model/ModelWatcher').get()

fieldType = null
map = null
awaited = false
listener = null

describe 'Map and Field tests', -> 

  beforeEach (done) ->
    Map.collection.drop -> Field.collection.drop -> FieldType.collection.drop -> Map.loadIdCache -> 
      new FieldType({id: 'plain'}).save (err, saved) ->
        return done err if err?
        fieldType = saved
        done()

  afterEach (done) ->
    # remove all listeners
    watcher.removeListener 'change', listener if listener?
    done()

  it 'should map be created', (done) -> 
    # given a new map
    id = 'map1'
    map = new Map {id: id}
    awaited = false

    # then a creation event was issued
    listener = (operation, className, instance)->
      if operation is 'creation' and className is 'Map'
        expect(instance).to.satisfy (o) -> map.equals o
        awaited = true
    watcher.on 'change', listener

    # when saving it
    map.save (err) ->
      return done "Can't save map: #{err}" if err?

      # then it is in mongo
      Map.find {}, (err, docs) ->
        return done "Can't find map: #{err}" if err?
        # then it's the only one document
        expect(docs).to.have.lengthOf 1
        # then it's values were saved
        expect(docs[0]).to.have.property('id').that.equal id
        expect(awaited, 'watcher was\'nt invoked for new map').to.be.true
        done()

  describe 'given a map', ->

    beforeEach (done) ->
      map = new Map {id: 'map2'}
      map.save -> done()

    it 'should map be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Map'
        expect(operation).to.equal 'deletion'
        expect(instance).to.satisfy (o) -> map.equals o
        awaited = true

      # when removing a map
      awaited = false
      map.remove ->

        # then it's not in mongo anymore
        Map.find {}, (err, docs) ->
          expect(docs).to.have.lengthOf 0
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should map be updated', (done) ->
      awaited = false
      
      # then a modification event was issued
      listener = (operation, className, instance) ->
        if operation is 'update' and className is 'Map'
          expect(instance).to.satisfy (o) -> map.equals o
          expect(instance).to.have.property('id').that.equal 'map2'
          expect(instance).to.have.property('kind').that.equal 'square'
          awaited = true
      watcher.on 'change', listener

      # when modifying and saving an item
      map.kind= 'square'
      map.save ->

        Map.find {}, (err, docs) ->
          # then it's the only one document
          expect(docs).to.have.lengthOf 1
          # then only the relevant values were modified
          expect(docs[0]).to.have.property('id').that.equal 'map2'
          expect(docs[0]).to.have.property('kind').that.equal 'square'
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should field be created', (done) ->
      # when creating a field on the map
      field = new Field {mapId:map.id, typeId:fieldType.id, x:0, y:0}
      field.save (err)->
        return done "Can't save field: #{err}" if err?
        # then its retrievable by map
        Field.find {mapId: map.id}, (err, fields) ->
          return done "Can't find field by map: #{err}" if err?
          expect(fields).to.have.lengthOf 1
          expect(fields[0]).to.satisfy (o) -> field.equals o
          expect(fields[0]).to.have.property('mapId').that.equal map.id
          expect(fields[0]).to.have.property('x').that.equal 0
          expect(fields[0]).to.have.property('y').that.equal 0
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
            expect(field).not.to.exist
            done()

    it 'should field cannot be updated', (done) ->
      # given an exiting a field on the map
      field = new Field {mapId:map.id, typeId:fieldType.id, x:10, y:10}
      field.save (err)->
        return done "Can't save field: #{err}" if err?
        # when updating it
        field.x= 20
        field.save (err) ->
          expect(err).to.have.property('message').that.include 'only creations are allowed on fields'
          done()

    it 'should field be removed with map', (done) ->
      # given some fields on the map
      new Field(mapId:map.id, typeId:fieldType.id, x:10, y:10).save (err) ->
        return done err if err?
        new Field(mapId:map.id, typeId:fieldType.id, x:5, y:5).save (err) ->
          return done err if err?
          Field.find {mapId: map.id}, (err, fields) ->
            return done err if err?
            expect(fields).to.have.lengthOf 2

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
                expect(fields).to.have.lengthOf 0
                expect(changes, 'watcher wasn\'t invoked').to.have.lengthOf 1
                expect(changes[0]).to.have.lengthOf 3
                expect(changes[0][0]).to.equal 'deletion'
                expect(changes[0][1]).to.equal 'Map'
                watcher.removeListener 'change', listener
                done()