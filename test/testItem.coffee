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

Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
Map = require '../hyperion/src/model/Map'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
{expect} = require 'chai'

item = null
item2 = null
type = null
awaited = false

describe 'Item tests', -> 

  beforeEach (done) ->
    ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> ItemType.loadIdCache ->
      type = new ItemType id: 'warehouse'
      type.setProperty 'rocks', 'integer', 100
      type.save done

  afterEach (done) ->
    ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> ItemType.loadIdCache done

  it 'should item be created', (done) -> 
    # given a new Item
    item = new Item x: 10, y:-3, type:type

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      expect(className).to.equal 'Item'
      expect(operation).to.equal 'creation'
      expect(instance).to.satisfy (o) -> item.equals o
      awaited = true

    # when saving it
    awaited = false
    item.save (err) ->
      return done "Can't save item: #{err}" if err?

      # then it is in mongo
      Item.find {}, (err, docs) ->
        return done "Can't find item: #{err}" if err?
        # then it's the only one document
        expect(docs).to.have.lengthOf 1
        # then it's values were saved
        expect(docs[0]).to.have.property('x').that.equal 10
        expect(docs[0]).to.have.property('y').that.equal -3
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should new item have default properties values', (done) ->
    # when creating an item of this type
    item = new Item type: type
    item.save (err)->
      return done "Can't save item: #{err}" if err?
      # then the default value was set
      expect(item).to.have.property('rocks').that.equal 100
      done()

  describe 'given an Item', ->

    beforeEach (done) ->
      item = new Item x: 150, y: 300, type: type
      item.save done

    it 'should item be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Item'
        expect(operation).to.equal 'deletion'
        expect(instance).to.satisfy (o) -> item.equals o
        awaited = true

      # when removing an item
      awaited = false
      item.remove (err) ->
        return done err if err?

        # then it's not in mongo anymore
        Item.find {}, (err, docs) ->
          return done "Can't find item: #{err}" if err?
          expect(docs).to.have.lengthOf 0
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should item be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Item'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> item.equals o
        expect(instance).to.have.property('x').that.equal -100
        awaited = true

      # when modifying and saving an item
      item.x= -100
      awaited = false
      item.save ->

        Item.find {}, (err, docs) ->
          return done "Can't find item: #{err}" if err?
          # then it's the only one document
          expect(docs).to.have.lengthOf 1
          # then only the relevant values were modified
          expect(docs[0]).to.have.property('x').that.equal -100
          expect(docs[0]).to.have.property('y').that.equal 300
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should dynamic property be modified', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Item'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> item.equals o
        expect(instance).to.have.property('rocks').that.equal 200
        awaited = true

      # when modifying a dynamic property
      item.rocks= 200
      awaited = false

      item.save (err) ->
        return done err if err?

        Item.findOne {_id: item.id}, (err, doc) ->
          return done "Can't find item: #{err}" if err?
          # then only the relevant values were modified
          expect(doc).to.have.property('x').that.equal 150
          expect(doc).to.have.property('y').that.equal 300
          expect(doc).to.have.property('rocks').that.equal 200
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should item cannot be saved with unknown property', (done) ->
      # when saving an item with an unknown property
      item.set 'test', true
      item.save (err)->
        # then an error is raised
        expect(err).to.have.property('message').that.include 'unknown property test'
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
            expect(items).to.have.lengthOf 1

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
                expect(items).to.have.lengthOf 0
                expect(changes).to.have.lengthOf 2
                expect(changes[0][1]).to.equal 'Item'
                expect(changes[0][0]).to.equal 'deletion'
                expect(changes[1][1]).to.equal 'Map'
                expect(changes[1][0]).to.equal 'deletion'
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
          expect(saved).to.have.property('quantity').that.is.null
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
          expect(saved).to.have.property('quantity').that.equal 10
          # when setting quantity to null
          item.quantity= null
          item.save (err, saved) ->
            return done err if err?
            # then quantity is set to 0
            expect(saved).to.have.property('quantity').that.equal 0
            done()

  describe 'given a type with object properties and several Items', -> 

    beforeEach (done) ->
      type = new ItemType id: 'river'
      type.setProperty 'name', 'string', ''
      type.setProperty 'end', 'object', 'Item'
      type.setProperty 'affluents', 'array', 'Item'
      type.save ->
        Item.collection.drop -> Item.loadIdCache ->
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
        expect(doc).to.have.property('end').that.equal item.id
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an item
      Item.findOne {name: item.name}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # then linked arrays are replaced by their ids
        expect(doc).to.have.property('affluents').that.has.lengthOf 1
        expect(doc.affluents[0]).to.equal item2.id
        done()

    it 'should fetch retrieves linked objects', (done) ->
      # given a unresolved item
      Item.findOne {name: item2.name}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # when resolving it
        doc.fetch (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked items are provided
          expect(doc).to.have.deep.property('end.id').that.equal item.id
          expect(doc).to.have.deep.property('end.name').that.equal item.name
          expect(doc).to.have.deep.property('end.end').that.equal item.end
          expect(doc.end.affluents[0]).to.equal item.affluents[0]
          done()

    it 'should fetch retrieves linked arrays', (done) ->
      # given a unresolved item
      Item.findOne {name: item.name}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # when resolving it
        doc.fetch (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked items are provided
          expect(doc).to.have.property('affluents').that.has.lengthOf 1
          linked = doc.affluents[0]
          expect(linked).to.have.property('id').that.equal item2.id
          expect(linked).to.have.property('name').that.equal item2.name
          expect(linked).to.have.property('end').that.equal item2.end
          expect(linked).to.have.property('affluents').that.has.lengthOf 0
          done()

    it 'should fetch retrieves all properties of all objects', (done) ->
      # given a unresolved items
      Item.where().sort(name:'asc').exec (err, docs) ->
        return done "Can't find item: #{err}" if err?
        # when resolving them
        Item.fetch docs, (err, docs) ->
          return done "Can't resolve links: #{err}" if err?
          # then the first item has resolved links
          expect(docs[0]).to.have.deep.property('end.id').that.equal item.id
          expect(docs[0]).to.have.deep.property('end.name').that.equal item.name
          expect(docs[0]).to.have.deep.property('end.end').that.equal item.end
          expect(docs[0]).to.have.deep.property('end.affluents').that.has.lengthOf 1
          expect(docs[0].end.affluents[0]).to.have.property('id').that.equal item.affluents[0]
          # then the second item has resolved links
          expect(docs[1]).to.have.property('affluents').that.has.lengthOf 1
          linked = docs[1].affluents[0]
          expect(linked).to.have.property('id').that.equal item2.id
          expect(linked).to.have.property('name').that.equal item2.name
          expect(linked).to.have.deep.property('end.id').that.equal item2.end
          expect(linked).to.have.property('affluents').that.has.lengthOf 0
          done()

    it 'should fetch removes null in arrays', (done) ->
      # given nulls inside array
      item.affluents = [null, item2, null]
      item.save (err) ->
        return done err if err?
      
        # given an unresolved item
        Item.findById item.id, (err, doc) ->
          return done "Can't find item: #{err}" if err?
          expect(doc).to.have.property('affluents').that.has.lengthOf 1
          expect(doc.affluents[0]).to.be.a 'string'
          # when resolving it
          Item.fetch [doc], (err, docs) ->
            return done "Can't resolve links: #{err}" if err?
            # then the property does not contains nulls anymore
            expect(docs[0]).to.satisfy (o) -> item.equals o
            expect(docs[0]).to.have.property('affluents').that.has.lengthOf 1
            expect(docs[0].affluents[0]).to.satisfy (o) -> item2.equals o
            done()

    it 'should modelWatcher send linked objects ids and not full objects', (done) ->
      # given a modification on linked properties
      item2.affluents.push item
      item2.end = item2

      # then a modification was detected on modified properties
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Item'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> item2.equals o
        # then modified object ids are shipped
        expect(instance).to.have.deep.property('id').that.equal item2.end
        expect(instance).to.have.deep.property('affluents').that.has.lengthOf 1
        expect(instance.affluents[0]).to.equal item.id
        awaited = true

      # when saving it
      awaited = false
      item2.save (err, saved) ->
        return done err if err?

        # then the saved object has object ids instead of full objects
        expect(saved).to.satisfy (o) -> item2.equals o
        expect(saved).to.have.deep.property('end').that.equal item2.id
        expect(saved).to.have.deep.property('affluents').that.has.lengthOf 1
        expect(saved.affluents[0]).to.equal item.id
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  describe 'given a type with json property', -> 

    beforeEach (done) ->
      type = new ItemType id: 'squad'
      type.setProperty 'name', 'string', ''
      type.setProperty 'prefs', 'json', {}
      type.save (err, saved) ->
        return done err if err?
        type = saved
        done()

    it 'should modification on json property be detected', (done) ->
      # given an item
      new Item(name: 'crimson', prefs:{imperium:true}, type:type).save (err, item) ->
        return done err if err?

        # when modifying its name
        item.name = 'crimson2'

        # then only name is detected as modified
        expect(item.isModified 'name').to.be.true
        expect(item.isModified 'prefs').to.be.false

        # when modifying its prefs
        item.prefs = imperium:false

        # then both properties are detected as modified
        expect(item.isModified 'name').to.be.true
        expect(item.isModified 'prefs').to.be.true

        item.save (err, result) ->
          return done err if err?
          expect(result).to.have.property('name').that.equal 'crimson2'
          expect(result).to.have.property('prefs').that.deep.equal imperium:false
          done()