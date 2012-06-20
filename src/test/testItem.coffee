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

item = null
item2 = null
type = null
awaited = false

describe 'Item tests', -> 

  beforeEach (done) ->
    type = new ItemType({name: 'plain'})
    type.setProperty 'rocks', 'integer', 100
    type.save (err, saved) ->
      throw new Error err if err?
      Item.collection.drop -> done()

  afterEach (end) ->
    ItemType.collection.drop -> Item.collection.drop -> end()

  it 'should item be created', (done) -> 
    # given a new Item
    item = new Item {x: 10, y:-3, type:type}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal 'Item', className
      assert.equal 'creation', operation
      assert.ok item.equals instance
      awaited = true

    # when saving it
    awaited = false
    item.save (err) ->
      throw new Error "Can't save item: #{err}" if err?

      # then it is in mongo
      Item.find {}, (err, docs) ->
        throw new Error "Can't find item: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal 10, docs[0].get 'x'
        assert.equal -3, docs[0].get 'y'
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should new item have default properties values', (done) ->
    # when creating an item of this type
    item = new Item {type: type}
    item.save (err)->
      throw new Error "Can't save item: #{err}" if err?
      # then the default value was set
      assert.equal 100, item.get 'rocks'
      done()

  describe 'given an Item', ->

    beforeEach (done) ->
      item = new Item {x: 150, y: 300, type: type}
      item.save -> done()

    it 'should item be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal 'Item', className
        assert.equal 'deletion', operation
        assert.ok item.equals instance
        awaited = true

      # when removing an item
      awaited = false
      item.remove ->

        # then it's not in mongo anymore
        Item.find {}, (err, docs) ->
          throw new Error "Can't find item: #{err}" if err?
          assert.equal docs.length, 0
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should item be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal 'Item', className
        assert.equal 'update', operation
        assert.ok item.equals instance
        assert.equal -100, instance.x
        awaited = true

      # when modifying and saving an item
      item.set 'x', -100
      awaited = false
      item.save ->

        Item.find {}, (err, docs) ->
          throw new Error "Can't find item: #{err}" if err?
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal -100, docs[0].get 'x'
          assert.equal 300, docs[0].get 'y'
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should dynamic property be modified', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal 'Item', className
        assert.equal 'update', operation
        assert.ok item.equals instance
        assert.equal 200, instance.rocks
        awaited = true

      # when modifying a dynamic property
      item.set 'rocks', 200
      awaited = false
      item.save ->

        Item.findOne {_id: item._id}, (err, doc) ->
          throw new Error "Can't find item: #{err}" if err?
          # then only the relevant values were modified
          assert.equal 150, doc.get 'x'
          assert.equal 300, doc.get 'y'
          assert.equal 200, doc.get 'rocks'
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should item cannot be saved with unknown property', (done) ->
      # when saving an item with an unknown property
      item.set 'test', true
      item.save (err)->
        # then an error is raised
        assert.fail 'An error must be raised when saving item with unknown property' if !err
        assert.ok err?.message.indexOf('unknown property test') isnt -1
        done()

  describe 'given a type with object properties and several Items', -> 

    beforeEach (done) ->
      type = new ItemType {name: 'river'}
      type.setProperty 'name', 'string', ''
      type.setProperty 'end', 'object', 'Item'
      type.setProperty 'affluents', 'array', 'Item'
      type.save ->
        Item.collection.drop -> 
          item = new Item {name: 'Rhône', end: null, type: type, affluents:[]}
          item.save (err, saved) ->
            throw new Error err  if err?
            item = saved
            item2 = new Item {name: 'Durance', end: item, type: type, affluents:[]}
            item2.save (err, saved) -> 
              throw new Error err  if err?
              item2 = saved
              item.set 'affluents', [item2]
              item.save (err) ->
                throw new Error err  if err?
                done()

    it 'should id be stored for linked object', (done) ->
      # when retrieving an item
      Item.findOne {name: item2.get 'name'}, (err, doc) ->
        throw new Error "Can't find item: #{err}" if err?
        # then linked items are replaced by their ids
        assert.ok item._id.equals doc.get('end')
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an item
      Item.findOne {name: item.get 'name'}, (err, doc) ->
        throw new Error "Can't find item: #{err}" if err?
        # then linked arrays are replaced by their ids
        assert.equal 1, doc.get('affluents').length
        assert.ok item2._id.equals doc.get('affluents')[0]
        done()

    it 'should resolve retrieves linked objects', (done) ->
      # given a unresolved item
      Item.findOne {name: item2.get 'name'}, (err, doc) ->
        throw new Error "Can't find item: #{err}" if err?
        # when resolving it
        doc.resolve (err, doc) ->
          throw new Error "Can't resolve links: #{err}" if err?
          # then linked items are provided
          assert.ok item._id.equals doc.get('end')._id
          assert.equal item.get('name'), doc.get('end').get('name')
          assert.equal item.get('end'), doc.get('end').get('end')
          assert.equal item.get('affluents')[0], doc.get('end').get('affluents')[0]
          done()

    it 'should resolve retrieves linked arrays', (done) ->
      # given a unresolved item
      Item.findOne {name: item.get 'name'}, (err, doc) ->
        throw new Error "Can't find item: #{err}" if err?
        # when resolving it
        doc.resolve (err, doc) ->
          throw new Error "Can't resolve links: #{err}" if err?
          # then linked items are provided
          assert.equal 1, doc.get('affluents').length
          linked = doc.get('affluents')[0]
          assert.ok item2._id.equals linked._id
          assert.equal item2.get('name'), linked.get('name')
          assert.equal item2.get('end'), linked.get('end')
          assert.equal 0, linked.get('affluents').length
          done()

    it 'should multi-resolve retrieves all properties of all objects', (done) ->
      # given a unresolved items
      Item.where().asc('name').run (err, docs) ->
        throw new Error "Can't find item: #{err}" if err?
        # when resolving them
        Item.multiResolve docs, (err, docs) ->
          throw new Error "Can't resolve links: #{err}" if err?
          # then the first item has resolved links
          assert.ok item._id.equals docs[0].get('end')._id
          assert.equal item.get('name'), docs[0].get('end').get('name')
          assert.equal item.get('end'), docs[0].get('end').get('end')
          assert.equal item.get('affluents')[0], docs[0].get('end').get('affluents')[0]
          # then the second item has resolved links
          assert.equal 1, docs[1].get('affluents').length
          linked = docs[1].get('affluents')[0]
          assert.ok item2._id.equals linked._id
          assert.equal item2.get('name'), linked.get('name')
          assert.equal item2.get('end'), linked.get('end')
          assert.equal 0, linked.get('affluents').length
          done()
