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

Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
watcher = require('../main/model/ModelWatcher').get()
assert = require('chai').assert

item1 = null
item2 = null
item3 = null
type = null

describe 'ItemType tests', -> 

  beforeEach (done) ->
    # empty items and types.
    Item.collection.drop -> ItemType.collection.drop -> done()

  it 'should type\'s properties be distinct', (done) ->
    # given a type with a property
    type = new ItemType({name: 'vehicule'})
    type.setProperty 'wheels', 'integer', 4
    type.save (err) ->
      if (err?)
        throw new Error err
        done()
      # when creating another type with distinct property
      type2 = new ItemType({name: 'animal'})
      type2.setProperty 'mammal', 'boolean', true
      type2.save (err) ->
        if (err?)
          throw new Error err
          done()
        # then their properties ar not mixed
        keys = Object.keys(type.get('properties'))
        keys2 = Object.keys(type2.get('properties'))
        assert.equal 1, keys.length 
        assert.equal 'wheels', keys[0] 
        assert.equal 1, keys2.length
        assert.equal 'mammal', keys2[0]
        done()

   it 'should type be created', (done) -> 
    # given a new ItemType
    type = new ItemType()
    name = 'montain'
    type.set 'name', name

    # when saving it
    type.save (err, saved) ->
      if err? 
        assert.fail "Can't save type: #{err}"
        return done()

      # then it is in mongo
      ItemType.find {}, (err, types) ->
        # then it's the only one document
        assert.equal types.length, 1
        # then it's values were saved
        assert.equal name, types[0].get 'name'
        done()

  describe 'given a type with a property', ->
    beforeEach (done) ->
      # creates a type with a property color which is a string.
      type = new ItemType()
      type.set 'name', 'river'
      type.setProperty 'color', 'string', 'blue'
      type.save (err, saved) -> 
        type = saved
        done()

    afterEach (done) ->
      # removes the type at the end.
      ItemType.collection.drop -> Item.collection.drop -> done()

    it 'should type be removed', (done) ->
      # when removing an item
      type.remove ->

      # then it's in mongo anymore
      ItemType.find {}, (err, types) ->
        assert.equal types.length, 0
        done()

    it 'should type properties be created', (done) ->
      # when adding a property
      type.setProperty 'depth', 'integer', 10
      type.save ->

        ItemType.find {}, (err, types) ->
          # then it's the only one document
          assert.equal types.length, 1
          # then only the relevant values were modified
          assert.equal 'river', types[0].get 'name'
          assert.ok 'depth' of types[0].get('properties'), 'no depth in properties'
          assert.equal 'integer',  types[0].get('properties').depth?.type
          assert.equal 10, types[0].get('properties').depth?.def
          done()

    it 'should type properties be updated', (done) ->
      assert.ok 'color' of type.get('properties'), 'no color in properties'
      assert.equal 'string',  type.get('properties').color?.type
      assert.equal 'blue',  type.get('properties').color?.def

      # when updating a property 
      type.setProperty 'color', 'integer', 10
      type.save (err, saved) ->
        # then the property was updated
        assert.equal 'integer',  saved.get('properties').color?.type
        assert.equal 10,  saved.get('properties').color?.def
        done()

    it 'should type properties be removed', (done) ->
      # when removing a property
      type.unsetProperty 'color'
      type.save (err, saved) ->
        if err? 
          assert.fail "Can't save item: #{err}"
          return done()

        # then the property was removed
        assert.ok not ('color' of saved.get('properties')), 'color still in properties'
        done()

    it 'should unknown type properties fail on remove', (done) ->
      try 
        # when removing an unknown property
        type.unsetProperty 'unknown'
        assert.fail 'Error must be raised when removing unknwown property'
      catch err
        # then an error is thrown
        assert.equal 'Unknown property unknown for item type river', err?.message
      done()

  describe 'given a type and some items', ->

    beforeEach (done) ->
      # creates a type with a string property 'color' and an array property 'affluents'.
      type = new ItemType {name: 'river'}
      type.setProperty 'color', 'string', 'blue'
      type.setProperty 'affluents', 'array', 'Item'
      type.save (err, saved) -> 
        throw new Error(err) if err?
        type = saved
        # creates three items of this type.
        item1 = new Item {type: type, affluents: []}
        item1.save (err) ->
          throw new Error(err) if err?
          item2 = new Item {type: type, affluents: []}
          item2.save (err) ->
            throw new Error(err) if err?
            item3 = new Item {type: type, affluents: []}
            item3.save (err) -> 
              throw new Error(err) if err?
              done()

    it 'should existing items be updated when setting a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', (operation, className, instance)->
        updates.push instance._id+''
        assert.equal 'Item', className
        assert.equal 'update', operation
        assert.equal 30, instance.depth

      # when setting a property to a type
      defaultDepth = 30
      type.setProperty 'depth', 'integer', defaultDepth
      type.save (err) -> 
        block = ->
          Item.find {type: type._id}, (err, items) ->
            for item in items
              assert.equal defaultDepth, item.get 'depth'
              assert.ok item._id+'' in updates
            watcher.removeAllListeners 'change'
            done()
        setTimeout block, 50

    it 'should existing items be updated when removing a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', (operation,className, instance)->
        assert.equal 'Item', className
        assert.equal 'update', operation
        updates.push instance._id+''
        assert.ok instance.color is undefined

      # when setting a property to a type
      defaultDepth = 30
      type.unsetProperty 'color'
      type.save (err) -> 
        block = ->
          Item.find {type: type._id}, (err, items) ->
            for item in items
              assert.ok undefined is item.get('color'), 'color still present'
              assert.ok item._id+'' in updates
            watcher.removeAllListeners 'change'
            done()
        setTimeout block, 50