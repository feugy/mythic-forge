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

Event = require '../src/model/Event'
EventType = require '../src/model/EventType'
watcher = require('../src/model/ModelWatcher').get()
assert = require('chai').assert

event = null
event2 = null
type = null
awaited = false

describe 'Event tests', -> 

  beforeEach (done) ->
    type = new EventType({name: 'talk'})
    type.setProperty 'content', 'string', '---'
    type.save (err, saved) ->
      throw new Error err if err?
      Event.collection.drop -> done()

  afterEach (end) ->
    EventType.collection.drop -> Event.collection.drop -> end()

  it 'should event be created', (done) -> 
    # given a new Event
    event = new Event {type:type, content:'hello !'}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Event'
      assert.equal operation, 'creation'
      assert.ok event.equals instance
      awaited = true

    # when saving it
    awaited = false
    event.save (err) ->
      throw new Error "Can't save event: #{err}" if err?

      # then it is in mongo
      Event.find {}, (err, docs) ->
        throw new Error "Can't find event: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal docs[0].get('content'), 'hello !'
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should new event have default properties values', (done) ->
    # when creating an event of this type
    event = new Event {type: type}
    event.save (err)->
      throw new Error "Can't save event: #{err}" if err?
      # then the default value was set
      assert.equal event.get('content'), '---'
      done()

  describe 'given an Event', ->

    beforeEach (done) ->
      event = new Event {content: 'hi !', type: type}
      event.save -> done()

    it 'should event be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Event'
        assert.equal operation, 'deletion'
        assert.ok event.equals instance
        awaited = true

      # when removing an event
      awaited = false
      event.remove ->

        # then it's not in mongo anymore
        Event.find {}, (err, docs) ->
          throw new Error "Can't find event: #{err}" if err?
          assert.equal docs.length, 0
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should dynamic property be modified', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Event'
        assert.equal operation, 'update'
        assert.ok event.equals instance
        assert.equal instance.content, 'world'
        awaited = true

      # when modifying a dynamic property
      event.set 'content', 'world'
      awaited = false
      event.save ->

        Event.find {}, (err, docs) ->
          throw new Error "Can't find event: #{err}" if err?
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal docs[0].get('content'), 'world'
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should event cannot be saved with unknown property', (done) ->
      # when saving an event with an unknown property
      event.set 'test', true
      event.save (err)->
        # then an error is raised
        assert.fail 'An error must be raised when saving event with unknown property' if !err
        assert.ok err?.message.indexOf('unknown property test') isnt -1
        done()

  describe 'given a type with object properties and several Events', -> 

    beforeEach (done) ->
      type = new EventType {name: 'talk'}
      type.setProperty 'content', 'string', ''
      type.setProperty 'father', 'object', 'Event'
      type.setProperty 'children', 'array', 'Event'
      type.save ->
        Event.collection.drop -> 
          event = new Event {content: 't1', father: null, type: type, children:[]}
          event.save (err, saved) ->
            throw new Error err  if err?
            event = saved
            event2 = new Event {content: 't2', father: event, type: type, children:[]}
            event2.save (err, saved) -> 
              throw new Error err  if err?
              event2 = saved
              event.set 'children', [event2]
              event.save (err) ->
                throw new Error err  if err?
                done()

    it 'should id be stored for linked object', (done) ->
      # when retrieving an event
      Event.findOne {content: event2.get 'content'}, (err, doc) ->
        throw new Error "Can't find event: #{err}" if err?
        # then linked events are replaced by their ids
        assert.ok event._id.equals doc.get('father')
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an event
      Event.findOne {content: event.get 'content'}, (err, doc) ->
        throw new Error "Can't find event: #{err}" if err?
        # then linked arrays are replaced by their ids
        assert.equal doc.get('children').length, 1
        assert.ok event2._id.equals doc.get('children')[0]
        done()

    it 'should resolve retrieves linked objects', (done) ->
      # given a unresolved event
      Event.findOne {content: event2.get 'content'}, (err, doc) ->
        throw new Error "Can't find event: #{err}" if err?
        # when resolving it
        doc.resolve (err, doc) ->
          throw new Error "Can't resolve links: #{err}" if err?
          # then linked events are provided
          assert.ok event._id.equals doc.get('father')._id
          assert.equal doc.get('father').get('content'), event.get('content')
          assert.equal doc.get('father').get('father'), event.get('father')
          assert.equal doc.get('father').get('children')[0], event.get('children')[0]
          done()

    it 'should resolve retrieves linked arrays', (done) ->
      # given a unresolved event
      Event.findOne {content: event.get 'content'}, (err, doc) ->
        throw new Error "Can't find event: #{err}" if err?
        # when resolving it
        doc.resolve (err, doc) ->
          throw new Error "Can't resolve links: #{err}" if err?
          # then linked events are provided
          assert.equal doc.get('children').length, 1
          linked = doc.get('children')[0]
          assert.ok event2._id.equals linked._id
          assert.equal linked.get('content'), event2.get('content')
          assert.equal linked.get('father'), event2.get('father')
          assert.equal linked.get('children').length, 0
          done()

    it 'should multi-resolve retrieves all properties of all objects', (done) ->
      # given a unresolved events
      Event.where().asc('content').run (err, docs) ->
        throw new Error "Can't find event: #{err}" if err?
        # when resolving them
        Event.multiResolve docs, (err, docs) ->
          throw new Error "Can't resolve links: #{err}" if err?
          # then the first event has resolved links
          assert.ok event._id.equals docs[1].get('father')._id
          assert.equal docs[1].get('father').get('content'), event.get('content')
          assert.equal docs[1].get('father').get('father'), event.get('father')
          assert.equal docs[1].get('father').get('children')[0], event.get('children')[0]
          # then the second event has resolved links
          assert.equal docs[0].get('children').length, 1
          linked = docs[0].get('children')[0]
          assert.ok event2._id.equals linked._id
          assert.equal linked.get('content'), event2.get('content')
          assert.equal linked.get('father'), event2.get('father')
          assert.equal linked.get('children').length, 0
          done()
