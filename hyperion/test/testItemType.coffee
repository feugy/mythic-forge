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

Item = require '../src/model/Item'
ItemType = require '../src/model/ItemType'
watcher = require('../src/model/ModelWatcher').get()
assert = require('chai').assert

item1 = null
item2 = null
item3 = null
type = null

describe 'ItemType tests', -> 

  beforeEach (done) ->
    # empty items and types.
    Item.collection.drop -> ItemType.collection.drop -> done()

  afterEach (done) ->
    # remove all listeners
    watcher.removeAllListeners 'change'
    done()

  it 'should type\'s properties be distinct', (done) ->
    # given a type with a property
    type = new ItemType({name: 'vehicule'})
    type.setProperty 'wheels', 'integer', 4
    type.save (err) ->
      return done err if err?
      # when creating another type with distinct property
      type2 = new ItemType({name: 'animal'})
      type2.setProperty 'mammal', 'boolean', true
      type2.save (err) ->
        return done err if err?
        # then their properties ar not mixed
        keys = Object.keys(type.properties)
        keys2 = Object.keys(type2.properties)
        assert.equal keys.length, 1 
        assert.equal keys[0], 'wheels'
        assert.equal keys2.length, 1
        assert.equal keys2[0], 'mammal'
        done()

  it 'should type be created', (done) -> 
    # given a new ItemType
    type = new ItemType()
    name = 'montain'
    type.name = name

    # when saving it
    type.save (err, saved) ->
      return done "Can't save type: #{err}" if err?

      # then it is in mongo
      ItemType.find {}, (err, types) ->
        # then it's the only one document
        assert.equal types.length, 1
        # then it's values were saved
        assert.equal types[0].name, name
        done()

  it 'should name and desc be internationalizables', (done) -> 
    # given a new ItemType with translated name
    type = new ItemType()
    name = 'dust'
    type.name = name
    type.locale = 'fr'
    nameFr = 'poussière'
    type.name = nameFr

    # when saving it
    type.save (err, saved) ->
      return done "Can't save type: #{err}" if err?

      # then translations are available
      saved.locale = null
      assert.equal saved.name, name
      saved.locale = 'fr'
      assert.equal saved.name, nameFr

      # when setting the tanslated description and saving it
      saved.locale = null
      desc = 'another one bites the dust'
      saved.desc = desc
      saved.locale = 'fr'
      descFr = 'encore un qui mort la poussière' 
      saved.desc = descFr

      saved.save (err, saved) ->
        return done "Can't save type: #{err}" if err?

        # then it is in mongo
        ItemType.find {}, (err, types) ->
          # then it's the only one document
          assert.equal 1, types.length
          # then it's values were saved
          assert.equal types[0].name, name
          assert.equal types[0].desc, desc
          types[0].locale = 'fr'
          assert.equal types[0].name, nameFr
          assert.equal types[0].desc, descFr
          done()

  it 'should date property always be stores as Date', (done) -> 
    # given a new ItemType with a null time property
    type = new ItemType()
    name = 'test-date'
    type.setProperty 'time', 'date', null
    # when saving it
    type.save (err, saved) ->
      return done err if err?

      # then the default time value is null
      assert.property saved.properties, 'time'
      assert.isNull saved.properties.time.def
      type = saved
          
      # then a saved instance will have a null default value
      new Item(type: type).save (err, saved) ->
        return done err if err?

        assert.isNull saved.time

        # when setting the default value to a valid string
        type.setProperty 'time', 'date', "2012-10-12T08:00:00.000Z"
        type.save (err, saved) ->
          return done err if err?

          # then the default value is a date
          assert.instanceOf saved.properties.time.def, Date 
          assert.deepEqual saved.properties.time.def, new Date("2012-10-12T08:00:00.000Z")
          type = saved

           # then a saved instance will have a date default value
          new Item(type: type).save (err, saved) ->
            return done err if err?

            assert.instanceOf saved.time, Date
            assert.deepEqual saved.time, new Date("2012-10-12T08:00:00.000Z")

            # when setting the default value to a valid date
            time = new Date()
            type.setProperty 'time', 'date', time
            type.save (err, saved) ->
              return done err if err?

              # then the default value is a date
              assert.instanceOf saved.properties.time.def, Date 
              assert.deepEqual saved.properties.time.def, time
              type = saved

              # then a saved instance will have a date default value
              new Item(type: type).save (err, saved) ->
                return done err if err? 

                assert.instanceOf saved.time, Date
                assert.deepEqual saved.time, time

                # when saving an instance with an invalid date
                new Item(type: type, time: "invalid").save (err) ->
                  # then an error is raised
                  assert.include err, 'not a valid date'

                  # when saving the type property instance with an invalid date
                  type.setProperty 'time', 'date', "true"
                  type.save (err, saved) ->
                    # then an error is raised
                    assert.include err, 'not a valid date'
                    done()

  describe 'given a type with a property', ->
    beforeEach (done) ->
      # creates a type with a property color which is a string.
      type = new ItemType()
      type.name = 'river'
      type.setProperty 'color', 'string', 'blue'
      type.save (err, saved) -> 
        type = saved
        done err

    afterEach (done) ->
      # removes the type at the end.
      ItemType.collection.drop -> Item.collection.drop -> done()

    it 'should type be removed', (done) ->
      # when removing an item
      type.remove (err) ->
        return done err if err?
        # then it's in mongo anymore
        ItemType.find {}, (err, types) ->
          return done err if err?
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
          assert.equal types[0].name, 'river',
          assert.ok 'depth' of types[0].properties, 'no depth in properties'
          assert.equal types[0].properties.depth?.type, 'integer'
          assert.equal types[0].properties.depth?.def, 10
          done()

    it 'should type properties be updated', (done) ->
      assert.ok 'color' of type.properties, 'no color in properties'
      assert.equal type.properties.color?.type, 'string'
      assert.equal type.properties.color?.def, 'blue'

      # when updating a property 
      type.setProperty 'color', 'integer', 10
      type.save (err, saved) ->
        # then the property was updated
        assert.equal saved.properties.color?.type, 'integer'
        assert.equal saved.properties.color?.def, 10
        done()

    it 'should type properties be removed', (done) ->
      # when removing a property
      type.unsetProperty 'color'
      type.save (err, saved) ->
        if err? 
          assert.fail "Can't save item: #{err}"
          return done()

        # then the property was removed
        assert.ok not ('color' of saved.properties), 'color still in properties'
        done()

    it 'should unknown type properties fail on remove', (done) ->
      try 
        # when removing an unknown property
        type.unsetProperty 'unknown'
        assert.fail 'Error must be raised when removing unknwown property'
      catch err
        # then an error is thrown
        assert.equal err?.message, 'Unknown property unknown for type river'
      done()

  describe 'given a type and some items', ->

    beforeEach (done) ->
      # creates a type with a string property 'color' and an array property 'affluents'.
      type = new ItemType {name: 'river'}
      type.setProperty 'color', 'string', 'blue'
      type.setProperty 'affluents', 'array', 'Item'
      type.save (err) -> 
        return done err if err?
        # creates three items of this type.
        item1 = new Item {type: type, affluents: []}
        item1.save (err) ->
          return done err if err?
          item2 = new Item {type: type, affluents: []}
          item2.save (err) ->
            return done err if err?
            item3 = new Item {type: type, affluents: []}
            item3.save (err) ->
              done err

    it 'should existing items be updated when setting a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', (operation, className, instance)->
        return if className isnt 'Item'
        updates.push instance._id.toString()
        assert.equal operation, 'update'
        assert.equal instance.depth, 30

      # when setting a property to a type
      defaultDepth = 30
      type.setProperty 'depth', 'integer', defaultDepth
      type.save (err) -> 
        return done err if err?
        next = ->
          Item.find {type: type._id}, (err, items) ->
            for item in items
              assert.isDefined item.depth
              assert.equal item.depth, defaultDepth
              assert.ok item._id.toString() in updates
            done()
        setTimeout next, 500

    it 'should existing items be updated when removing a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', (operation, className, instance)->
        return if className isnt 'Item'
        assert.equal operation, 'update'
        updates.push instance._id.toString()
        assert.ok instance.color is undefined

      # when setting a property to a type
      defaultDepth = 30
      type.unsetProperty 'color'
      type.save (err) -> 
        next done err if err?
        next = ->
          Item.find {type: type._id}, (err, items) ->
            return done err if err?
            for item in items
              assert.ok undefined is item.color, 'color still present'
              assert.ok item._id.toString() in updates
            done()
        setTimeout next, 50

    it 'should items be updated when modifying quantifiable state', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', (operation, className, instance)->
        return if className isnt 'Item'
        assert.equal operation, 'update'
        updates.push instance._id.toString()
        assert.ok instance.color is undefined

      # when setting quantifiable to true
      type.quantifiable = true
      type.save (err) -> 
        return done err if err?

        next = ->
          Item.find {type: type._id}, (err, items) ->
            return done err if err?
            # then all items have their quantity to 0
            for item in items
              assert.equal 0, item.quantity , 'quantity not set to 0'
              assert.ok item._id.toString() in updates

            # when setting quantifiable to false
            type.quantifiable = false
            type.save (err) -> 
              return done err if err?
              next2 = ->
                Item.find {type: type._id}, (err, items) ->
                  # then all
                  for item in items
                    assert.isNull item.quantity , 'quantity not set to null'
                    assert.ok item._id.toString() in updates
                  done()

              setTimeout next2, 50

        setTimeout next, 50