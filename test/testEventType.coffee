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

Event = require '../hyperion/src/model/Event'
EventType = require '../hyperion/src/model/EventType'
watcher = require('../hyperion/src/model/ModelWatcher').get()
assert = require('chai').assert

event1 = null
event2 = null
event3 = null
type = null

describe 'EventType tests', -> 

  beforeEach (done) ->
    # empty events and types.
    Event.collection.drop -> EventType.collection.drop -> Event.loadIdCache done

  it 'should type\'s properties be distinct', (done) ->
    # given a type with a property
    type = new EventType({id: 'birth'})
    type.setProperty 'weight', 'float', 3.5
    type.save (err) ->
      if (err?)
        throw new Error err
        done()
      # when creating another type with distinct property
      type2 = new EventType({id: 'death'})
      type2.setProperty 'when', 'date', new Date()
      type2.save (err) ->
        if (err?)
          throw new Error err
          done()
        # then their properties ar not mixed
        keys = Object.keys type.properties
        keys2 = Object.keys type2.properties
        assert.equal keys.length, 1 
        assert.equal keys[0], 'weight'
        assert.equal keys2.length, 1
        assert.equal keys2[0], 'when'
        done()

  it 'should type be created', (done) -> 
    # given a new EventType
    id = 'talk'
    type = new EventType id: id

    # when saving it
    type.save (err, saved) ->
      throw new Error "Can't save type: #{err}" if err?

      # then it is in mongo
      EventType.find {}, (err, types) ->
        # then it's the only one document
        assert.equal types.length, 1
        # then it's values were saved
        assert.equal types[0].id, id
        done()


  describe 'given a type with a property', ->
    beforeEach (done) ->
      # creates a type with a property color which is a string.
      type = new EventType id: 'talk'
      type.setProperty 'content', 'string', '---'
      type.save (err, saved) -> 
        type = saved
        done()

    afterEach (done) ->
      # removes the type at the end.
      EventType.collection.drop -> Event.collection.drop -> done()

    it 'should type be removed', (done) ->
      # when removing an event
      type.remove (err) ->
        return done err if err?
        # then it's in mongo anymore
        EventType.find {}, (err, types) ->
          return done err if err?
          assert.equal types.length, 0
          done()

    it 'should type properties be created', (done) ->
      # when adding a property
      type.setProperty 'length', 'integer', 100
      type.save ->

        EventType.find {}, (err, types) ->
          # then it's the only one document
          assert.equal types.length, 1
          # then only the relevant values were modified
          assert.equal types[0].id, 'talk',
          assert.ok 'length' of types[0].properties, 'no length in properties'
          assert.equal types[0].properties.length?.type, 'integer'
          assert.equal types[0].properties.length?.def, 100
          done()

    it 'should type properties be updated', (done) ->
      assert.ok 'content' of type.properties, 'no content in properties'
      assert.equal type.properties.content?.type, 'string'
      assert.equal type.properties.content?.def, '---'

      # when updating a property 
      type.setProperty 'content', 'integer', 10
      type.save (err, saved) ->
        # then the property was updated
        assert.equal saved.properties.content?.type, 'integer'
        assert.equal saved.properties.content?.def, 10
        done()

    it 'should type properties be removed', (done) ->
      # when removing a property
      type.unsetProperty 'content'
      type.save (err, saved) ->
        if err? 
          assert.fail "Can't save event: #{err}"
          return done()

        # then the property was removed
        assert.ok not ('content' of saved.properties), 'content still in properties'
        done()

    it 'should unknown type properties fail on remove', (done) ->
      try 
        # when removing an unknown property
        type.unsetProperty 'unknown'
        assert.fail 'Error must be raised when removing unknwown property'
      catch err
        # then an error is thrown
        assert.equal err?.message, 'Unknown property unknown for type talk'
      done()

  describe 'given a type and some events', ->

    beforeEach (done) ->
      # creates a type with a string property 'color' and an array property 'subTalks'.
      type = new EventType id: 'talk'
      type.setProperty 'content', 'string', ''
      type.setProperty 'subTalks', 'array', 'Event'
      type.save (err, saved) -> 
        throw new Error(err) if err?
        type = saved
        # creates three events of this type.
        event1 = new Event {type: type, subTalks: []}
        event1.save (err) ->
          throw new Error(err) if err?
          event2 = new Event {type: type, subTalks: []}
          event2.save (err) ->
            throw new Error(err) if err?
            event3 = new Event {type: type, subTalks: []}
            event3.save (err) -> 
              throw new Error(err) if err?
              done()

    it 'should existing events be updated when setting a type property', (done) ->
      updates = []
      defaultLength = 30
      
      # then a modification event was issued
      watcher.on 'change', listener = (operation, className, instance)->
        return if className isnt 'Event'
        updates.push instance.id
        assert.equal operation, 'update'
        assert.equal instance.length, defaultLength

      # when setting a property to a type
      type.setProperty 'length', 'integer', defaultLength
      type.save (err) -> 
        block = ->
          Event.find {type: type.id}, (err, events) ->
            for event in events
              assert.equal event.length, defaultLength
              assert.ok event.id in updates
            watcher.removeListener 'change', listener
            done()
        setTimeout block, 50

    it 'should existing events be updated when removing a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', listener = (operation,className, instance)->
        return if className isnt 'Event'
        assert.equal operation, 'update'
        updates.push instance.id
        assert.ok instance.content is undefined

      # when setting a property to a type
      type.unsetProperty 'content'
      type.save (err) -> 
        block = ->
          Event.find {type: type.id}, (err, events) ->
            for event in events
              assert.ok undefined is event.content, 'content still present'
              assert.ok event.id in updates
            watcher.removeListener 'change', listener
            done()
        setTimeout block, 50