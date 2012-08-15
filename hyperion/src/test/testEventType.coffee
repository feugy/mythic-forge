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

Event = require '../main/model/Event'
EventType = require '../main/model/EventType'
watcher = require('../main/model/ModelWatcher').get()
assert = require('chai').assert

event1 = null
event2 = null
event3 = null
type = null

describe 'EventType tests', -> 

  beforeEach (done) ->
    # empty events and types.
    Event.collection.drop -> EventType.collection.drop -> done()

  it 'should type\'s properties be distinct', (done) ->
    # given a type with a property
    type = new EventType({name: 'birth'})
    type.setProperty 'weight', 'float', 3.5
    type.save (err) ->
      if (err?)
        throw new Error err
        done()
      # when creating another type with distinct property
      type2 = new EventType({name: 'death'})
      type2.setProperty 'when', 'date', new Date()
      type2.save (err) ->
        if (err?)
          throw new Error err
          done()
        # then their properties ar not mixed
        keys = Object.keys(type.get('properties'))
        keys2 = Object.keys(type2.get('properties'))
        assert.equal keys.length, 1 
        assert.equal keys[0], 'weight'
        assert.equal keys2.length, 1
        assert.equal keys2[0], 'when'
        done()

  it 'should type be created', (done) -> 
    # given a new EventType
    type = new EventType()
    name = 'talk'
    type.set 'name', name

    # when saving it
    type.save (err, saved) ->
      throw new Error "Can't save type: #{err}" if err?

      # then it is in mongo
      EventType.find {}, (err, types) ->
        # then it's the only one document
        assert.equal types.length, 1
        # then it's values were saved
        assert.equal types[0].get('name'), name
        done()

  it 'should name and desc be internationalizables', (done) -> 
    # given a new EventType with translated name
    type = new EventType()
    name = 'talk'
    type.set 'name', name
    type.locale = 'fr'
    nameFr = 'discussion'
    type.set 'name', nameFr

    # when saving it
    type.save (err, saved) ->
      throw new Error "Can't save type: #{err}" if err?

      # then translations are available
      saved.locale = null
      assert.equal saved.get('name'), name
      saved.locale = 'fr'
      assert.equal saved.get('name'), nameFr

      # when setting the tanslated description and saving it
      saved.locale = null
      desc = 'a speech between players'
      saved.set 'desc', desc
      saved.locale = 'fr'
      descFr = 'une discussion entre joueurs' 
      saved.set 'desc', descFr

      saved.save (err, saved) ->
        throw new Error "Can't save type: #{err}" if err?

        # then it is in mongo
        EventType.find {}, (err, types) ->
          # then it's the only one document
          assert.equal 1, types.length
          # then it's values were saved
          assert.equal types[0].get('name'), name
          assert.equal types[0].get('desc'), desc
          types[0].locale = 'fr'
          assert.equal types[0].get('name'), nameFr
          assert.equal types[0].get('desc'), descFr
          done()

  describe 'given a type with a property', ->
    beforeEach (done) ->
      # creates a type with a property color which is a string.
      type = new EventType()
      type.set 'name', 'talk'
      type.setProperty 'content', 'string', '---'
      type.save (err, saved) -> 
        type = saved
        done()

    afterEach (done) ->
      # removes the type at the end.
      EventType.collection.drop -> Event.collection.drop -> done()

    it 'should type be removed', (done) ->
      # when removing an event
      type.remove ->

      # then it's in mongo anymore
      EventType.find {}, (err, types) ->
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
          assert.equal types[0].get('name'), 'talk',
          assert.ok 'length' of types[0].get('properties'), 'no length in properties'
          assert.equal types[0].get('properties').length?.type, 'integer'
          assert.equal types[0].get('properties').length?.def, 100
          done()

    it 'should type properties be updated', (done) ->
      assert.ok 'content' of type.get('properties'), 'no content in properties'
      assert.equal type.get('properties').content?.type, 'string'
      assert.equal type.get('properties').content?.def, '---'

      # when updating a property 
      type.setProperty 'content', 'integer', 10
      type.save (err, saved) ->
        # then the property was updated
        assert.equal saved.get('properties').content?.type, 'integer'
        assert.equal saved.get('properties').content?.def, 10
        done()

    it 'should type properties be removed', (done) ->
      # when removing a property
      type.unsetProperty 'content'
      type.save (err, saved) ->
        if err? 
          assert.fail "Can't save event: #{err}"
          return done()

        # then the property was removed
        assert.ok not ('content' of saved.get('properties')), 'content still in properties'
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
      type = new EventType {name: 'talk'}
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
      watcher.on 'change', (operation, className, instance)->
        return if className isnt 'Event'
        updates.push instance._id+''
        assert.equal operation, 'update'
        assert.equal instance.length, defaultLength

      # when setting a property to a type
      type.setProperty 'length', 'integer', defaultLength
      type.save (err) -> 
        block = ->
          Event.find {type: type._id}, (err, events) ->
            for event in events
              assert.equal event.get('length'), defaultLength
              assert.ok event._id+'' in updates
            watcher.removeAllListeners 'change'
            done()
        setTimeout block, 50

    it 'should existing events be updated when removing a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', (operation,className, instance)->
        return if className isnt 'Event'
        assert.equal operation, 'update'
        updates.push instance._id+''
        assert.ok instance.content is undefined

      # when setting a property to a type
      type.unsetProperty 'content'
      type.save (err) -> 
        block = ->
          Event.find {type: type._id}, (err, events) ->
            for event in events
              assert.ok undefined is event.get('content'), 'content still present'
              assert.ok event._id+'' in updates
            watcher.removeAllListeners 'change'
            done()
        setTimeout block, 50