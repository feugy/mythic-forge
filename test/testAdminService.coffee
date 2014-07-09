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

yaml = require 'js-yaml'
pathUtils = require 'path'
fs = require 'fs-extra'
async = require 'async'
{expect} = require 'chai'
ItemType = require '../hyperion/src/model/ItemType'
Item = require '../hyperion/src/model/Item'
FieldType = require '../hyperion/src/model/FieldType'
Field = require '../hyperion/src/model/Field'
EventType = require '../hyperion/src/model/EventType'
Event = require '../hyperion/src/model/Event'
Executable = require '../hyperion/src/model/Executable'
Map = require '../hyperion/src/model/Map'
FSItem = require '../hyperion/src/model/FSItem'
Player = require '../hyperion/src/model/Player'
ClientConf = require '../hyperion/src/model/ClientConf'
authoringService = require('../hyperion/src/service/AuthoringService').get()
service = require('../hyperion/src/service/AdminService').get()
watcher = require('../hyperion/src/model/ModelWatcher').get()
utils = require '../hyperion/src/util/common'
     
itemTypes = []
eventTypes = []
fieldTypes = []
executables = []
maps = []
fields = []
items = []
events = []
confs = []
fsItem = null
listener = null
awaited = false
gameClientRoot = utils.confKey 'game.client.dev'

describe 'AdminService tests', -> 

  beforeEach (done) ->
    awaited = false
    itemTypes = []
    eventTypes = []
    executables = []
    fieldTypes = []
    item = []
    maps = []
    event = []
    confs = []
    utils.empty utils.confKey('game.executable.source'), ->
      Executable.resetAll true, (err) -> 
        return done err if err?
        ItemType.collection.drop -> Item.collection.drop ->
          FieldType.collection.drop -> Field.collection.drop ->
            EventType.collection.drop -> Event.collection.drop ->
              Map.collection.drop -> ClientConf.collection.drop -> Map.loadIdCache ->
                # creates fixtures
                created = [
                  {clazz: ItemType, args: {id: 'type1', properties:{strength:{type:'integer', def:10}}}, store: itemTypes}
                  {clazz: ItemType, args: {id: 'type2', properties:{strength:{type:'integer', def:10}}}, store: itemTypes}
                  {clazz: EventType, args: {id: 'type5', properties:{content:{type:'string', def:'hello'}}}, store: eventTypes}
                  {clazz: EventType, args: {id: 'type6', properties:{content:{type:'string', def:'hello'}}}, store: eventTypes}
                  {clazz: FieldType, args: {id: 'type3'}, store: fieldTypes}
                  {clazz: FieldType, args: {id: 'type4'}, store: fieldTypes}
                  {clazz: Executable, args: {id: 'rule1', content:'# hello'}, store: executables}
                  {clazz: Executable, args: {id: 'rule2', content:'# world'}, store: executables}
                  {clazz: Map, args: {id: 'map1', kind:'square'}, store: maps}
                  {clazz: Map, args: {id: 'map2', kind:'diamond'}, store: maps}
                  {clazz: ClientConf, args: {id:'default', source: "names:\n  plain: 'plain'"}, store: confs}
                  {clazz: ClientConf, args: {id:'fr', source: "names:\n  plain: 'plaine'\n  river: 'rivière'"}, store: confs}
                ]
                create = (def) ->
                  return done() unless def?
                  new def.clazz(def.args).save (err, saved) ->
                    return done err if err?
                    def.store.push saved
                    create created.pop()

                create created.pop()

  afterEach (done) ->
    # remove all listeners
    watcher.removeListener 'change', listener if listener?
    done()

  it 'should list fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when listing unallowed model
    service.list unknownModelName, (err, modelName, list) ->
      # then an error occured
      expect(err).to.equal "The #{unknownModelName} model can't be listed"
      expect(modelName).to.equal unknownModelName
      done()

  it 'should list returns item types', (done) ->
    # when listing all item types
    service.list 'ItemType', (err, modelName, list) ->
      return done "Can't list itemTypes: #{err}" if err?
      # then the two created types are retrieved
      expect(list).to.have.lengthOf 2
      expect(modelName).to.equal 'ItemType'
      expect(list[0]).to.satisfy (o) -> o.equals itemTypes[0]
      expect(list[1]).to.satisfy (o) -> o.equals itemTypes[1]
      done()

  it 'should list returns event types', (done) ->
    # when listing all event types
    service.list 'EventType', (err, modelName, list) ->
      return done "Can't list eventTypes: #{err}" if err?
      # then the two created types are retrieved
      expect(list).to.have.lengthOf 2
      expect(modelName).to.equal 'EventType'
      expect(list[0]).to.satisfy (o) -> o.equals eventTypes[0]
      expect(list[1]).to.satisfy (o) -> o.equals eventTypes[1]
      done()

  it 'should list returns field types', (done) ->
    # when listing all field types
    service.list 'FieldType', (err, modelName, list) ->
      return done "Can't list fieldTypes: #{err}" if err?
      # then the two created types are retrieved
      expect(list).to.have.lengthOf 2
      expect(modelName).to.equal 'FieldType'
      expect(list[0]).to.satisfy (o) -> o.equals fieldTypes[0]
      expect(list[1]).to.satisfy (o) -> o.equals fieldTypes[1]
      done()

  it 'should list returns executables', (done) ->
    # when listing all item types
    service.list 'Executable', (err, modelName, list) ->
      return done "Can't list executables: #{err}" if err?
      # then the two created executables are retrieved
      expect(list).to.have.lengthOf 2
      expect(modelName).to.equal 'Executable'
      expect(list[0]).to.have.property('id').that.equal executables[0].id
      expect(list[1]).to.have.property('id').that.equal executables[1].id
      done()

  it 'should list returns maps', (done) ->
    # when listing all item types
    service.list 'Map', (err, modelName, list) ->
      return done "Can't list maps: #{err}" if err?
      # then the two created executables are retrieved
      expect(list).to.have.lengthOf 2
      expect(modelName).to.equal 'Map'
      expect(list[0]).to.satisfy (o) -> o.equals maps[0]
      expect(list[1]).to.satisfy (o) -> o.equals maps[1]
      done()

  it 'should list fails on Items', (done) ->
    # when listing items
    service.list 'Item', (err, modelName, list) ->
      # then an error occured
      expect(err).to.equal "The Item model can't be listed"
      done()

  it 'should list fails on Events', (done) ->
    # when listing events
    service.list 'Event', (err, modelName, list) ->
      # then an error occured
      expect(err).to.equal "The Event model can't be listed"
      done()

  it 'should list returns configurations', (done) ->
    # when listing items
    service.list 'ClientConf', (err, modelName, list) ->
      return done "Can't list configurations: #{err}" if err?
      # then the two created executables are retrieved
      expect(list).to.have.lengthOf 2
      expect(modelName).to.equal 'ClientConf'
      expect(list[0]).to.satisfy (o) -> o.equals confs[0]
      expect(list[1]).to.satisfy (o) -> o.equals confs[1]
      done()

  it 'should list returns fsItems in root', (done) ->
    # given a clean empty folder root
    utils.remove gameClientRoot, (err) -> 
      return done err if err?
      authoringService.init (err) ->
        return done err if err?
        # creates a single fsItem
        authoringService.save 
          path: 'folder/test.txt'
          isFolder: false
          content: new Buffer('Hi !').toString 'base64'
        , 'admin', (err, result) ->
          return callback err if err?
          fsItem = result
          
          # when reading the root
          authoringService.readRoot (err, expected) ->
            return done err if err?

            # when listing all fs items
            service.list 'FSItem', (err, modelName, list) ->
              return done "Can't list root FSItems: #{err}" if err?
              # then the authoring service result were returned
              expect(modelName).to.equal 'FSItem'
              expect(list).to.have.lengthOf expected.content.length
              for item, i in expected.content
                expect(item).to.satisfy (o) -> o.equals list[i]
              done()

  it 'should save fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when saving unallowed model
    service.save unknownModelName, {id:'type3'}, 'admin', (err, modelName, model) ->
      # then an error occured
      expect(err).to.equal "The #{unknownModelName} model can't be saved"
      expect(modelName).to.equal unknownModelName
      done()

  it 'should save create new item type', (done) ->
    # given new values
    values = {id: 'itemtype3', properties:{health:{def:0, type:'integer'}}}
   
    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'ItemType' and operation is 'creation'
      expect(instance).to.have.property('id').that.equal 'itemtype3'
      awaited = true
    watcher.on 'change', listener

    # when saving new item type
    service.save 'ItemType', values, 'admin', (err, modelName, model) ->
      return done "Can't save itemType: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('id').that.equal values.id
      expect(model).to.have.property('properties').that.deep.equal values.properties

      # then the model exists in DB
      ItemType.findById model.id, (err, obj) ->
        return done "Can't find itemType in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should save create new event type', (done) ->
    # given new values
    values = {id: 'eventtype3', properties:{weight:{def:5.2, type:'float'}}}
   
    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'EventType' and operation is 'creation'
      expect(instance).to.have.property('id').that.equal 'eventtype3'
      awaited = true
    watcher.on 'change', listener

    # when saving new event type
    service.save 'EventType', values, 'admin', (err, modelName, model) ->
      return done "Can't save eventType: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('id').that.equal values.id
      expect(model).to.have.property('properties').that.deep.equal values.properties

      # then the model exists in DB
      EventType.findById model.id, (err, obj) ->
        return done "Can't find eventType in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should save create new field type', (done) ->
    # given new values
    values = {id: 'fieldtype3'}
   
    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'FieldType' and operation is 'creation'
      expect(instance).to.have.property('id').that.equal 'fieldtype3'
      awaited = true
    watcher.on 'change', listener

    # when saving new field type
    service.save 'FieldType', values, 'admin', (err, modelName, model) ->
      return done "Can't save fieldType: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('id').that.equal values.id

      # then the model exists in DB
      FieldType.findById model.id, (err, obj) ->
        return done "Can't find fieldType in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should save create new executable', (done) ->
    # given new values
    values = {id: 'rule3', content:'console.log("hello world 3");'}
   
    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'Executable' and operation is 'creation'
      expect(instance).to.have.property('id').that.equal 'rule3'
      awaited = true
    watcher.on 'change', listener

    # when saving new executable
    service.save 'Executable', values, 'admin', (err, modelName, model) ->
      return done "Can't save executable: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('id').that.equal values.id
      expect(model).to.have.property('content').that.equal values.content

      # then the model exists in cache
      Executable.findCached [model.id], (err, objs) ->
        return done "Can't find executable #{err}" if err?
        expect(objs).to.have.lengthOf 1
        expect(objs[0]).to.deep.equal model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should save report executable compilation failure', (done) ->
    # given new values
    values = {id: 'rule6', content:'console. "hello world 3"'}
   
    # then NO creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'Executable' and operation is 'creation'
      awaited = true
    watcher.on 'change', listener

    # when saving new executable
    service.save 'Executable', values, 'admin', (err) ->
      # then the compilation error is reported
      expect(err).to.include 'unexpected "hello world 3"'

      # then the model does not exist in cache
      Executable.findCached [values.id], (err, objs) ->
        return done "Can't find executable #{err}" if err?
        expect(objs).to.have.lengthOf 0
        expect(awaited, 'watcher was invoked').to.be.false
        done()

  it 'should save create new map', (done) ->
    # given new values
    values = {id: 'map3'}
   
    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'Map' and operation is 'creation'
      expect(instance).to.have.property('id').that.equal 'map3'
      awaited = true
    watcher.on 'change', listener

    # when saving new map
    service.save 'Map', values, 'admin', (err, modelName, model) ->
      return done "Can't save map: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('id').that.equal values.id
      expect(model).to.have.property('kind').that.equal 'hexagon'

      # then the model exists in DB
      Map.findById model.id, (err, obj) ->
        return done "Can't find map in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should save create new fsItem', (done) ->
    # given new values
    values = path: 'test2.txt', isFolder: false, content: new Buffer('Hi !').toString('base64')
   
    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'FSItem' and operation is 'creation'
      expect(instance).to.have.property('path').that.equal values.path
      expect(instance.isFolder).to.be.false
      expect(instance).to.have.property('content').that.equal values.content
      awaited = true
    watcher.on 'change', listener

    # when saving new fsitem
    service.save 'FSItem', values, 'admin', (err, modelName, model) ->
      return done "Can't save fsitem: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('path').that.equal values.path
      expect(model).to.have.property('content').that.equal values.content
      expect(model.isFolder).to.be.false

      # then the authoring servce serve this fsitem
      authoringService.read model, (err, obj) ->
        return done "Can't find fsitem with authoring servce #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should save create new configuration', (done) ->
    # given new values
    values = {id: 'jp', source: "names:\n  river: 'kawa'"}
   
    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'ClientConf' and operation is 'creation'
      expect(instance).to.have.property('id').that.equal 'jp'
      awaited = true
    watcher.on 'change', listener

    # when saving new client configuration
    service.save 'ClientConf', values, 'admin', (err, modelName, model) ->
      return done "Can't save conf: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('id').that.equal values.id
      expect(model).to.have.deep.property('values.names.river').that.equal 'kawa'
      expect(model).to.have.property('source').that.equal values.source

      # then the model exists in DB
      ClientConf.findById model.id, (err, obj) ->
        return done "Can't find conf in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should save update existing item type', (done) ->
    # given existing values
    values = itemTypes[1].toJSON()

    # given an item for this type
    new Item({type: itemTypes[1]}).save (err, item) ->
      return done "Can't save item: #{err}" if err?
      expect(item).to.have.property('strength').that.equal 10
        
      # given a property raw change
      values.properties.desc = {type:'string', def:'to be defined'}
      delete values.properties.strength

      # then a creation event was issued
      listener = (operation, className, instance) ->
        return unless className is 'ItemType'
        expect(operation).to.equal 'update'
        expect(itemTypes[1]).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when saving existing item type
      service.save 'ItemType', values, 'admin', (err, modelName, model) ->
        return done "Can't save itemType: #{err}" if err?

        # then the created values are returned
        expect(model).to.have.property('id').that.equal itemTypes[1].id
        expect(model).to.have.deep.property('properties.desc.type').that.equal 'string'
        expect(model).to.have.deep.property('properties.desc.def').that.equal 'to be defined'

        # then the model exists in DB
        ItemType.findById model.id, (err, obj) ->
          return done "Can't find itemType in db #{err}" if err?
          expect(obj).to.satisfy (o) -> o.equals model

          # then the model was updated, not created in DB
          ItemType.find {}, (err, list) ->
            return done "Can't find itemTypes in db #{err}" if err?
            expect(list).to.have.lengthOf 2
            expect(awaited, 'watcher wasn\'t invoked').to.be.true

            # then the instance has has only property property desc
            Item.findById item.id, (err, item) ->
              return done "Can't get item from db #{err}" if err?
              expect(item).to.have.property('desc').that.equal 'to be defined'
              expect(item).not.to.have.property 'strength'
              done()

  it 'should save update existing event type', (done) ->
    # given existing values
    values = eventTypes[1].toJSON()

    # given an event for this type
    new Event({type: eventTypes[1]}).save (err, event) ->
      return done "Can't save event: #{err}" if err?
      expect(event).to.have.property('content').that.equal 'hello'
        
      # given a property raw change
      values.properties.desc = {type:'string', def:'to be defined'}
      delete values.properties.content

      # then a creation event was issued
      listener = (operation, className, instance) ->
        return unless className is 'EventType'
        expect(operation).to.equal 'update'
        expect(eventTypes[1]).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when saving existing event type
      service.save 'EventType', values, 'admin', (err, modelName, model) ->
        return done "Can't save eventType: #{err}" if err?
        # then the created values are returned
        expect(eventTypes[1]).to.have.property('id').that.equal model.id
        expect(model).to.have.deep.property('properties.desc.type').that.equal 'string'
        expect(model).to.have.deep.property('properties.desc.def').that.equal 'to be defined'

        # then the model exists in DB
        EventType.findById model.id, (err, obj) ->
          return done "Can't find eventType in db #{err}" if err?
          expect(obj).to.satisfy (o) -> o.equals model

          # then the model was updated, not created in DB
          EventType.find {}, (err, list) ->
            return done "Can't find eventTypes in db #{err}" if err?
            expect(list).to.have.lengthOf 2
            expect(awaited, 'watcher wasn\'t invoked').to.be.true

            # then the instance has has only property property desc
            Event.findById event.id, (err, event) ->
              return done "Can't get event from db #{err}" if err?
              expect(event).to.have.property('desc').that.equal 'to be defined'
              expect(event).not.to.have.property 'content'
              done()

  it 'should save update existing field type', (done) ->
    # given existing values
    values = fieldTypes[1].toJSON()
    values.descImage = 'to be defined'

    # then a update event was issued
    listener = (operation, className, instance)->
      return unless className is 'FieldType' and operation is 'update'
      expect(fieldTypes[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when saving existing field type
    service.save 'FieldType', values, 'admin', (err, modelName, model) ->
      return done "Can't save fieldType: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(fieldTypes[1]).to.have.property('id').that.equal model.id
      expect(model).to.have.property('descImage').that.equal 'to be defined'

      # then the model exists in DB
      FieldType.findById model.id, (err, obj) ->
        return done "Can't find fieldType in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model

        # then the model was updated, not created in DB
        FieldType.find {}, (err, list) ->
          return done "Can't find fieldTypes in db #{err}" if err?
          expect(list).to.have.lengthOf 2
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

  it 'should save update existing map', (done) ->
    # given existing values
    values = maps[0].toJSON()
    values.kind = 'square'

    # then a update event was issued
    listener = (operation, className, instance)->
      return unless className is 'Map' and operation is 'update'
      expect(maps[0]).to.satisfy (o) -> o.equals instance
      expect(instance).to.have.property('kind').that.equal 'square'
      awaited = true
    watcher.on 'change', listener

    # when saving existing map
    service.save 'Map', values, 'admin', (err, modelName, model) ->
      return done "Can't save map: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(maps[0]).to.have.property('id').that.equal model.id
      expect(model).to.have.property('kind').that.equal 'square' 

      # then the model exists in DB
      Map.findById model.id, (err, obj) ->
        return done "Can't find map in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model

        # then the model was updated, not created in DB
        Map.find {}, (err, list) ->
          return done "Can't find maps in db #{err}" if err?
          expect(list).to.have.lengthOf 2
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

  it 'should save update existing executable', (done) ->
    # given existing values
    values = executables[1]
    values.content = 'console.log("hello world 4");'

    # then a update event was issued
    listener = (operation, className, instance)->
      return unless className is 'Executable' and operation is 'update'
      expect(executables[1]).to.deep.equal instance
      awaited = true
    watcher.on 'change', listener

    # when saving existing item types
    service.save 'Executable', values, 'admin', (err, modelName, model) ->
      return done "Can't save executable: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(executables[1]).to.have.property('id').that.equal model.id
      expect(model).to.have.property('content').that.equal 'console.log("hello world 4");'

      # then the model exists in DB
      Executable.findCached [model.id], (err, objs) ->
        return done "Can't find executable in db #{err}" if err?
        expect(objs).to.have.lengthOf 1
        expect(objs[0]).to.deep.equal model
        done()

  it 'should save update existing fsItem', (done) ->
    # given new values
    newContent = new Buffer('Hi !! 2').toString('base64')
    fsItem.content = newContent
   
    # then a update event was issued
    listener = (operation, className, instance)->
      return unless className is 'FSItem' and operation is 'update'
      expect(instance).to.have.property('path').that.equal fsItem.path
      expect(instance).to.have.property('content').that.equal newContent
      awaited = true
    watcher.on 'change', listener

    # when saving existing fsitem
    service.save 'FSItem', fsItem, 'admin', (err, modelName, model) ->
      return done "Can't save fsitem: #{err}" if err?
      # then the created values are returned
      expect(model).to.exist
      expect(model).to.have.property('path').that.equal fsItem.path
      expect(model).to.have.property('content').that.equal newContent
      expect(model.isFolder).to.be.false

      # then the authoring servce serve this fsitem
      authoringService.read fsItem, (err, obj) ->
        return done "Can't find fsitem with authoring servce #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        expect(obj).to.have.property('content').that.equal newContent
        done()

  it 'should save creates new fields', (done) ->
    saved = []
    # given two new fields
    toBeSaved = [
      {mapId: maps[0].id, typeId: fieldTypes[0].id, x:0, y:0}
      {mapId: maps[0].id, typeId: fieldTypes[1].id, x:0, y:1}
    ]

    # then a creation event was issued
    listener = (operation, className, instance)->
      expect(className).to.equal 'Field'
      expect(operation).to.equal 'creation'
      saved.push instance
    watcher.on 'change', listener

    # when saving two new fields
    service.save 'Field', toBeSaved.concat(), 'admin', (err, modelName, returned) ->
      return done "Can't save fields: #{err}" if err?
      # then the created values are returned
      expect(returned).to.have.lengthOf 2
      expect(saved).to.have.lengthOf 2

      # then the model exists in DB
      Field.findById returned[0].id, (err, obj) ->
        return done "Can't find field in db #{err}" if err?
        expect(obj).to.have.property('mapId').that.equal toBeSaved[1].mapId
        expect(obj).to.have.property('typeId').that.equal toBeSaved[1].typeId
        expect(obj).to.have.property('x').that.equal toBeSaved[1].x
        expect(obj).to.have.property('y').that.equal toBeSaved[1].y
        expect(obj).to.satisfy (o) -> o.equals returned[0]
        # then the model exists in DB
        Field.findById returned[1].id, (err, obj) ->
          return done "Can't find field in db #{err}" if err?
          expect(obj).to.have.property('mapId').that.equal toBeSaved[0].mapId
          expect(obj).to.have.property('typeId').that.equal toBeSaved[0].typeId
          expect(obj).to.have.property('x').that.equal toBeSaved[0].x
          expect(obj).to.have.property('y').that.equal toBeSaved[0].y
          expect(obj).to.satisfy (o) -> o.equals returned[1]
          done()

  it 'should save fails on non fields array parameter', (done) ->
    # when saving field without array
    service.save 'Field', {mapId: maps[0].id, typeId: fieldTypes[0].id, x:0, y:0}, 'admin', (err, modelName, returned) ->
      # then nothing was saved
      expect(err).to.equal 'Fields must be saved within an array'
      expect(modelName).to.equal 'Field'
      expect(returned).not.to.exist
      done()

  it 'should save fails on existing fields', (done) ->
    # given an existing field
    new Field({mapId: maps[0].id, typeId: fieldTypes[0].id, x:0, y:0}).save (err, field) ->
      return done "Can't save field: #{err}" if err?

      # given another new field
      saved = []
      toBeSaved = [
        field.toJSON()
        {mapId: maps[0].id, typeId: fieldTypes[1].id, x:0, y:1}
      ]

      # then a creation event was issued
      listener = (operation, className, instance)->
        expect(className).to.equal 'Field'
        expect(operation).to.equal 'creation'
        saved.push instance
      watcher.on 'change', listener

      # when saving two new fields
      service.save 'Field', toBeSaved.concat(), 'admin', (err, modelName, returned) ->
        # then an error was returned
        expect(err).to.equal 'Fields cannot be updated'
        # then the created values are returned
        expect(returned).to.have.lengthOf 1
        expect(saved).to.have.lengthOf 1

        # then the model exists in DB
        Field.findById returned[0].id, (err, obj) ->
          return done "Can't find field in db #{err}" if err?
          expect(obj).to.have.property('mapId').that.equal toBeSaved[1].mapId
          expect(obj).to.have.property('typeId').that.equal toBeSaved[1].typeId
          expect(obj).to.have.property('x').that.equal toBeSaved[1].x
          expect(obj).to.have.property('y').that.equal toBeSaved[1].y
          expect(obj).to.satisfy (o) -> o.equals returned[0]
          done()

  it 'should save do nothing on empty fields array', (done) ->
    # when saving field with empty array
    service.save 'Field', [], 'admin', (err, modelName, returned) ->
      # then nothing was saved
      return done "Unexpected error while saving fields: #{err}" if err?
      expect(modelName).to.equal 'Field'
      expect(returned).to.have.lengthOf 0
      done()

  it 'should save creates new item', (done) ->
    # given a new item
    saved = null
    toBeSaved = type: itemTypes[1].toJSON(), map: maps[0].toJSON(), x:0, y:0, strength:20

    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'Item' and operation is 'creation'
      saved = instance
    watcher.on 'change', listener

    # when saving the new item
    service.save 'Item', toBeSaved, 'admin', (err, modelName, returned) ->
      return done "Can't save item: #{err}" if err?
      # then the created values are returned
      expect(returned).to.exist
      expect(saved).to.exist
      expect(returned).to.satisfy (o) -> o.equals saved

      # then the model exists in DB
      Item.findById returned.id, (err, obj) ->
        return done "Can't find item in db #{err}" if err?
        expect(obj).to.have.deep.property('map._id').that.equal maps[0].id
        expect(obj).to.have.deep.property('type._id').that.equal itemTypes[1].id
        expect(obj).to.have.property('x').that.equal toBeSaved.x
        expect(obj).to.have.property('y').that.equal toBeSaved.y
        expect(obj).to.have.property('strength').that.equal toBeSaved.strength
        expect(obj).to.satisfy (o) -> o.equals returned
        done()

  it 'should save saved existing item', (done) ->
    # given an existing item
    new Item(type: itemTypes[0], map: maps[0], x:0, y:0, strength:20).save (err, item) ->
      return done err if err?

      toBeSaved = item.toJSON()
      toBeSaved.strength = 50

      # then a update event was issued
      listener = (operation, className, instance)->
        return unless className is 'Item' and operation is 'update'
        expect(item).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when saving the existing item
      service.save 'Item', toBeSaved, 'admin', (err, modelName, returned) ->
        return done "Can't save item: #{err}" if err?
        # then the created values are returned
        expect(returned).to.exist
        expect(awaited, 'watcher was not as many times invoked as awaited').to.be.true

        # then the model exists in DB
        Item.findById returned.id, (err, obj) ->
          return done "Can't find item in db #{err}" if err?
          expect(obj).to.have.deep.property('map._id').that.equal maps[0].id
          expect(obj).to.have.deep.property('type._id').that.equal itemTypes[0].id
          expect(obj).to.have.property('x').that.equal toBeSaved.x
          expect(obj).to.have.property('y').that.equal toBeSaved.y
          expect(obj).to.have.property('strength').that.equal toBeSaved.strength
          expect(obj).to.satisfy (o) -> o.equals returned
          done()

  it 'should save creates new event', (done) ->
    # given a new event
    saved = null
    toBeSaved = type: eventTypes[1].toJSON(), content:'yaha'

    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'Event' and operation is 'creation'
      saved = instance
    watcher.on 'change', listener

    # when saving the new event
    service.save 'Event', toBeSaved, 'admin', (err, modelName, returned) ->
      return done "Can't save event: #{err}" if err?
      # then the created values are returned
      expect(returned).to.exist
      expect(saved).to.exist
      expect(returned).to.satisfy (o) -> o.equals saved

      # then the model exists in DB
      Event.findById returned.id, (err, obj) ->
        return done "Can't find event in db #{err}" if err?
        expect(obj).to.have.deep.property('type._id').that.equal eventTypes[1].id
        expect(obj).to.have.property('content').that.equal toBeSaved.content
        expect(obj).to.satisfy (o) -> o.equals returned
        done()

  it 'should save saved existing event', (done) ->
    # given an existing event
    new Event(type: eventTypes[1], content:'yaha').save (err, event) ->
      return done err if err?

      toBeSaved = event.toJSON()
      toBeSaved.content = 'hohoho'

      # then a update event was issued
      listener = (operation, className, instance)->
        return unless className is 'Event' and operation is 'update'
        expect(event).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when saving the existing event
      service.save 'Event', toBeSaved, 'admin', (err, modelName, returned) ->
        return done "Can't save event: #{err}" if err?
        # then the created values are returned
        expect(returned).to.exist
        expect(awaited, 'watcher was not as many times invoked as awaited').to.be.true

        # then the model exists in DB
        Event.findById returned.id, (err, obj) ->
          return done "Can't find event in db #{err}" if err?
          expect(obj).to.have.deep.property('type._id').that.equal eventTypes[1].id
          expect(obj).to.have.property('content').that.equal toBeSaved.content
          expect(obj).to.satisfy (o) -> o.equals returned
          done()

  it 'should save creates new player', (done) ->
    # given a new player
    saved = null
    toBeSaved = email: 'caracol', provider:'Google', isAdmin: true

    # then a creation event was issued
    listener = (operation, className, instance)->
      return unless className is 'Player' and operation is 'creation'
      saved = instance
    watcher.on 'change', listener

    # when saving the new player
    service.save 'Player', toBeSaved, 'admin', (err, modelName, returned) ->
      return done "Can't save player: #{err}" if err?
      # then the created values are returned
      expect(returned).to.exist
      expect(saved).to.exist
      expect(returned).to.satisfy (o) -> o.equals saved

      # then the model exists in DB
      Player.findById returned.id, (err, obj) ->
        return done "Can't find player in db #{err}" if err?
        expect(obj).to.have.property('email').that.equal toBeSaved.email
        expect(obj).to.have.property('provider').that.equal toBeSaved.provider
        expect(obj).to.have.property('isAdmin').that.equal toBeSaved.isAdmin
        expect(obj).to.satisfy (o) -> o.equals returned
        done()

  it 'should save saved existing player', (done) ->
    # given an existing player
    new Player(email: 'caracol', provider:'Google', isAdmin: true).save (err, player) ->
      return done err if err?

      toBeSaved = player.toJSON()
      toBeSaved.provider = null
      toBeSaved.password = 'toto'

      # then a update event was issued
      listener = (operation, className, instance)->
        return unless className is 'Player' and operation is 'update'
        expect(player).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when saving the existing player
      service.save 'Player', toBeSaved, 'admin', (err, modelName, returned) ->
        return done "Can't save player: #{err}" if err?
        # then the created values are returned
        expect(returned).to.exist
        expect(awaited, 'watcher was not as many times invoked as awaited').to.be.true

        # then the model exists in DB
        Player.findById returned.id, (err, obj) ->
          return done "Can't find player in db #{err}" if err?
          expect(obj).to.have.property('email').that.equal toBeSaved.email
          expect(obj).to.have.property('provider').that.equal toBeSaved.provider
          expect(obj).to.have.property('isAdmin').that.equal toBeSaved.isAdmin
          expect(obj).to.satisfy (o) -> o.equals returned
          done()

  it 'should save update existing configuration', (done) ->
    # given a change on existing values
    conf = confs[1].toJSON()
    values = yaml.safeLoad conf.source
    values.names.montain = 'montagne'
    conf.source = yaml.safeDump values

    # then an update event was issued
    listener = (operation, className, instance) ->
      return unless className is 'ClientConf'
      expect(operation).to.equal 'update'
      expect(confs[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when saving existing configuration
    service.save 'ClientConf', conf, 'admin', (err, modelName, model) ->
      return done "Can't save conf: #{err}" if err?

      # then the created values are returned
      expect(confs[1]).to.have.property('id').that.equal model.id
      expect(confs[1]).to.have.property('source').that.equal model.source
      expect(model).to.have.deep.property('values.names.montain').that.equal 'montagne'
      
      # then the model exists in DB
      ClientConf.findById model.id, (err, obj) ->
        return done "Can't find conf in db #{err}" if err?
        expect(obj).to.satisfy (o) -> o.equals model

        # then the model was updated, not created in DB
        ClientConf.find {}, (err, list) ->
          return done "Can't find confs in db #{err}" if err?
          expect(list).to.have.lengthOf 2
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

  it 'should remove fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when removing unallowed model
    service.remove unknownModelName, {id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      expect(err).to.equal "The #{unknownModelName} model can't be removed"
      expect(modelName).to.equal unknownModelName
      done()

  it 'should remove fails on unknown item type', (done) ->
    # when removing unknown item type
    service.remove 'ItemType', {id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      expect(err).to.include "Unexisting ItemType"
      done()

  it 'should remove fails on unknown event type', (done) ->
    # when removing unknown event type
    service.remove 'EventType', {id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      expect(err).to.include "Unexisting EventType"
      done()

  it 'should remove fails on unknown field type', (done) ->
    # when removing unknown field type
    service.remove 'FieldType', {id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      expect(err).to.include "Unexisting FieldType"
      done()

  it 'should remove fails on unknown executable', (done) ->
    # when removing unknown item type
    service.remove 'Executable', {id:'4feab529ac7805980e000017'}, 'admin', (err, modelName, model) ->
      # then an error occured
      expect(err).to.include "Unexisting Executable"
      done()

  it 'should remove delete existing item type', (done) ->
    # then a deletion event was issued
    listener = (operation, className, instance)->
      return unless className is 'ItemType' and operation is 'deletion'
      expect(itemTypes[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when removing existing item type
    service.remove 'ItemType', itemTypes[1], 'admin', (err, modelName, model) ->
      return done "Can't remove itemType: #{err}" if err?
      # then the removed values are returned
      expect(model).to.exist
      expect(itemTypes[1]).to.have.property('id').that.equal model.id

      # then the model do not exists anymore in DB
      ItemType.findById model.id, (err, obj) ->
        expect(obj).not.to.exist
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should remove delete existing event type', (done) ->
    # then a deletion event was issued
    listener = (operation, className, instance)->
      return unless className is 'EventType' and operation is 'deletion'
      expect(eventTypes[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when removing existing item type
    service.remove 'EventType', eventTypes[1], 'admin', (err, modelName, model) ->
      return done "Can't remove eventType: #{err}" if err?
      # then the removed values are returned
      expect(model).to.exist
      expect(eventTypes[1]).to.have.property('id').that.equal model.id

      # then the model do not exists anymore in DB
      EventType.findById model.id, (err, obj) ->
        expect(obj).not.to.exist
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should remove delete existing field type', (done) ->
    # then a deletion event was issued
    listener = (operation, className, instance)->
      return unless className is 'FieldType' and operation is 'deletion'
      expect(fieldTypes[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when removing existing field type
    service.remove 'FieldType', fieldTypes[1], 'admin', (err, modelName, model) ->
      return done "Can't remove fieldType: #{err}" if err?
      # then the removed values are returned
      expect(model).to.exist
      expect(fieldTypes[1]).to.have.property('id').that.equal model.id

      # then the model do not exists anymore in DB
      FieldType.findById model.id, (err, obj) ->
        expect(obj).not.to.exist
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should remove delete existing executable', (done) ->
    # then a deletion event was issued
    listener = (operation, className, instance)->
      return unless className is 'Executable' and operation is 'deletion'
      expect(executables[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when removing existing executable
    service.remove 'Executable', executables[1], 'admin', (err, modelName, model) ->
      return done "Can't remove executable: #{err}" if err?
      # then the removed values are returned
      expect(model).to.exist
      expect(executables[1]).to.have.property('id').that.equal model.id

      # then the model do not exists anymore in DB
      Executable.findCached [model.id], (err, objs) ->
        expect(objs).to.have.lengthOf 0
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should remove delete existing map', (done) ->
    # then a deletion event was issued
    listener = (operation, className, instance)->
      return unless className is 'Map' and operation is 'deletion'
      expect(maps[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when removing existing map
    service.remove 'Map', maps[1], 'admin', (err, modelName, model) ->
      return done "Can't remove map: #{err}" if err?
      # then the removed values are returned
      expect(model).to.exist
      expect(maps[1]).to.have.property('id').that.equal model.id

      # then the model do not exists anymore in DB
      Map.findById model.id, (err, obj) ->
        expect(obj).not.to.exist
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should remove removes existing fields', (done) ->
    # given two existing field
    new Field({mapId: maps[0].id, typeId: fieldTypes[0].id, x:0, y:0}).save (err, field1) ->
      return done "Can't save field: #{err}" if err?
      new Field({mapId: maps[0].id, typeId: fieldTypes[1].id, x:0, y:1}).save (err, field2) ->
        return done "Can't save field: #{err}" if err?
        removed = []

        # then a deletion event was issued
        listener = (operation, className, instance)->
          expect(className).to.equal 'Field'
          expect(operation).to.equal 'deletion'
          removed.push instance
        watcher.on 'change', listener

        # when removing two existing fields
        service.remove 'Field', [field1, field2], 'admin', (err, modelName, returned) ->
          return done "Can't remove fields: #{err}" if err?
          # then the created values are returned
          expect(returned).to.have.lengthOf 2
          expect(returned[0]).to.satisfy (o) -> o.equals field2
          expect(returned[1]).to.satisfy (o) -> o.equals field1

          # then the model does exist in DB anymore
          Field.findById field1.id, (err, obj) ->
            return done "Can't find field in db #{err}" if err?
            expect(obj).not.to.exist
            Field.findById field2.id, (err, obj) ->
              return done "Can't find field in db #{err}" if err?
              expect(obj).not.to.exist
              # then the watcher was properly invoked
              expect(removed).to.have.lengthOf 2
              expect(returned[0]).to.satisfy (o) -> o.equals removed[0]
              expect(returned[1]).to.satisfy (o) -> o.equals removed[1]
              done()

  it 'should remove delete existing item', (done) ->
    # given an existing item
    new Item(type: itemTypes[0], map: maps[0], x:0, y:0, strength:20).save (err, item) ->
      return done err if err?
    
      # then a deletion event was issued
      listener = (operation, className, instance)->
        return unless className is 'Item' and operation is 'deletion'
        expect(item).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when removing an existing item
      service.remove 'Item', item.toJSON(), 'admin', (err, modelName, returned) ->
        return done "Can't remove item: #{err}" if err?
        # then the created values are returned
        expect(returned).to.exist
        expect(awaited, 'watcher was not as many times invoked as awaited').to.be.true
        expect(returned).to.satisfy (o) -> o.equals item

        # then the model exists in DB
        Item.findById returned.id, (err, obj) ->
          return done "Can't find item in db #{err}" if err?
          expect(obj).not.to.exist
          done()

  it 'should remove delete existing event', (done) ->
    # given an existing event
    new Event(type: eventTypes[0], content: 'héhé').save (err, event) ->
      return done err if err?
    
      # then a deletion event was issued
      listener = (operation, className, instance)->
        return unless className is 'Event' and operation is 'deletion'
        expect(event).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when removing an existing event
      service.remove 'Event', event.toJSON(), 'admin', (err, modelName, returned) ->
        return done "Can't remove event: #{err}" if err?
        # then the created values are returned
        expect(returned).to.exist
        expect(awaited, 'watcher was not as many times invoked as awaited').to.be.true
        expect(returned).to.satisfy (o) -> o.equals event

        # then the model exists in DB
        Event.findById returned.id, (err, obj) ->
          return done "Can't find event in db #{err}" if err?
          expect(obj).not.to.exist
          done()

  it 'should remove delete existing player', (done) ->
    # given an existing player
    new Player(email: 'jack', provider: null, password: 'yep').save (err, player) ->
      return done err if err?
    
      # then a deletion event was issued
      listener = (operation, className, instance)->
        return unless operation is 'deletion'
        expect(className).to.equal 'Player'
        expect(player).to.satisfy (o) -> o.equals instance
        awaited = true
      watcher.on 'change', listener

      # when removing an existing player
      service.remove 'Player', player.toJSON(), 'admin', (err, modelName, returned) ->
        return done "Can't remove player: #{err}" if err?
        # then the created values are returned
        expect(returned).to.exist
        expect(awaited, 'watcher was not as many times invoked as awaited').to.be.true
        expect(returned).to.satisfy (o) -> o.equals player

        # then the model exists in DB
        Player.findById returned.id, (err, obj) ->
          return done "Can't find player in db #{err}" if err?
          expect(obj).not.to.exist
          done()

  it 'should remove delete existing fsItem', (done) ->
    # then a deletion event was issued
    listener = (operation, className, instance)->
      return unless className is 'FSItem' and operation is 'deletion'
      expect(fsItem).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when removing existing fsItem
    service.remove 'FSItem', fsItem, 'admin', (err, modelName, model) ->
      return done "Can't remove fieldType: #{err}" if err?
      # then the removed values are returned
      expect(model).to.exist
      expect(fsItem).to.satisfy (o) -> o.equals model

      # then the model is not readable with authoring service
      authoringService.read fsItem, (err, obj) ->
        expect(err).to.include 'Unexisting item'
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should remove fails on non array parameter', (done) ->
    # when removing field without array
    service.remove 'Field', {mapId: maps[0].id, typeId: fieldTypes[0].id, x:0, y:0}, 'admin', (err, modelName, returned) ->
      # then nothing was removed
      expect(err).to.include 'Fields must be removed within an array'
      expect(modelName).to.equal 'Field'
      expect(returned).not.to.exist
      done()

  it 'should remove fails on unexisting fields', (done) ->
    # given an existing field
    new Field({mapId: maps[0].id, typeId: fieldTypes[0].id, x:0, y:0}).save (err, field) ->
      return done "Can't save field: #{err}" if err?
      
      removed = []

      # then a deletion event was issued
      listener = (operation, className, instance)->
        expect(className).to.equal 'Field'
        expect(operation).to.equal 'deletion'
        removed.push instance
      watcher.on 'change', listener

      # when removing an existing and a new fields
      unexisting = {id: fieldTypes[0].id, mapId: maps[0].id, typeId: fieldTypes[1].id, x:0, y:1}
      service.remove 'Field', [unexisting, field], 'admin', (err, modelName, returned) ->
        # then an error occured
        expect(err).to.equal "Unexisting field with id #{unexisting.id}"
        # then the created values are returned
        expect(returned).to.have.lengthOf 1
        expect(returned[0]).to.satisfy (o) -> o.equals field

        # then the model does exist in DB anymore
        Field.findById field.id, (err, obj) ->
          return done "Can't find field in db #{err}" if err?
          expect(obj).not.to.exist
          # then the watcher was properly invoked
          expect(removed).to.have.lengthOf 1
          expect(returned[0]).to.satisfy (o) -> o.equals removed[0]
          done()

  it 'should remove do nothing on empty array', (done) ->
    # when removing field with empty array
    service.remove 'Field', [], 'admin', (err, modelName, returned) ->
      # then nothing was saved
      return done "Unexpected error while saving fields: #{err}" if err?
      expect(modelName).to.equal 'Field'
      expect(returned).to.have.lengthOf 0
      done()

  it 'should remove delete existing configuration', (done) ->
    # then a deletion event was issued
    listener = (operation, className, instance)->
      return unless className is 'ClientConf' and operation is 'deletion'
      expect(confs[1]).to.satisfy (o) -> o.equals instance
      awaited = true
    watcher.on 'change', listener

    # when removing existing configuration
    service.remove 'ClientConf', confs[1], 'admin', (err, modelName, model) ->
      return done "Can't remove conf: #{err}" if err?
      # then the removed values are returned
      expect(model).to.exist
      expect(confs[1]).to.have.property('id').that.equal model.id

      # then the model do not exists anymore in DB
      ClientConf.findById model.id, (err, obj) ->
        expect(obj).not.to.exist
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should id unicity be globally checked', (done) ->
    # given all combination of existing names and models
    names = ['type1', 'type2', 'type3', 'type4', 'type5', 'type6', 'map1', 'map2', 'rule1', 'rule2']
    types = [{clazz: ItemType, args: {}, name: 'ItemType'}
      {clazz: EventType, args: {}, name: 'EventType'}
      {clazz: FieldType, args: {}, name: 'FieldType'}
      {clazz: Executable, args: {content:'# world'}, name: 'Executable'}
      {clazz: Map, args: {kind:'square'}, name: 'Map'}]
    async.forEach names, (name, next) ->
      async.forEach types, (type, next) ->
        # we cannot detect id reuse within executables
        return next() if type.name is 'Executable' and name in ['rule1', 'rule2']
        type.args.id = name
        # when saving the model with an executable id
        new type.clazz(type.args).save (err) ->
          # then an error is detected
          expect(err, "#{name} for #{type.name} did not report error").to.exist
          expect(err).to.have.property('message').that.equal "id #{name} for model #{type.name} is already used"
          next()
      , next
    , done

  it 'should id only contains word characers', (done) ->
    # given all combination of unallowed names and models
    names = ['type 1', 'type\'1', '', ';type1']
    types = [{clazz: ItemType, args: {}, name: 'ItemType'}
      {clazz: EventType, args: {}, name: 'EventType'}
      {clazz: FieldType, args: {}, name: 'FieldType'}
      {clazz: Executable, args: {content:'# world'}, name: 'Executable'}
      {clazz: Map, args: {kind:'square'}, name: 'Map'}]
    async.forEach names, (name, next) ->
      async.forEach types, (type, next) ->
        type.args.id = name
        # when saving the model with an unallowed id
        new type.clazz(type.args).save (err) ->
          # then an error is detected
          expect(err, "#{name} for #{type.name} did not report error").to.exist
          expect(err).to.have.property('message').that.equal "id #{name} for model #{type.name} is invalid"
          next()
      , next
    , done

  describe 'given a normal player and an administrator', ->

    player = null
    admin = null

    beforeEach (done) ->
      new Player(email: 'administrator', password:'toto', isAdmin: true).save (err, saved) ->
        return done err if err?
        admin = saved
        new Player(email: 'player', password:'toto').save (err, saved) ->
          player = saved
          done err

    afterEach (done) ->
      admin.remove (err) ->
        player.remove (err2) ->
          done err or err2

    it 'should connect as another player', (done) ->
      # when connecting as a player
      service.connectAs player.email, admin.email, (err, token) ->

        expect(err).not.to.exist
        expect(token).to.be.a('string').and.to.have.lengthOf 24

        # then player token was updated
        Player.findById player.id, (err, result) ->
          return done err if err?
          expect(result).to.have.property('token').that.equal token
          done()

    it 'should not connect if not administrator', (done) ->
      service.connectAs admin.email, player.email, (err, token) ->

        expect(err).to.include 'reserved'
        expect(token).not.to.exist

        # then player token was updated
        Player.findById admin.id, (err, result) ->
          return done err if err?
          expect(result).not.to.have.property 'token'
          done()

    it 'should not connect as unknown player', (done) ->
      service.connectAs 'someone', admin.email, (err, token) ->

        expect(err).to.include 'No player with email someone'
        expect(token).not.to.exist
        done()

    it 'should not connect as unknown administrator', (done) ->
      service.connectAs player.email, 'somebody', (err, token) ->

        expect(err).to.include 'No player with email somebody'
        expect(token).not.to.exist

        # then player token was updated
        Player.findById player.id, (err, result) ->
          return done err if err?
          expect(result).not.to.have.property 'token'
          done()