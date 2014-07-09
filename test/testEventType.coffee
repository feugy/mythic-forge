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

Event = require '../hyperion/src/model/Event'
EventType = require '../hyperion/src/model/EventType'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
{expect} = require 'chai'

event1 = null
event2 = null
event3 = null
type = null
listener = null

describe 'EventType tests', -> 

  beforeEach (done) ->
    # empty events and types.
    Event.collection.drop -> EventType.collection.drop -> Event.loadIdCache done

  afterEach (done) ->
    # remove all listeners
    watcher.removeListener 'change', listener if listener?
    done()

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
        expect(type.properties).to.have.keys ['weight']
        expect(type2.properties).to.have.keys ['when']
        done()

  it 'should type be created', (done) -> 
    # given a new EventType
    id = 'talk'
    type = new EventType id: id
    awaited = false

    # then a creation event was issued
    listener = (operation, className, instance)->
      if operation is 'creation' and className is 'EventType'
        expect(instance).to.satisfy (o) -> type.equals o
        awaited = true
    watcher.on 'change', listener

    # when saving it
    type.save (err, saved) ->
      throw new Error "Can't save type: #{err}" if err?

      # then it is in mongo
      EventType.find {}, (err, types) ->
        # then it's the only one document
        expect(types).to.have.lengthOf 1
        # then it's values were saved
        expect(types[0]).to.have.property('id').that.equal id
        expect(awaited, 'watcher was\'nt invoked for new type').to.be.true
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
      EventType.collection.drop -> Event.collection.drop -> Event.loadIdCache done

    it 'should type be removed', (done) ->
      # when removing an event
      type.remove (err) ->
        return done err if err?
        # then it's in mongo anymore
        EventType.find {}, (err, types) ->
          return done err if err?
          expect(types).to.have.lengthOf 0
          done()

    it 'should type properties be created', (done) ->
      # when adding a property
      type.setProperty 'length', 'integer', 100
      type.save ->

        EventType.find {}, (err, types) ->
          # then it's the only one document
          expect(types).to.have.lengthOf 1
          # then only the relevant values were modified
          expect(types[0]).to.have.property('id').that.equal 'talk',
          expect(types[0]).to.have.deep.property 'properties.length'
          expect(types[0]).to.have.deep.property('properties.length.type').that.equal 'integer'
          expect(types[0]).to.have.deep.property('properties.length.def').that.equal 100
          done()

    it 'should type properties be updated', (done) ->
      awaited = false
      
      # then a modification event was issued
      listener = (operation, className, instance) ->
        if operation is 'update' and className is 'EventType'
          expect(instance).to.satisfy (o) -> type.equals o
          awaited = true
      watcher.on 'change', listener

      expect(type).to.have.deep.property 'properties.content'
      expect(type).to.have.deep.property('properties.content.type').that.equal 'string'
      expect(type).to.have.deep.property('properties.content.def').that.equal '---'

      # when updating a property 
      type.setProperty 'content', 'integer', 10
      type.save (err, saved) ->
        # then the property was updated
        expect(saved).to.have.deep.property('properties.content.type').that.equal 'integer'
        expect(saved).to.have.deep.property('properties.content.def').that.equal 10
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

    it 'should type properties be removed', (done) ->
      # when removing a property
      type.unsetProperty 'content'
      type.save (err, saved) ->
        return done err if err? 

        # then the property was removed
        expect(saved).not.to.have.deep.property 'properties.content'
        done()

    it 'should unknown type properties fail on remove', (done) ->
      try 
        # when removing an unknown property
        type.unsetProperty 'unknown'
        throw new Error 'Error must be raised when removing unknwown property'
      catch err
        # then an error is thrown
        expect(err).to.have.property('message').that.include 'Unknown property unknown for type talk'
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
        expect(operation).to.equal 'update'
        expect(instance).to.have.property('length').that.equal defaultLength

      # when setting a property to a type
      type.setProperty 'length', 'integer', defaultLength
      type.save (err) -> 
        block = ->
          Event.find {type: type.id}, (err, events) ->
            for event in events
              expect(event).to.have.property('length').that.equal defaultLength
              expect(updates).to.include event.id
            watcher.removeListener 'change', listener
            done()
        setTimeout block, 50

    it 'should existing events be updated when removing a type property', (done) ->
      updates = []
      # then a modification event was issued
      watcher.on 'change', listener = (operation,className, instance)->
        return if className isnt 'Event'
        expect(operation).to.equal 'update'
        updates.push instance.id
        expect(instance).to.have.property('content').that.is.null

      # when setting a property to a type
      type.unsetProperty 'content'
      type.save (err) -> 
        block = ->
          Event.find {type: type.id}, (err, events) ->
            for event in events
              expect(event).not.to.have.property 'content'
              expect(updates).to.include event.id
            watcher.removeListener 'change', listener
            done()
        setTimeout block, 50