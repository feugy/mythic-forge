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
service = require('../main/service/AdminService').get()
watcher = require('../main/model/ModelWatcher').get()
assert = require('chai').assert
     
itemTypes = []

describe 'AdminService tests', -> 

  beforeEach (done) ->
    itemTypes = []
    ItemType.collection.drop -> 
      # creates fixtures
      created = [
        {clazz: ItemType, args: {name: 'type 1'}, store: itemTypes},
        {clazz: ItemType, args: {name: 'type 2'}, store: itemTypes}
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
    values = {name: 'type 3', properties:{health:{def:0, type:'integer'}}}
   
    awaited = false
    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'ItemType'
      assert.equal operation, 'creation'
      assert.equal instance._name.default, 'type 3'
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

  it 'should remove fails on unallowed model', (done) ->
    unknownModelName = 'toto'
    # when removing unallowed model
    service.remove unknownModelName, {_id:'4feab529ac7805980e000017'}, (err, modelName, model) ->
      # then an error occured
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

  it 'should remove delete existing item type', (done) ->
    awaited = false
    # then a creation event was issued
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
