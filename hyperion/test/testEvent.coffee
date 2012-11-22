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
Item = require '../src/model/Item'
ItemType = require '../src/model/ItemType'
watcher = require('../src/model/ModelWatcher').get()
assert = require('chai').assert

event = null
event2 = null
type = null
awaited = false
item = null
itemType = null

describe 'Event tests', -> 

  before (done) ->
    # given an item type and an item
    new ItemType(
      name: 'character'
      properties:
        name: type:'string', def:'Joe'
        chat: type:'array', def: 'Event'
    ).save (err, saved) ->
      return done err if err?
      itemType = saved

      new Item(type: itemType, name: 'Jack').save (err, saved) ->
        return done err if err?
        item = saved
        done()

  beforeEach (done) ->
    type = new EventType({name: 'talk'})
    type.setProperty 'content', 'string', '---'
    type.save (err, saved) ->
      return done err if err?
      Event.collection.drop -> done()

  afterEach (end) ->
    EventType.collection.drop -> Event.collection.drop -> end()

  it 'should event be created', (done) -> 
    # given a new Event
    event = new Event {type:type, from: item, content:'hello !'}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Event'
      assert.equal operation, 'creation'
      assert.ok event.equals instance
      assert.equal instance.from, item._id
      awaited = true

    # when saving it
    awaited = false
    event.save (err) ->
      return done "Can't save event: #{err}" if err?

      # then it is in mongo
      Event.find {}, (err, docs) ->
        return done "Can't find event: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal docs[0].content, 'hello !'
        assert.ok item.equals docs[0].from
        assert.closeTo docs[0].created.getTime(), new Date().getTime(), 500
        assert.equal docs[0].created.getTime(), docs[0].updated.getTime()
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should new event have default properties values', (done) ->
    # when creating an event of this type
    event = new Event {type: type}
    event.save (err)->
      return done "Can't save event: #{err}" if err?
      # then the default value was set
      assert.equal event.content, '---'
      done()

  describe 'given an Event', ->

    beforeEach (done) ->
      event = new Event {content: 'hi !', from: item, type: type}
      event.save -> done()

    it 'should event be modified', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Event'
        assert.equal operation, 'update'
        assert.ok event.equals instance
        assert.isUndefined instance.from
        awaited = true

      # when removing an event
      awaited = false
      event.set 'from', null
      # use timeout to avoid saving during same millis than creation
      setTimeout ->
        event.save (err) ->
          return done "Failed to save event: #{err}" if err?
          

          Event.find {}, (err, docs) ->
            return done "Can't find event: #{err}" if err?
            # then it's the only one document
            assert.equal docs.length, 1
            # then only the relevant values were modified
            assert.isNull docs[0].from
            assert.closeTo docs[0].updated.getTime(), new Date().getTime(), 500
            assert.notEqual docs[0].created.getTime(), docs[0].updated.getTime()
            assert.ok awaited, 'watcher wasn\'t invoked'
            done()
      , 10

    it 'should event be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Event'
        assert.equal operation, 'deletion'
        assert.ok event.equals instance
        awaited = true

      # when removing an event
      awaited = false
      event.remove (err) ->
        return done "Failed to remove event: #{err}" if err?

        # then it's not in mongo anymore
        Event.find {}, (err, docs) ->
          return done "Can't find event: #{err}" if err?
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
      event.save (err) ->
        return done "Failed to save event: #{err}" if err?

        Event.find {}, (err, docs) ->
          return done "Can't find event: #{err}" if err?
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal docs[0].content, 'world'
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should event cannot be saved with unknown property', (done) ->
      # when saving an event with an unknown property
      event.set 'test', true
      event.save (err)->
        # then an error is raised
        assert.fail 'An error must be raised when saving event with unknown property' if !err
        assert.include err?.message, 'unknown property test'
        done()

    it 'should save failed if creation date were modified', (done) ->
      event.set 'created', new Date()
      event.save (err) ->
        # then an error is raised
        assert.fail 'An error must be raised when saving event with modified creation date' if !err
        assert.include err?.message, 'creation date cannot be modified'
        done()

  describe 'given a type with object properties and several Events', -> 

    beforeEach (done) ->
      type = new EventType {name: 'talk'}
      type.setProperty 'content', 'string', ''
      type.setProperty 'father', 'object', 'Event'
      type.setProperty 'children', 'array', 'Event'
      type.save (err) ->
        return done err if err?
        Event.collection.drop -> 
          event = new Event {content: 't1', father: null, type: type, children:[]}
          event.save (err, saved) ->
            return done err if err?
            event = saved
            event2 = new Event {content: 't2', father: event, type: type, children:[]}
            event2.save (err, saved) -> 
              return done err if err?
              event2 = saved
              event.set 'children', [event2]
              event.save (err) ->
                return done err if err?
                done()

    it 'should id be stored for linked object', (done) ->
      # when retrieving an event
      Event.findOne {content: event2.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # then linked events are replaced by their ids
        assert.ok event._id.equals doc.father
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an event
      Event.findOne {content: event.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # then linked arrays are replaced by their ids
        assert.equal doc.children.length, 1
        assert.ok event2._id.equals doc.children[0]
        done()

    it 'should getLinked retrieves linked objects', (done) ->
      # given a unresolved event
      Event.findOne {content: event2.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # when resolving it
        doc.getLinked (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked events are provided
          assert.ok event._id.equals doc.father._id
          assert.equal doc.father.content, event.content
          assert.equal doc.father.father, event.father
          assert.equal doc.father.children[0], event.children[0]
          done()

    it 'should getLinked retrieves linked arrays', (done) ->
      # given a unresolved event
      Event.findOne {content: event.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # when resolving it
        doc.getLinked (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked events are provided
          assert.equal doc.children.length, 1
          linked = doc.children[0]
          assert.ok event2._id.equals linked._id
          assert.equal linked.content, event2.content
          assert.equal linked.father, event2.father
          assert.equal linked.children.length, 0
          done()

    it 'should getLinked retrieves all properties of all objects', (done) ->
      # given a unresolved events
      Event.where().sort(content: 'asc').exec (err, docs) ->
        return done "Can't find event: #{err}" if err?
        # when resolving them
        Event.getLinked docs, (err, docs) ->
          return done "Can't resolve links: #{err}" if err?
          # then the first event has resolved links
          assert.ok event._id.equals docs[1].father._id
          assert.equal docs[1].father.content, event.content
          assert.equal docs[1].father.father, event.father
          assert.equal docs[1].father.children[0], event.children[0]
          # then the second event has resolved links
          assert.equal docs[0].children.length, 1
          linked = docs[0].children[0]
          assert.ok event2._id.equals linked._id
          assert.equal linked.content, event2.content
          assert.equal linked.father, event2.father
          assert.equal linked.children.length, 0
          done()