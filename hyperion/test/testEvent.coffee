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
utils = require '../src/util/common'
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
    # empty events and types.
    Event.collection.drop -> EventType.collection.drop -> Item.collection.drop -> ItemType.collection.drop -> Event.loadIdCache ->
      new ItemType(
        id: 'character'
        properties:
          name: type:'string', def:'Joe'
          chat: type:'array', def: 'Event'
      ).save (err, saved) ->
        return done err if err?
        itemType = saved

        new Item(type: itemType, id: 'Jack').save (err, saved) ->
          return done err if err?
          item = saved
          done()

  afterEach (done) ->
    EventType.collection.drop -> Event.collection.drop -> Event.loadIdCache done

  describe 'given a type', ->

    beforeEach (done) ->
      type = new EventType id:'talk'
      type.setProperty 'content', 'string', '---'
      type.save (err, saved) ->
        return done err if err?
        Event.collection.drop -> Event.loadIdCache done

    it 'should event be created', (done) -> 
      # given a new Event
      event = new Event {type:type, from: item, content:'hello !'}

      # then a creation event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Event'
        assert.equal operation, 'creation'
        assert.ok event.equals instance
        assert.equal instance.from, item.id
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
          assert.closeTo docs[0].created.getTime(), docs[0].updated.getTime(), 50
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
      type = new EventType id:'talk'
      type.setProperty 'content', 'string', '---'
      type.save (err, saved) ->
        return done err if err?
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
      type = new EventType {id: 'talk'}
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
              event.children = [event2]
              event.save (err) ->
                return done err if err?
                done()

    it 'should id be stored for linked object', (done) ->
      # when retrieving an event
      Event.findOne {content: event2.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # then linked events are replaced by their ids
        assert.equal event.id, doc.father
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an event
      Event.findOne {content: event.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # then linked arrays are replaced by their ids
        assert.equal doc.children.length, 1
        assert.equal event2.id, doc.children[0]
        done()

    it 'should getLinked retrieves linked objects', (done) ->
      # given a unresolved event
      Event.findOne {content: event2.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # when resolving it
        doc.getLinked (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked events are provided
          assert.equal event.id, doc.father.id
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
          assert.equal event2.id, linked.id
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
          assert.equal event.id, docs[1].father.id
          assert.equal docs[1].father.content, event.content
          assert.equal docs[1].father.father, event.father
          assert.equal docs[1].father.children[0], event.children[0]
          # then the second event has resolved links
          assert.equal docs[0].children.length, 1
          linked = docs[0].children[0]
          assert.equal event2.id, linked.id
          assert.equal linked.content, event2.content
          assert.equal linked.father, event2.father
          assert.equal linked.children.length, 0
          done()

    it 'should getLinked removes null in arrays', (done) ->
      # given nulls inside array
      event.children = [null, event2, null]
      event.save (err) ->
        return done err if err?
      
        # given an unresolved events
        Event.findById event.id, (err, doc) ->
          return done "Can't find event: #{err}" if err?
          assert.equal doc.children.length, 1
          assert.equal utils.type(doc.children[0]), 'string'
          # when resolving it
          Event.getLinked [doc], (err, docs) ->
            return done "Can't resolve links: #{err}" if err?
            # then the property does not contains nulls anymore
            assert.ok event.equals docs[0]
            assert.equal docs[0].children.length, 1
            assert.ok event2.equals docs[0].children[0]
            done()

    it 'should getLinked handle circular references in properties', (done) ->
      # given circular reference in dynamic properties
      event.children = [event2]
      event.save (err, event) ->
        return done err if err?
        event2.father = event
        event2.save (err, event2) ->
          return done err if err?

          # given an unresolved events
          Event.find _id:$in:[event.id, event2.id], (err, docs) ->
            return done "Can't find event: #{err}" if err?
            assert.equal docs.length, 2
            # when resolving then
            Event.getLinked docs, (err, docs) ->
              return done "Can't resolve links: #{err}" if err?
              
              assert.equal docs.length, 2
              for doc in docs
                if event.equals doc
                  # then the dynamic properties where resolves
                  assert.isNull doc.father
                  assert.equal doc.children.length, 1
                  assert.ok event2.equals doc.children[0]
                  # then the circular dependency was broken
                  assert.equal utils.type(doc.children[0].father), 'string'
                else if event2.equals doc
                  # then the dynamic properties where resolves
                  assert.ok event.equals doc.father
                  assert.equal doc.children.length, 0
                  # then the circular dependency was broken
                  assert.equal doc.father.children.length, 1
                  assert.equal utils.type(doc.father.children[0]), 'string'
                else
                  assert.fail "unkown event: #{doc}"

              # then events can be serialized
              try 
                JSON.stringify docs
              catch err
                assert.fail "Fail to serialize item: #{err}"
              done()

    it 'should getLinked handle circular references in from', (done) ->
      # given circular reference in dynamic properties
      event.from = item
      event.save (err, event) ->
        return done err if err?
        item.chat.push event
        item.save (err, item) ->
          return done err if err?

           # given an unresolved events
          Event.findById event.id, (err, doc) ->
            return done "Can't find event: #{err}" if err?
            assert.ok item.equals doc.from
            assert.equal doc.from.chat.length, 1
            assert.equal utils.type(doc.from.chat[0]), 'string'
            # when resolving it
            Event.getLinked [doc], (err, docs) ->
              return done "Can't resolve links: #{err}" if err?
              # then the proeprty were resolved
              assert.ok item.equals docs[0].from
              assert.equal docs[0].from.chat.length, 1
              assert.equal utils.type(docs[0].from.chat[0]), 'string'

              # given an unresolved item
              Item.findById item.id, (err, doc) ->
                return done "Can't find item: #{err}" if err?
                assert.ok item.equals doc
                assert.equal doc.chat.length, 1
                assert.equal utils.type(doc.chat[0]), 'string'
                # when resolving it
                Item.getLinked [doc], (err, docs) ->
                  return done "Can't resolve links: #{err}" if err?
                  # then the property were resolved
                  assert.ok item.equals docs[0]
                  assert.equal docs[0].chat.length, 1
                  assert.ok event.equals docs[0].chat[0]
                  assert.ok item.equals docs[0].chat[0].from
                  assert.equal utils.type(docs[0].chat[0].from.chat[0]), 'string'
                  # then item can be serialized
                  try 
                    JSON.stringify docs
                  catch err
                    assert.fail "Fail to serialize item: #{err}"
                  done()

    it 'should modelWatcher send linked objects ids and not full objects', (done) ->
      # given a modification on linked properties
      event2.children.push event
      event2.markModified 'children'
      event2.father = event2

      # then a modification was detected on modified properties
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Event'
        assert.equal operation, 'update'
        assert.ok event2.equals instance
        # then modified object ids are shipped
        assert.equal event2.id, instance.father
        assert.equal instance.children?.length, 1
        assert.equal event.id, instance.children[0]
        awaited = true

      # when saving it
      awaited = false
      event2.save (err, saved) ->
        return done err if err?

        # then the saved object has object ids instead of full objects
        assert.ok event2.equals saved
        assert.equal event2.id, saved.father
        assert.equal saved.children?.length, 1
        assert.equal event.id, saved.children[0]
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()