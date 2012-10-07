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

ItemType = require '../src/model/ItemType'
Item = require '../src/model/Item'
FieldType = require '../src/model/FieldType'
Field = require '../src/model/Field'
EventType = require '../src/model/EventType'
Event = require '../src/model/Event'
Executable = require '../src/model/Executable'
Map = require '../src/model/Map'
FSItem = require '../src/model/FSItem'
authoringService = require('../src/service/AuthoringService').get()
service = require('../src/service/AdminService').get()
watcher = require('../src/model/ModelWatcher').get()
testUtils = require './utils/testUtils'
utils = require '../src/utils'
pathUtils = require 'path'
fs = require 'fs-extra'
assert = require('chai').assert
     
itemTypes = []
eventTypes = []
fieldTypes = []
executables = []
maps = []
fields = []
items = []
fsItem = null
gameClientRoot = utils.confKey 'game.dev'

# CLean FSItem root and reinit authoring service
initializedFSRoot = (callback) ->
  fs.remove pathUtils.dirname(gameClientRoot), (err) -> 
    return callback err if err?
    authoringService.init (err) ->
      return callback err if err?
      # creates a single fsItem
      authoringService.save 
        path: 'folder/test.txt'
        isFolder: false
        content: new Buffer('Hi !').toString 'base64'
      , 'admin', (err, result) ->
        return callback err if err?
        fsItem = result
        callback()

describe 'AdminService tests', -> 

  beforeEach (done) ->
    itemTypes = []
    eventTypes = []
    executables = []
    fieldTypes = []
    item = []
    maps = []
    testUtils.cleanFolder utils.confKey('executable.source'), -> 
      Executable.resetAll -> 
        ItemType.collection.drop -> Item.collection.drop ->
          FieldType.collection.drop -> Field.collection.drop ->
            EventType.collection.drop -> Event.collection.drop ->
              Map.collection.drop ->
                # creates fixtures
                created = [
                  {clazz: ItemType, args: {name: 'type 1', properties:{strength:{type:'integer', def:10}}}, store: itemTypes}
                  {clazz: ItemType, args: {name: 'type 2', properties:{strength:{type:'integer', def:10}}}, store: itemTypes}
                  {clazz: EventType, args: {name: 'type 5', properties:{content:{type:'string', def:'hello'}}}, store: eventTypes}
                  {clazz: EventType, args: {name: 'type 6', properties:{content:{type:'string', def:'hello'}}}, store: eventTypes}
                  {clazz: FieldType, args: {name: 'type 3'}, store: fieldTypes}
                  {clazz: FieldType, args: {name: 'type 4'}, store: fieldTypes}
                  {clazz: Executable, args: {_id: 'rule 1', content:'# hello'}, store: executables}
                  {clazz: Executable, args: {_id: 'rule 2', content:'# world'}, store: executables}
                  {clazz: Map, args: {name: 'map 1', kind:'square'}, store: maps}
                  {clazz: Map, args: {name: 'map 2', kind:'diamond'}, store: maps}
                ]
                create = (def) ->
                  return done() unless def?
                  new def.clazz(def.args).save (err, saved) ->
                    throw new Error err if err?
                    def.store.push saved
                    create created.pop()

                create created.pop()

  it 'should list fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when listing unallowed model
    service.list unknownModelName, (err, modelName, list) ->
      # then an error occured
      assert.equal err, "The #{unknownModelName} model can't be listed"
      assert.equal modelName, unknownModelName
      done()

  it 'should list returns item types', (done) ->
    # when listing all item types
    service.list 'ItemType', (err, modelName, list) ->
      throw new Error "Can't list itemTypes: #{err}" if err?
      # then the two created types are retrieved
      assert.equal list.length, 2
      assert.equal modelName, 'ItemType'
      assert.ok itemTypes[0].equals(list[0])
      assert.ok itemTypes[1].equals(list[1])
      done()

  it 'should list returns event types', (done) ->
    # when listing all event types
    service.list 'EventType', (err, modelName, list) ->
      throw new Error "Can't list eventTypes: #{err}" if err?
      # then the two created types are retrieved
      assert.equal list.length, 2
      assert.equal modelName, 'EventType'
      assert.ok eventTypes[0].equals(list[0])
      assert.ok eventTypes[1].equals(list[1])
      done()

  it 'should list returns field types', (done) ->
    # when listing all field types
    service.list 'FieldType', (err, modelName, list) ->
      throw new Error "Can't list fieldTypes: #{err}" if err?
      # then the two created types are retrieved
      assert.equal list.length, 2
      assert.equal modelName, 'FieldType'
      assert.ok fieldTypes[0].equals(list[0])
      assert.ok fieldTypes[1].equals(list[1])
      done()

  it 'should list returns executables', (done) ->
    # when listing all item types
    service.list 'Executable', (err, modelName, list) ->
      throw new Error "Can't list executables: #{err}" if err?
      # then the two created executables are retrieved
      assert.equal list.length, 2
      assert.equal modelName, 'Executable'
      assert.equal executables[0]._id, list[0]._id
      assert.equal executables[1]._id, list[1]._id
      done()

  it 'should list returns maps', (done) ->
    # when listing all item types
    service.list 'Map', (err, modelName, list) ->
      throw new Error "Can't list maps: #{err}" if err?
      # then the two created executables are retrieved
      assert.equal list.length, 2
      assert.equal modelName, 'Map'
      assert.ok maps[0].equals(list[0])
      assert.ok maps[1].equals(list[1])
      done()

  it 'should list fails on Items', (done) ->
    # when listing items
    service.list 'Item', (err, modelName, list) ->
      # then an error occured
      assert.equal err, "The Item model can't be listed"
      done()

  it 'should list returns fsItems in root', (done) ->
    # given a clean empty folder root
    initializedFSRoot (err)->
      throw new Error err if err?
      
      # when reading the root
      authoringService.readRoot (err, expected) ->
        throw new Error err if err?

        # when listing all fs items
        service.list 'FSItem', (err, modelName, list) ->
          throw new Error "Can't list root FSItems: #{err}" if err?
          # then the authoring service result were returned
          assert.equal modelName, 'FSItem'
          assert.equal list.length, expected.content.length
          for item, i in expected.content
            assert.ok item.equals list[i]
          done()

  it 'should save fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when saving unallowed model
    service.save unknownModelName, {name:'type 3'}, 'admin', (err, modelName, model) ->
      # then an error occured
      assert.equal err, "The #{unknownModelName} model can't be saved"
      assert.equal modelName, unknownModelName
      done()

  it 'should save create new item type', (done) ->
    # given new values
    values = {name: 'itemtype 3', properties:{health:{def:0, type:'integer'}}}
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'ItemType'
      assert.equal operation, 'creation'
      assert.equal instance._name.default, 'itemtype 3'
      awaited = true

    # when saving new item type
    service.save 'ItemType', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save itemType: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.ok model._id?
      assert.equal model.get('name'), values.name
      assert.equal model.get('properties'), values.properties

      # then the model exists in DB
      ItemType.findById model._id, (err, obj) ->
        throw new Error "Can't find itemType in db #{err}" if err?
        assert.ok obj.equals model
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should save create new event type', (done) ->
    # given new values
    values = {name: 'eventtype 3', properties:{weight:{def:5.2, type:'float'}}}
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'EventType'
      assert.equal operation, 'creation'
      assert.equal instance._name.default, 'eventtype 3'
      awaited = true

    # when saving new event type
    service.save 'EventType', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save eventType: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.ok model._id?
      assert.equal model.get('name'), values.name
      assert.equal model.get('properties'), values.properties

      # then the model exists in DB
      EventType.findById model._id, (err, obj) ->
        throw new Error "Can't find eventType in db #{err}" if err?
        assert.ok obj.equals model
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should save create new field type', (done) ->
    # given new values
    values = {name: 'fieldtype 3'}
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'FieldType'
      assert.equal operation, 'creation'
      assert.equal instance._name.default, 'fieldtype 3'
      awaited = true

    # when saving new field type
    service.save 'FieldType', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save fieldType: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.ok model._id?
      assert.equal model.get('name'), values.name

      # then the model exists in DB
      FieldType.findById model._id, (err, obj) ->
        throw new Error "Can't find fieldType in db #{err}" if err?
        assert.ok obj.equals model
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should save create new executable', (done) ->
    # given new values
    values = {_id: 'rule 3', content:'console.log("hello world 3");'}
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Executable'
      assert.equal operation, 'creation'
      assert.equal instance._id, 'rule 3'
      awaited = true

    # when saving new executable
    service.save 'Executable', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save executable: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.equal model._id, values._id
      assert.equal model.content, values.content

      # then the model exists in cache
      Executable.findCached model._id, (err, obj) ->
        throw new Error "Can't find executable #{err}" if err?
        assert.deepEqual obj, model
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should save create new map', (done) ->
    # given new values
    values = {name: 'map 3'}
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Map'
      assert.equal operation, 'creation'
      assert.equal instance._name.default, 'map 3'
      assert.equal instance.kind, 'hexagon'
      awaited = true

    # when saving new map
    service.save 'Map', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save map: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.ok model._id?
      assert.equal model.get('name'), values.name
      assert.equal model.get('kind'), 'hexagon'

      # then the model exists in DB
      Map.findById model._id, (err, obj) ->
        throw new Error "Can't find map in db #{err}" if err?
        assert.ok obj.equals model
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should save create new fsItem', (done) ->
    # given new values
    values = path: 'test2.txt', isFolder: false, content: new Buffer('Hi !').toString('base64')
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'FSItem'
      assert.equal operation, 'creation'
      assert.equal instance.path, values.path
      assert.isFalse instance.isFolder
      assert.equal instance.content, values.content
      awaited = true

    # when saving new fsitem
    service.save 'FSItem', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save fsitem: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.equal model.path, values.path
      assert.equal model.content, values.content
      assert.isFalse model.isFolder

      # then the authoring servce serve this fsitem
      authoringService.read model, (err, obj) ->
        throw new Error "Can't find fsitem with authoring servce #{err}" if err?
        assert.ok obj.equals model
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should save update existing item type', (done) ->
    # given existing values
    values = itemTypes[1].toObject()

    # given an item for this type
    new Item({type: itemTypes[1]}).save (err, item) ->
      throw new Error "Can't save item: #{err}" if err?
      assert.equal item.get('strength'), 10
        
      # given a property raw change
      values.properties.desc = {type:'string', def:'to be defined'}
      delete values.properties.strength

      awaited = false
      # then a creation event was issued
      watcher.on 'change', (operation, className, instance) ->
        return unless className is 'ItemType'
        assert.equal operation, 'update'
        assert.ok itemTypes[1].equals instance, 'In watcher, changed instance doesn`t mathc parameters'
        awaited = true

      # when saving existing item type
      service.save 'ItemType', values, 'admin', (err, modelName, model) ->
        throw new Error "Can't save itemType: #{err}" if err?

        # then the created values are returned
        assert.ok itemTypes[1]._id.equals(model._id), 'Saved model doesn\'t match parameters'
        assert.equal model.get('name'), itemTypes[1].get('name')
        assert.ok 'desc' of model.get('properties'), 'Desc not added in properties'
        assert.equal model.get('properties').desc.type, 'string'
        assert.equal model.get('properties').desc.def, 'to be defined'

        # then the model exists in DB
        ItemType.findById model._id, (err, obj) ->
          throw new Error "Can't find itemType in db #{err}" if err?
          assert.ok obj.equals model, 'ItemType cannot be found in DB'

          # then the model was updated, not created in DB
          ItemType.find {}, (err, list) ->
            throw new Error "Can't find itemTypes in db #{err}" if err?
            assert.equal list.length, 2
            assert.ok awaited, 'watcher wasn\'t invoked'

            # then the instance has has only property property desc
            Item.findById item._id, (err, item) ->
              throw new Error "Can't get item from db #{err}" if err?
              assert.equal 'to be defined', item.get('desc')
              assert.ok item.get('strength') is undefined, 'Item still has strength property'
              watcher.removeAllListeners 'change'
              done()

  it 'should save update existing event type', (done) ->
    # given existing values
    values = eventTypes[1].toObject()

    # given an event for this type
    new Event({type: eventTypes[1]}).save (err, event) ->
      throw new Error "Can't save event: #{err}" if err?
      assert.equal event.get('content'), 'hello'
        
      # given a property raw change
      values.properties.desc = {type:'string', def:'to be defined'}
      delete values.properties.content

      awaited = false
      # then a creation event was issued
      watcher.on 'change', (operation, className, instance) ->
        return unless className is 'EventType'
        assert.equal operation, 'update'
        assert.ok eventTypes[1].equals instance, 'In watcher, changed instance doesn`t match parameters'
        awaited = true

      # when saving existing event type
      service.save 'EventType', values, 'admin', (err, modelName, model) ->
        throw new Error "Can't save eventType: #{err}" if err?
        # then the created values are returned
        assert.ok eventTypes[1]._id.equals(model._id), 'Saved model doesn\'t match parameters'
        assert.equal model.get('name'), eventTypes[1].get('name')
        assert.ok 'desc' of model.get('properties'), 'Desc not added in properties'
        assert.equal model.get('properties').desc.type, 'string'
        assert.equal model.get('properties').desc.def, 'to be defined'

        # then the model exists in DB
        EventType.findById model._id, (err, obj) ->
          throw new Error "Can't find eventType in db #{err}" if err?
          assert.ok obj.equals model, 'EventType cannot be found in DB'

          # then the model was updated, not created in DB
          EventType.find {}, (err, list) ->
            throw new Error "Can't find eventTypes in db #{err}" if err?
            assert.equal list.length, 2
            assert.ok awaited, 'watcher wasn\'t invoked'

            # then the instance has has only property property desc
            Event.findById event._id, (err, event) ->
              throw new Error "Can't get event from db #{err}" if err?
              assert.equal 'to be defined', event.get('desc')
              assert.ok event.get('content') is undefined, 'Event still has content property'
              watcher.removeAllListeners 'change'
              done()

  it 'should save update existing field type', (done) ->
    # given existing values
    values = fieldTypes[1]
    values.set 'desc', 'to be defined'

    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'FieldType'
      assert.equal operation, 'update'
      assert.ok fieldTypes[1].equals instance
      awaited = true

    # when saving existing field type
    service.save 'FieldType', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save fieldType: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.ok fieldTypes[1]._id.equals model._id
      assert.equal model.get('name'), values.get('name')
      assert.equal model.get('desc'), 'to be defined'

      # then the model exists in DB
      FieldType.findById model._id, (err, obj) ->
        throw new Error "Can't find fieldType in db #{err}" if err?
        assert.ok obj.equals model

        # then the model was updated, not created in DB
        FieldType.find {}, (err, list) ->
          throw new Error "Can't find fieldTypes in db #{err}" if err?
          assert.equal list.length, 2
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

  it 'should save fails to update existing executable', (done) ->
    # when saving existing executable
    service.save 'Executable', executables[1], 'admin', (err, modelName, model) ->
      assert.ok err?
      assert.equal err, "Id #{executables[1]._id} already used"
      done()

  it 'should save update existing map', (done) ->
    # given existing values
    values = maps[0]
    values.set 'kind', 'square'

    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Map'
      assert.equal operation, 'update'
      assert.ok maps[0].equals instance
      assert.equal instance.kind, 'square', 'modification not propagated'
      awaited = true

    # when saving existing map
    service.save 'Map', values, 'admin', (err, modelName, model) ->
      throw new Error "Can't save map: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.ok maps[0]._id.equals model._id
      assert.equal model.get('name'), values.get('name')
      assert.equal model.get('kind'), 'square', 'returned value not updated'

      # then the model exists in DB
      Map.findById model._id, (err, obj) ->
        throw new Error "Can't find map in db #{err}" if err?
        assert.ok obj.equals model

        # then the model was updated, not created in DB
        Map.find {}, (err, list) ->
          throw new Error "Can't find maps in db #{err}" if err?
          assert.equal list.length, 2
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

  it 'should save update existing fsItem', (done) ->
    # given new values
    newContent = new Buffer('Hi !! 2').toString('base64')
    fsItem.content = newContent
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'FSItem'
      assert.equal operation, 'update'
      assert.equal instance.path, fsItem.path
      assert.equal instance.content, newContent
      awaited = true

    # when saving existing fsitem
    service.save 'FSItem', fsItem, 'admin', (err, modelName, model) ->
      throw new Error "Can't save fsitem: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.equal model.path, fsItem.path
      assert.equal model.content, newContent
      assert.isFalse model.isFolder

      # then the authoring servce serve this fsitem
      authoringService.read fsItem, (err, obj) ->
        throw new Error "Can't find fsitem with authoring servce #{err}" if err?
        assert.ok obj.equals model
        assert.ok awaited, 'watcher wasn\'t invoked'
        assert.equal obj.content, newContent
        done()

  it 'should save creates new fields', (done) ->
    saved = []
    # given two new fields
    toBeSaved = [
      {mapId: maps[0]._id, typeId: fieldTypes[0]._id, x:0, y:0}
      {mapId: maps[0]._id, typeId: fieldTypes[1]._id, x:0, y:1}
    ]

    # then a creation event was issued
    watcher.on 'change', (operation, className, instance)->
      assert.equal className, 'Field'
      assert.equal operation, 'creation'
      saved.push instance

    # when saving two new fields
    service.save 'Field', toBeSaved.concat(), 'admin', (err, modelName, returned) ->
      throw new Error "Can't save fields: #{err}" if err?
      # then the created values are returned
      assert.equal returned?.length, 2, 'unexpected returned fields'
      assert.equal saved.length, 2, 'watcher was not as many times invoked as awaited'

      # then the model exists in DB
      Field.findById returned[0]._id, (err, obj) ->
        throw new Error "Can't find field in db #{err}" if err?
        assert.equal obj.get('mapId'), toBeSaved[1].mapId
        assert.equal obj.get('typeId'), toBeSaved[1].typeId
        assert.equal obj.get('x'), toBeSaved[1].x
        assert.equal obj.get('y'), toBeSaved[1].y
        assert.ok returned[0].equals obj
        # then the model exists in DB
        Field.findById returned[1]._id, (err, obj) ->
          throw new Error "Can't find field in db #{err}" if err?
          assert.equal obj.get('mapId'), toBeSaved[0].mapId
          assert.equal obj.get('typeId'), toBeSaved[0].typeId
          assert.equal obj.get('x'), toBeSaved[0].x
          assert.equal obj.get('y'), toBeSaved[0].y
          assert.ok returned[1].equals obj
          watcher.removeAllListeners 'change'
          done()

  it 'should save fails on non fields array parameter', (done) ->
    # when saving field without array
    service.save 'Field', {mapId: maps[0]._id, typeId: fieldTypes[0]._id, x:0, y:0}, 'admin', (err, modelName, returned) ->
      # then nothing was saved
      assert.isNotNull err
      assert.equal 'Fields must be saved within an array', err
      assert.equal modelName, 'Field'
      assert.isUndefined returned
      done()

  it 'should save fails on existing fields', (done) ->
    # given an existing field
    new Field({mapId: maps[0]._id, typeId: fieldTypes[0]._id, x:0, y:0}).save (err, field) ->
      throw new Error "Can't save field: #{err}" if err?

      # given another new field
      saved = []
      toBeSaved = [
        field
        {mapId: maps[0]._id, typeId: fieldTypes[1]._id, x:0, y:1}
      ]

      # then a creation event was issued
      watcher.on 'change', (operation, className, instance)->
        assert.equal className, 'Field'
        assert.equal operation, 'creation'
        saved.push instance

      # when saving two new fields
      service.save 'Field', toBeSaved.concat(), 'admin', (err, modelName, returned) ->
        # then an error was returned
        assert.equal 'Fields cannot be updated', err
        # then the created values are returned
        assert.equal returned?.length, 1, 'unexpected returned fields'
        assert.equal saved.length, 1, 'watcher was not as many times invoked as awaited'

        # then the model exists in DB
        Field.findById returned[0]._id, (err, obj) ->
          throw new Error "Can't find field in db #{err}" if err?
          assert.equal obj.get('mapId'), toBeSaved[1].mapId
          assert.equal obj.get('typeId'), toBeSaved[1].typeId
          assert.equal obj.get('x'), toBeSaved[1].x
          assert.equal obj.get('y'), toBeSaved[1].y
          assert.ok returned[0].equals obj
          watcher.removeAllListeners 'change'
          done()

  it 'should save do nothing on empty fields array', (done) ->
    # when saving field with empty array
    service.save 'Field', [], 'admin', (err, modelName, returned) ->
      # then nothing was saved
      throw new Error "Unexpected error while saving fields: #{err}" if err?
      assert.equal modelName, 'Field'
      assert.equal returned.length, 0
      done()

  it 'should save creates new item', (done) ->
    # given a new item
    saved = null
    toBeSaved = type: itemTypes[1].toObject(), map: maps[0].toObject(), x:0, y:0, strength:20

    # then a creation event was issued
    watcher.on 'change', (operation, className, instance)->
      assert.equal className, 'Item'
      assert.equal operation, 'creation'
      saved = instance

    # when saving two new fields
    service.save 'Item', toBeSaved, 'admin', (err, modelName, returned) ->
      throw new Error "Can't save item: #{err}" if err?
      # then the created values are returned
      assert.isNotNull returned, 'unexpected returned item'
      assert.isNotNull saved, 'watcher was not as many times invoked as awaited'
      assert.ok returned.equals saved

      # then the model exists in DB
      Item.findById returned._id, (err, obj) ->
        throw new Error "Can't find field in db #{err}" if err?
        assert.ok maps[0]._id.equals(obj.get('map')._id), "unexpected map id #{obj.get('map')._id}"
        assert.ok itemTypes[1]._id.equals(obj.get('type')._id), "unexpected type id #{obj.get('type')._id}"
        assert.equal obj.get('x'), toBeSaved.x
        assert.equal obj.get('y'), toBeSaved.y
        assert.equal obj.get('strength'), toBeSaved.strength
        assert.ok obj.equals returned
        watcher.removeAllListeners 'change'
        done()

  it 'should save saved existing item', (done) ->
    # given an existing item
    new Item(type: itemTypes[0], map: maps[0], x:0, y:0, strength:20).save (err, item) ->
      return done err if err?

      awaited = false
      toBeSaved = item.toObject()
      toBeSaved.strength = 50

      # then a creation event was issued
      watcher.on 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'update'
        assert.ok item.equals instance
        awaited = true

      # when saving two new fields
      service.save 'Item', toBeSaved, 'admin', (err, modelName, returned) ->
        throw new Error "Can't save item: #{err}" if err?
        # then the created values are returned
        assert.isNotNull returned, 'unexpected returned item'
        assert.ok awaited, 'watcher was not as many times invoked as awaited'

        # then the model exists in DB
        Item.findById returned._id, (err, obj) ->
          throw new Error "Can't find field in db #{err}" if err?
          assert.ok maps[0]._id.equals(obj.get('map')._id), "unexpected map id #{obj.get('map')._id}"
          assert.ok itemTypes[0]._id.equals(obj.get('type')._id), "unexpected type id #{obj.get('type')._id}"
          assert.equal obj.get('x'), toBeSaved.x
          assert.equal obj.get('y'), toBeSaved.y
          assert.equal obj.get('strength'), toBeSaved.strength
          assert.ok obj.equals returned
          watcher.removeAllListeners 'change'
          done()

  it 'should remove fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when removing unallowed model
    service.remove unknownModelName, {_id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.equal err, "The #{unknownModelName} model can't be removed"
      assert.equal modelName, unknownModelName
      done()

  it 'should remove fails on unknown item type', (done) ->
    # when removing unknown item type
    service.remove 'ItemType', {_id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.ok 0 is err.indexOf "Unexisting ItemType"
      done()

  it 'should remove fails on unknown event type', (done) ->
    # when removing unknown event type
    service.remove 'EventType', {_id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.ok 0 is err.indexOf "Unexisting EventType"
      done()

  it 'should remove fails on unknown field type', (done) ->
    # when removing unknown field type
    service.remove 'FieldType', {_id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.ok 0 is err.indexOf "Unexisting FieldType"
      done()

  it 'should remove fails on unknown executable', (done) ->
    # when removing unknown item type
    service.remove 'Executable', {_id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.ok 0 is err.indexOf "Unexisting Executable"
      done()

  it 'should remove delete existing item type', (done) ->
    awaited = false
    # then a deletion event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'ItemType'
      assert.equal operation, 'deletion'
      assert.ok itemTypes[1].equals instance
      awaited = true

    # when removing existing item type
    service.remove 'ItemType', itemTypes[1], 'admin', (err, modelName, model) ->
      throw new Error "Can't remove itemType: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.ok itemTypes[1]._id.equals model._id

      # then the model do not exists anymore in DB
      ItemType.findById model._id, (err, obj) ->
        assert.ok obj is null
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should remove delete existing event type', (done) ->
    awaited = false
    # then a deletion event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'EventType'
      assert.equal operation, 'deletion'
      assert.ok eventTypes[1].equals instance
      awaited = true

    # when removing existing item type
    service.remove 'EventType', eventTypes[1], 'admin', (err, modelName, model) ->
      throw new Error "Can't remove eventType: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.ok eventTypes[1]._id.equals model._id

      # then the model do not exists anymore in DB
      EventType.findById model._id, (err, obj) ->
        assert.ok obj is null
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should remove delete existing field type', (done) ->
    awaited = false
    # then a deletion event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'FieldType'
      assert.equal operation, 'deletion'
      assert.ok fieldTypes[1].equals instance
      awaited = true

    # when removing existing field type
    service.remove 'FieldType', fieldTypes[1], 'admin', (err, modelName, model) ->
      throw new Error "Can't remove fieldType: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.ok fieldTypes[1]._id.equals model._id

      # then the model do not exists anymore in DB
      FieldType.findById model._id, (err, obj) ->
        assert.isNull obj
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should remove delete existing executable', (done) ->
    awaited = false
    # then a deletion event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Executable'
      assert.equal operation, 'deletion'
      assert.deepEqual executables[1], instance
      awaited = true

    # when removing existing executable
    service.remove 'Executable', executables[1], 'admin', (err, modelName, model) ->
      throw new Error "Can't remove executable: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.equal executables[1]._id, model._id

      # then the model do not exists anymore in DB
      Executable.findCached model._id, (err, obj) ->
        assert.ok obj is null
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should remove delete existing map', (done) ->
    awaited = false
    # then a deletion event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Map'
      assert.equal operation, 'deletion'
      assert.ok maps[1].equals instance
      awaited = true

    # when removing existing map
    service.remove 'Map', maps[1], 'admin', (err, modelName, model) ->
      throw new Error "Can't remove map: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.ok maps[1]._id.equals model._id

      # then the model do not exists anymore in DB
      Map.findById model._id, (err, obj) ->
        assert.ok obj is null
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should remove removes existing fields', (done) ->
    # given two existing field
    new Field({mapId: maps[0]._id, typeId: fieldTypes[0]._id, x:0, y:0}).save (err, field1) ->
      throw new Error "Can't save field: #{err}" if err?
      new Field({mapId: maps[0]._id, typeId: fieldTypes[1]._id, x:0, y:1}).save (err, field2) ->
        throw new Error "Can't save field: #{err}" if err?
        removed = []

        # then a deletion event was issued
        watcher.on 'change', (operation, className, instance)->
          assert.equal className, 'Field'
          assert.equal operation, 'deletion'
          removed.push instance

        # when removing two existing fields
        service.remove 'Field', [field1, field2], 'admin', (err, modelName, returned) ->
          throw new Error "Can't remove fields: #{err}" if err?
          # then the created values are returned
          assert.equal returned?.length, 2, 'unexpected returned fields'
          assert.ok returned[0].equals field2
          assert.ok returned[1].equals field1

          # then the model does exist in DB anymore
          Field.findById field1._id, (err, obj) ->
            throw new Error "Can't find field in db #{err}" if err?
            assert.isNull obj
            Field.findById field2._id, (err, obj) ->
              throw new Error "Can't find field in db #{err}" if err?
              assert.isNull obj
              # then the watcher was properly invoked
              assert.equal removed.length, 2, 'watcher was not as many times invoked as awaited'
              assert.ok returned[0].equals removed[0]
              assert.ok returned[1].equals removed[1]
              watcher.removeAllListeners 'change'
              done()

  it 'should remove delete existing item', (done) ->
    # given an existing item
    new Item(type: itemTypes[0], map: maps[0], x:0, y:0, strength:20).save (err, item) ->
      return done err if err?
      awaited = false
    
      # then a deletion event was issued
      watcher.on 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'deletion'
        assert.ok item.equals instance
        awaited = true

      # when removing an existing item
      service.remove 'Item', item.toObject(), 'admin', (err, modelName, returned) ->
        throw new Error "Can't remove item: #{err}" if err?
        # then the created values are returned
        assert.isNotNull returned, 'unexpected returned item'
        assert.ok awaited, 'watcher was not as many times invoked as awaited'
        assert.ok returned.equals item

        # then the model exists in DB
        Item.findById returned._id, (err, obj) ->
          throw new Error "Can't find field in db #{err}" if err?
          assert.isNull obj
          watcher.removeAllListeners 'change'
          done()

  it 'should remove delete existing fsItem', (done) ->
    awaited = false
    # then a deletion event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'FSItem'
      assert.equal operation, 'deletion'
      assert.ok fsItem.equals instance
      awaited = true

    # when removing existing fsItem
    service.remove 'FSItem', fsItem, 'admin', (err, modelName, model) ->
      throw new Error "Can't remove fieldType: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.ok fsItem.equals model

      # then the model is not readable with authoring service
      authoringService.read fsItem, (err, obj) ->
        assert.isNotNull err
        assert.ok -1 isnt err.indexOf 'Unexisting item'
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should remove fails on non array parameter', (done) ->
    # when removing field without array
    service.remove 'Field', {mapId: maps[0]._id, typeId: fieldTypes[0]._id, x:0, y:0}, 'admin', (err, modelName, returned) ->
      # then nothing was removed
      assert.isNotNull err
      assert.equal 'Fields must be removed within an array', err
      assert.equal modelName, 'Field'
      assert.isUndefined returned
      done()

  it 'should remove fails on unexisting fields', (done) ->
    # given an existing field
    new Field({mapId: maps[0]._id, typeId: fieldTypes[0]._id, x:0, y:0}).save (err, field) ->
      throw new Error "Can't save field: #{err}" if err?
      
      removed = []

      # then a deletion event was issued
      watcher.on 'change', (operation, className, instance)->
        assert.equal className, 'Field'
        assert.equal operation, 'deletion'
        removed.push instance

      # when removing an existing and a new fields
      unexisting = {_id: fieldTypes[0]._id, mapId: maps[0]._id, typeId: fieldTypes[1]._id, x:0, y:1}
      service.remove 'Field', [unexisting, field], 'admin', (err, modelName, returned) ->
        # then an error occured
        assert.isNotNull err
        assert.equal "Unexisting field with id #{unexisting._id}", err
        # then the created values are returned
        assert.equal returned?.length, 1, 'unexpected returned fields'
        assert.ok returned[0].equals field

        # then the model does exist in DB anymore
        Field.findById field._id, (err, obj) ->
          throw new Error "Can't find field in db #{err}" if err?
          assert.isNull obj
          # then the watcher was properly invoked
          assert.equal removed.length, 1, 'watcher was not as many times invoked as awaited'
          assert.ok returned[0].equals removed[0]
          watcher.removeAllListeners 'change'
          done()

  it 'should remove do nothing on empty array', (done) ->
    # when removing field with empty array
    service.remove 'Field', [], 'admin', (err, modelName, returned) ->
      # then nothing was saved
      throw new Error "Unexpected error while saving fields: #{err}" if err?
      assert.equal modelName, 'Field'
      assert.equal returned.length, 0
      done()

  it 'should saveAndRename change executable id', (done) ->
    deletionReceived = false
    creationReceived = false

    # then a deletion event was issued for old executable
    watcher.on 'change', (operation, className, instance)->
      return unless operation is 'deletion' and className is 'Executable'
      assert.equal instance._id, executables[0]._id
      deletionReceived = true

    # then a creation event was issued for new executable
    watcher.on 'change', (operation, className, instance)->
      return unless operation is 'creation' and className is 'Executable'
      assert.equal instance._id, newId
      creationReceived = true

    # when renaming existing rule with new name
    newId = 'rule 4'
    oldId = executables[0]._id
    service.saveAndRename executables[0], newId, (err, oldId, model) ->
      throw new Error "Can't save and rename executable: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.equal model._id, newId
      assert.equal model.content, executables[0].content

      # then the old model id do not exists in cache
      Executable.findCached oldId, (err, obj) ->
        throw new Error "Can't find executable #{err}" if err?
        assert.equal obj, null
        assert.ok deletionReceived, 'watcher wasn\'t invoked for deletion'
        assert.ok creationReceived, 'watcher wasn\'t invoked for creation'
        watcher.removeAllListeners 'change'
        done()

  it 'should saveAndRename update existing executable', (done) ->
    # given existing values
    values = executables[1]
    values.content = 'console.log("hello world 4");'

    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Executable'
      assert.equal operation, 'update'
      assert.deepEqual executables[1], instance
      awaited = true

    # when saving existing item types
    service.saveAndRename values, null, (err, oldId, model) ->
      throw new Error "Can't save and rename executable: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.equal executables[1]._id, model._id
      assert.equal model.content, 'console.log("hello world 4");'

      # then the model exists in DB
      Executable.findCached model._id, (err, obj) ->
        throw new Error "Can't find executable in db #{err}" if err?
        assert.deepEqual obj, model
        done()

  it 'should saveAndRename failed on unknown executable', (done) ->
    # when saving unknown executable
    service.saveAndRename new Executable({_id:'rule 4', content:''}), 'rule 5', (err, oldId, model) ->
      # then an error was issued
      assert.ok err?
      assert.equal err, 'Unexisting Executable with id rule 4'
      done()

  it 'should saveAndRename failed on existing new name', (done) ->
    # when saving executable with existing new if
    service.saveAndRename executables[0], executables[1]._id, (err, oldId, model) ->
      # then an error was issued
      assert.ok err?
      assert.equal err, "Id #{executables[1]._id} already used"
      done()