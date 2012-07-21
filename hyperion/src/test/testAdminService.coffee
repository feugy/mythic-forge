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

ItemType = require '../main/model/ItemType'
FieldType = require '../main/model/FieldType'
Executable = require '../main/model/Executable'
service = require('../main/service/AdminService').get()
watcher = require('../main/model/ModelWatcher').get()
testUtils = require './utils/testUtils'
utils = require '../main/utils'
assert = require('chai').assert
     
itemTypes = []
fieldTypes = []
executables = []

describe 'AdminService tests', -> 

  beforeEach (done) ->
    itemTypes = []
    executables = []
    fieldTypes = []
    testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
      Executable.resetAll -> 
        ItemType.collection.drop -> 
          FieldType.collection.drop ->
            # creates fixtures
            created = [
              {clazz: ItemType, args: {name: 'type 1'}, store: itemTypes}
              {clazz: ItemType, args: {name: 'type 2'}, store: itemTypes}
              {clazz: FieldType, args: {name: 'type 3'}, store: fieldTypes}
              {clazz: FieldType, args: {name: 'type 4'}, store: fieldTypes}
              {clazz: Executable, args: {_id: 'rule 1', content:'# hello'}, store: executables}
              {clazz: Executable, args: {_id: 'rule 2', content:'# world'}, store: executables}
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

  it 'should save fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when saving unallowed model
    service.save unknownModelName, {name:'type 3'}, (err, modelName, model) ->
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

    # when saving new item types
    service.save 'ItemType', values, (err, modelName, model) ->
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

    # when saving new field types
    service.save 'FieldType', values, (err, modelName, model) ->
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

    # when saving new item types
    service.save 'Executable', values, (err, modelName, model) ->
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

  it 'should save update existing item type', (done) ->
    # given existing values
    values = itemTypes[1]
    values.setProperty 'desc', 'string', 'to be defined'

    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'ItemType'
      assert.equal operation, 'update'
      assert.ok itemTypes[1].equals instance
      awaited = true

    # when saving existing item types
    service.save 'ItemType', values, (err, modelName, model) ->
      throw new Error "Can't save itemType: #{err}" if err?
      # then the created values are returned
      assert.ok model?
      assert.ok itemTypes[1]._id.equals model._id
      assert.equal model.get('name'), values.get('name')
      assert.ok 'desc' of model.get 'properties'
      assert.equal model.get( 'properties').desc.type, 'string'
      assert.equal model.get( 'properties').desc.def, 'to be defined'

      # then the model exists in DB
      ItemType.findById model._id, (err, obj) ->
        throw new Error "Can't find itemType in db #{err}" if err?
        assert.ok obj.equals model

        # then the model was updated, not created in DB
        ItemType.find {}, (err, list) ->
          throw new Error "Can't find itemTypes in db #{err}" if err?
          assert.equal list.length, 2
          assert.ok awaited, 'watcher wasn\'t invoked'
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

    # when saving existing field types
    service.save 'FieldType', values, (err, modelName, model) ->
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
    service.save 'Executable', executables[1], (err, modelName, model) ->
      assert.ok err?
      assert.equal err, "Id #{executables[1]._id} already used"
      done()

  it 'should remove fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when removing unallowed model
    service.remove unknownModelName, {_id:'4feab529ac7805980e000017'}, (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.equal err, "The #{unknownModelName} model can't be removed"
      assert.equal modelName, unknownModelName
      done()

  it 'should remove fails on unknown item type', (done) ->
    # when removing unknown item type
    service.remove 'ItemType', {_id:'4feab529ac7805980e000017'}, (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.ok 0 is err.indexOf "Unexisting ItemType"
      done()

  it 'should remove fails on unknown field type', (done) ->
    # when removing unknown field type
    service.remove 'FieldType', {_id:'4feab529ac7805980e000017'}, (err, modelName, model) ->
      # then an error occured
      assert.ok err?
      assert.ok 0 is err.indexOf "Unexisting FieldType"
      done()

  it 'should remove fails on unknown executable', (done) ->
    # when removing unknown item type
    service.remove 'Executable', {_id:'4feab529ac7805980e000017'}, (err, modelName, model) ->
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

    # when removing existing item types
    service.remove 'ItemType', itemTypes[1], (err, modelName, model) ->
      throw new Error "Can't remove itemType: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.ok itemTypes[1]._id.equals model._id

      # then the model do not exists anymore in DB
      ItemType.findById model._id, (err, obj) ->
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

    # when removing existing item types
    service.remove 'FieldType', fieldTypes[1], (err, modelName, model) ->
      throw new Error "Can't remove itemType: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.ok fieldTypes[1]._id.equals model._id

      # then the model do not exists anymore in DB
      FieldType.findById model._id, (err, obj) ->
        assert.ok obj is null
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
    service.remove 'Executable', executables[1], (err, modelName, model) ->
      throw new Error "Can't remove executable: #{err}" if err?
      # then the removed values are returned
      assert.ok model?
      assert.equal executables[1]._id, model._id

      # then the model do not exists anymore in DB
      Executable.findCached model._id, (err, obj) ->
        assert.ok obj is null
        assert.ok awaited, 'watcher wasn\'t invoked'
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