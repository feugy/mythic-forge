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

Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
Map = require '../hyperion/src/model/Map'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
assert = require('chai').assert

item = null
item2 = null
type = null
awaited = false

describe 'Item tests', -> 

  beforeEach (done) ->
    ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> ItemType.loadIdCache ->
      type = new ItemType id: 'plain'
      type.setProperty 'rocks', 'integer', 100
      type.save done

  afterEach (done) ->
    ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> ItemType.loadIdCache done

  it 'should item be created', (done) -> 
    # given a new Item
    item = new Item x: 10, y:-3, type:type

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Item'
      assert.equal operation, 'creation'
      assert.ok item.equals instance
      awaited = true

    # when saving it
    awaited = false
    item.save (err) ->
      return done "Can't save item: #{err}" if err?

      # then it is in mongo
      Item.find {}, (err, docs) ->
        return done "Can't find item: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal docs[0].x, 10
        assert.equal docs[0].y, -3
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should new item have default properties values', (done) ->
    # when creating an item of this type
    item = new Item type: type
    item.save (err)->
      return done "Can't save item: #{err}" if err?
      # then the default value was set
      assert.equal item.rocks, 100
      done()

  describe 'given an Item', ->

    beforeEach (done) ->
      item = new Item x: 150, y: 300, type: type
      item.save done

    it 'should item be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'deletion'
        assert.ok item.equals instance
        awaited = true

      # when removing an item
      awaited = false
      item.remove (err) ->
        return done err if err?

        # then it's not in mongo anymore
        Item.find {}, (err, docs) ->
          return done "Can't find item: #{err}" if err?
          assert.equal docs.length, 0
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should item be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'update'
        assert.ok item.equals instance
        assert.equal instance.x, -100
        awaited = true

      # when modifying and saving an item
      item.x= -100
      awaited = false
      item.save ->

        Item.find {}, (err, docs) ->
          return done "Can't find item: #{err}" if err?
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal docs[0].x, -100
          assert.equal docs[0].y, 300
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should dynamic property be modified', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'update'
        assert.ok item.equals instance
        assert.equal instance.rocks, 200
        awaited = true

      # when modifying a dynamic property
      item.rocks= 200
      awaited = false

      item.save (err) ->
        return done err if err?

        Item.findOne {_id: item.id}, (err, doc) ->
          return done "Can't find item: #{err}" if err?
          # then only the relevant values were modified
          assert.equal doc.x, 150
          assert.equal doc.y, 300
          assert.equal doc.rocks, 200
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

    it 'should item be removed with map', (done) ->
      # given a map
      map = new Map(id: 'map1').save (err, map) ->
        return done err if err?
        # given a map item
        new Item(map: map, x: 0, y: 0, type: type).save (err, item2) ->
          return done err if err?
          Item.find {map: map.id}, (err, items) ->
            return done err if err?
            assert.equal items.length, 1

            changes = []
            # then only a removal event was issued
            watcher.on 'change', listener = (operation, className, instance) ->
              changes.push arguments

            # when removing the map
            map.remove (err) ->
              return done "Failed to remove map: #{err}" if err?

              # then items are not in mongo anymore
              Item.find {map: map.id}, (err, items) ->
                return done err if err?
                assert.equal items.length, 0
                assert.equal 1, changes.length, 'watcher wasn\'t invoked'
                assert.equal changes[0][1], 'Map'
                assert.equal changes[0][0], 'deletion'
                watcher.removeListener 'change', listener
                done()

    it 'should quantity not be set on unquantifiable type', (done) ->
      # given a unquantifiable type
      type.quantifiable= false
      type.save (err) ->
        return done err if err?
        # when setting quantity on item
        item.quantity= 10
        item.save (err, saved) ->
          return done err if err?
          # then quantity is set to null
          assert.isNull saved.quantity
          done()

    it 'should quantity be set on quantifiable type', (done) ->
      # given a unquantifiable type
      type.quantifiable= true
      type.save (err) ->
        return done err if err?
        # when setting quantity on item
        item.quantity= 10
        item.save (err, saved) ->
          return done err if err?
          # then quantity is set to relevant quantity
          assert.equal 10, saved.quantity
          # when setting quantity to null
          item.quantity= null
          item.save (err, saved) ->
            return done err if err?
            # then quantity is set to 0
            assert.equal 0, saved.quantity
            done()

  describe 'given a type with object properties and several Items', -> 

    beforeEach (done) ->
      type = new ItemType id: 'river'
      type.setProperty 'name', 'string', ''
      type.setProperty 'end', 'object', 'Item'
      type.setProperty 'affluents', 'array', 'Item'
      type.save ->
        Item.collection.drop -> 
          item = new Item {name: 'Rhône', end: null, type: type, affluents:[]}
          item.save (err, saved) ->
            return done err  if err?
            item = saved
            item2 = new Item {name: 'Durance', end: item, type: type, affluents:[]}
            item2.save (err, saved) -> 
              return done err  if err?
              item2 = saved
              item.affluents= [item2]
              item.save (err) ->
                return done err  if err?
                done()

    it 'should id be stored for linked object', (done) ->
      # when retrieving an item
      Item.findOne {name: item2.name}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # then linked items are replaced by their ids
        assert.equal item.id, doc.end
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an item
      Item.findOne {name: item.name}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # then linked arrays are replaced by their ids
        assert.equal doc.affluents.length, 1
        assert.equal item2.id, doc.affluents[0]
        done()

    it 'should getLinked retrieves linked objects', (done) ->
      # given a unresolved item
      Item.findOne {name: item2.name}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # when resolving it
        doc.getLinked (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked items are provided
          assert.equal item.id, doc.end.id
          assert.equal doc.end.name, item.name
          assert.equal doc.end.end, item.end
          assert.equal doc.end.affluents[0], item.affluents[0]
          done()

    it 'should getLinked retrieves linked arrays', (done) ->
      # given a unresolved item
      Item.findOne {name: item.name}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # when resolving it
        doc.getLinked (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked items are provided
          assert.equal doc.affluents.length, 1
          linked = doc.affluents[0]
          assert.equal item2.id, linked.id
          assert.equal linked.name, item2.name
          assert.equal linked.end, item2.end
          assert.equal linked.affluents.length, 0
          done()

    it 'should getLinked retrieves all properties of all objects', (done) ->
      # given a unresolved items
      Item.where().sort(name:'asc').exec (err, docs) ->
        return done "Can't find item: #{err}" if err?
        # when resolving them
        Item.getLinked docs, (err, docs) ->
          return done "Can't resolve links: #{err}" if err?
          # then the first item has resolved links
          assert.equal item.id, docs[0].end.id
          assert.equal docs[0].end.name, item.name
          assert.equal docs[0].end.end, item.end
          assert.equal docs[0].end.affluents[0], item.affluents[0]
          # then the second item has resolved links
          assert.equal docs[1].affluents.length, 1
          linked = docs[1].affluents[0]
          assert.equal item2.id, linked.id
          assert.equal linked.name, item2.name
          assert.equal linked.end, item2.end
          assert.equal linked.affluents.length, 0
          done()

    it 'should getLinked removes null in arrays', (done) ->
      # given nulls inside array
      item.affluents = [null, item2, null]
      item.save (err) ->
        return done err if err?
      
        # given an unresolved item
        Item.findById item.id, (err, doc) ->
          return done "Can't find item: #{err}" if err?
          assert.equal doc.affluents.length, 1
          assert.equal utils.type(doc.affluents[0]), 'string'
          # when resolving it
          Item.getLinked [doc], (err, docs) ->
            return done "Can't resolve links: #{err}" if err?
            # then the property does not contains nulls anymore
            assert.ok item.equals docs[0]
            assert.equal docs[0].affluents.length, 1
            assert.ok item2.equals docs[0].affluents[0]
            done()

    it 'should modelWatcher send linked objects ids and not full objects', (done) ->
      # given a modification on linked properties
      item2.affluents.push item
      item2.markModified 'affluents'
      item2.end = item2

      # then a modification was detected on modified properties
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'update'
        assert.ok item2.equals instance
        # then modified object ids are shipped
        assert.equal item2.id, instance.end
        assert.equal instance.affluents?.length, 1
        assert.equal item.id, instance.affluents[0]
        awaited = true

      # when saving it
      awaited = false
      item2.save (err, saved) ->
        return done err if err?

        # then the saved object has object ids instead of full objects
        assert.ok item2.equals saved
        assert.equal item2.id, saved.end
        assert.equal saved.affluents?.length, 1
        assert.equal item.id, saved.affluents[0]
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()