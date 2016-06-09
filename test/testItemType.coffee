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
typeFactory = require '../hyperion/src/model/typeFactory'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
{expect} = require 'chai'

item1 = null
item2 = null
item3 = null
type = null

describe 'ItemType tests', ->

  listener = null

  beforeEach (done) ->
    listener = null
    # empty items and types.
    Item.remove {}, -> ItemType.remove {}, -> Item.loadIdCache done

  afterEach (done) ->
    # remove all listeners
    watcher.removeListener 'change', listener if listener?
    done()

  it 'should type\'s properties be distinct', (done) ->
    # given a type with a property
    type = new ItemType({id: 'vehicule'})
    type.setProperty 'wheels', 'integer', 4
    type.save (err) ->
      return done err if err?
      # when creating another type with distinct property
      type2 = new ItemType({id: 'animal'})
      type2.setProperty 'mammal', 'boolean', true
      type2.save (err) ->
        return done err if err?
        # then their properties ar not mixed
        expect(type.properties).to.have.keys ['wheels']
        expect(type2.properties).to.have.keys ['mammal']
        done()

  it 'should type be created', (done) ->
    # given a new ItemType
    id = 'montain'
    type = new ItemType id:id
    awaited = false

    # then a creation event was issued
    listener = (operation, className, instance) ->
      if operation is 'creation' and className is 'ItemType'
        expect(instance).to.satisfy (o) -> type.equals o
        awaited = true
    watcher.on 'change', listener

    # when saving it
    type.save (err, saved) ->
      return done "Can't save type: #{err}" if err?

      # then it is in mongo
      ItemType.find {}, (err, types) ->
        # then it's the only one document
        expect(types).to.have.lengthOf 1
        # then it's values were saved
        expect(types[0]).to.have.property('id').that.equal id
        expect(awaited, 'watcher was\'nt invoked for new type').to.be.true
        done()

  it 'should date property always be stores as Date', (done) ->
    # given a new ItemType with a null time property
    type = new ItemType id:'test-date'
    type.setProperty 'time', 'date', null
    # when saving it
    type.save (err, saved) ->
      return done err if err?

      # then the default time value is null
      expect(saved).to.have.deep.property 'properties.time'
      expect(saved).to.have.deep.property('properties.time.def').that.is.null
      type = saved

      # then a saved instance will have a null default value
      new Item(type: type).save (err, saved) ->
        return done err if err?

        setTimeout ->
          expect(saved).to.have.property('time').that.is.null

          # when setting the default value to a valid string
          type.setProperty 'time', 'date', "2012-10-12T08:00:00.000Z"
          type.save (err, saved) ->
            return done err if err?

            # then the default value is a date
            expect(saved).to.have.deep.property('properties.time.def')
              .that.is.an.instanceOf(Date)
              .and.that.deep.equal new Date "2012-10-12T08:00:00.000Z"
            type = saved

             # then a saved instance will have a date default value
            new Item(type: type).save (err, saved) ->
              return done err if err?

              expect(saved).to.have.property('time')
                .that.is.an.instanceOf(Date)
                .and.that.deep.equal new Date "2012-10-12T08:00:00.000Z"

              # when setting the default value to a valid date
              time = new Date()
              type.setProperty 'time', 'date', time
              type.save (err, saved) ->
                return done err if err?

                # then the default value is a date
                expect(saved).to.have.deep.property('properties.time.def')
                  .that.is.an.instanceOf(Date)
                  .and.that.deep.equal time
                type = saved

                # then a saved instance will have a date default value
                new Item(type: type).save (err, saved) ->
                  return done err if err?

                  expect(saved).to.have.property('time')
                    .that.is.an.instanceOf(Date)
                    .and.that.deep.equal time

                  # when saving an instance with an invalid date
                  new Item(type: type, time: "invalid").save (err) ->
                    # then an error is raised
                    expect(err).to.have.property('message').that.include "isn't a valid date"

                    # when saving the type property instance with an invalid date
                    type.setProperty 'time', 'date', "true"
                    type.save (err, saved) ->
                      # then an error is raised
                      expect(err).to.have.property('message').that.include "isn't a valid date"
                      done()
        , 500

  it 'should default properties values be kept by plainObjects', (done) ->
    # given a type with JSON property
    type = new ItemType id: 'river'
    type.setProperty 'mission', 'json', {}
    type.setProperty 'players', 'json', []
    type.setProperty 'empty', 'json', null
    type.setProperty 'existing', 'json', coucou:true
    type.save (err, type) ->
      return done err if err?

      # when transforming into plain objects
      result = utils.plainObjects type

      # then all empty properties are still here
      expect(result).to.have.deep.property('properties.mission').that.deep.equal type: 'json', def: {}
      expect(result).to.have.deep.property('properties.players').that.deep.equal type: 'json', def: []
      expect(result).to.have.deep.property('properties.empty').that.deep.equal type: 'json', def: null
      expect(result).to.have.deep.property('properties.existing').that.deep.equal type: 'json', def: coucou:true
      done()

  describe 'given a type with a property', ->
    beforeEach (done) ->
      # creates a type with a property color which is a string.
      type = new ItemType id: 'river'
      type.setProperty 'color', 'string', 'blue'
      type.save (err, saved) ->
        type = saved
        done err

    afterEach (done) ->
      # removes the type at the end.
      ItemType.remove {}, -> Item.remove {}, -> Item.loadIdCache done

    it 'should type be removed', (done) ->
      # when removing an item
      type.remove (err) ->
        return done err if err?
        # then it's in mongo anymore
        ItemType.find {}, (err, types) ->
          return done err if err?
          expect(types).to.have.lengthOf 0
          done()

    it 'should type properties be created', (done) ->
      # when adding a property
      type.setProperty 'depth', 'integer', 10
      type.save ->

        ItemType.find {}, (err, types) ->
          # then it's the only one document
          expect(types).to.have.lengthOf 1
          # then only the relevant values were modified
          expect(types[0]).to.have.property('id').that.equal 'river'
          expect(types[0]).to.have.deep.property('properties.depth.type').that.equal 'integer'
          expect(types[0]).to.have.deep.property('properties.depth.def').that.equal 10
          done()

    it 'should type properties be updated', (done) ->
      expect(type).to.have.deep.property('properties.color.type').that.equal 'string'
      expect(type).to.have.deep.property('properties.color.def').that.equal 'blue'

      # when updating a property
      type.setProperty 'color', 'integer', 10
      type.save (err, saved) ->
        # then the property was updated
        expect(saved).to.have.deep.property('properties.color.type').that.equal 'integer'
        expect(saved).to.have.deep.property('properties.color.def').that.equal 10
        done()

    it 'should type properties be removed', (done) ->
      # when removing a property
      type.unsetProperty 'color'
      type.save (err, saved) ->
        return done err if err?

        # then the property was removed
        expect(saved).not.to.have.deep.property 'properties.color'
        done()

    it 'should unknown type properties fail on remove', (done) ->
      try
        # when removing an unknown property
        type.unsetProperty 'unknown'
        return done 'Error must be raised when removing unknwown property'
      catch err
        # then an error is thrown
        expect(err).to.have.property('message').that.equal 'Unknown property unknown for type river'
      done()

  describe 'given a type and some items', ->

    beforeEach (done) ->
      # creates a type with a string property 'color' and an array property 'affluents'.
      type = new ItemType id: 'river'
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
      watcher.on 'change', listener = (operation, className, instance)->
        return if className isnt 'Item'
        updates.push instance.id
        expect(operation).to.equal 'update'
        expect(instance).to.have.property('depth').that.equal 30

      # when setting a property to a type
      defaultDepth = 30
      type.setProperty 'depth', 'integer', defaultDepth
      type.save (err) ->
        return done err if err?
        next = ->
          Item.find {type: type.id}, (err, items) ->
            for item in items
              expect(item).to.have.property('depth').that.equal defaultDepth
              expect(updates).to.include item.id
            done()
        setTimeout next, 500

    it 'should existing items be updated when removing a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', listener = (operation, className, instance)->
        return if className isnt 'Item'
        expect(operation).to.equal 'update'
        updates.push instance.id
        expect(instance).to.have.property('color').that.is.null

      # when setting a property to a type
      defaultDepth = 30
      type.unsetProperty 'color'
      type.save (err) ->
        return done err if err?
        setTimeout ->
          Item.find {type: type.id}, (err, items) ->
            return done err if err?
            for item in items
              expect(item).not.to.have.property 'color'
              expect(updates).to.include item.id
            done()
        , 100

    it 'should items be updated when modifying quantifiable state', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', listener = (operation, className, instance)->
        return if className isnt 'Item'
        expect(operation).to.equal 'update'
        updates.push instance.id
        expect(instance).not.to.have.property 'color'

      # when setting quantifiable to true
      type.quantifiable = true
      type.save (err) ->
        return done err if err?
        setTimeout ->
          Item.find {type: type.id}, (err, items) ->
            return done err if err?
            # then all items have their quantity to 0
            for item in items
              expect(item).to.have.property('quantity').that.equal 0
              expect(updates).to.include item.id

            # when setting quantifiable to false
            type.quantifiable = false
            type.save (err) ->
              return done err if err?
              setTimeout ->
                Item.find {type: type.id}, (err, items) ->
                  # then all
                  for item in items
                    expect(item).to.have.property('quantity').that.is.null
                    expect(updates).to.include item.id
                  done()
              , 100
        , 100