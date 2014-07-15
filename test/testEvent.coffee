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
Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
{expect} = require 'chai'

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
        expect(className).to.equal 'Event'
        expect(operation).to.equal 'creation'
        expect(instance).to.satisfy (o) -> event.equals o
        expect(instance).to.have.property('from').that.equal item.id
        awaited = true

      # when saving it
      awaited = false
      event.save (err) ->
        return done "Can't save event: #{err}" if err?

        # then it is in mongo
        Event.find {}, (err, docs) ->
          return done "Can't find event: #{err}" if err?
          # then it's the only one document
          expect(docs).to.have.lengthOf 1
          # then it's values were saved
          expect(docs[0]).to.have.property('content').that.equal 'hello !'
          expect(docs[0]).to.have.property('from').that.satisfy (o) -> o.equals item
          expect(docs[0]).to.have.property 'created'
          expect(docs[0].created.getTime()).to.be.closeTo Date.now(), 500
          expect(docs[0].created.getTime()).to.be.closeTo docs[0].updated.getTime(), 50
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should new event have default properties values', (done) ->
      # when creating an event of this type
      event = new Event {type: type}
      event.save (err)->
        return done "Can't save event: #{err}" if err?
        # then the default value was set
        expect(event).to.have.property('content').that.equal '---'
        done()

  describe 'given a type with a json property and an event', ->

    beforeEach (done) ->
      type = new EventType id:'talk'
      type.setProperty 'preferences', 'json', {help:true}
      type.save (err, saved) ->
        return done err if err?
        Event.collection.drop -> Event.loadIdCache ->
          event = new Event {type: type}
          event.save (err) ->
            # wait a little to avoid to fast save+update that prevent 'updated' to be detected as modified
            setTimeout (-> done err), 10

    it 'should not accept invalid JSON property', (done) ->
      # when modifying the Json value with invalid JSON
      event.preferences = 10

      event.save (err)->
        expect(err).to.have.property('message').that.include 'json only accepts arrays and object'
        done()

    it 'should modelWatcher detect modification on JSON property', (done) ->
      awaited = false
      # given a listening watcher
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Event'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> event.equals o
        # then a change was detected on preferences
        expect(instance).to.have.keys ['id', 'updated', 'preferences']
        awaited = true

      # when modifying the Json value
      event.preferences.help = true
      event.preferences.count = 1

      event.save (err, event)->
        return done "Can't save event: #{err}" if err?

        # then value was updated
        expect(event).to.have.property('preferences').that.deep.equal help:true, count: 1
        expect(awaited, "watcher wasn't invoked").to.be.true
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
        expect(className).to.equal 'Event'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> event.equals o
        expect(instance).to.have.property('from').that.is.null
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
            expect(docs).to.have.lengthOf 1
            # then only the relevant values were modified
            expect(docs[0]).to.have.property('from').that.is.null
            expect(docs[0].updated.getTime()).to.be.closeTo Date.now(), 500
            expect(docs[0].created.getTime()).not.to.equal docs[0].updated.getTime()
            expect(awaited, 'watcher wasn\'t invoked').to.be.true
            done()
      , 10

    it 'should event be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Event'
        expect(operation).to.equal 'deletion'
        expect(instance).to.satisfy (o) -> event.equals o
        awaited = true

      # when removing an event
      awaited = false
      event.remove (err) ->
        return done "Failed to remove event: #{err}" if err?

        # then it's not in mongo anymore
        Event.find {}, (err, docs) ->
          return done "Can't find event: #{err}" if err?
          expect(docs).to.have.lengthOf 0
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should dynamic property be modified', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Event'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> event.equals o
        expect(instance).to.have.property('content').that.equal 'world'
        awaited = true

      # when modifying a dynamic property
      event.set 'content', 'world'
      awaited = false
      event.save (err) ->
        return done "Failed to save event: #{err}" if err?

        Event.find {}, (err, docs) ->
          return done "Can't find event: #{err}" if err?
          # then it's the only one document
          expect(docs).to.have.lengthOf 1
          # then only the relevant values were modified
          expect(docs[0]).to.have.property('content').that.equal 'world'
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should event cannot be saved with unknown property', (done) ->
      # when saving an event with an unknown property
      event.set 'test', true
      event.save (err)->
        # then an error is raised
        expect(err).to.have.property('message').that.include 'unknown property test'
        done()

    it 'should save failed if creation date were modified', (done) ->
      event.set 'created', new Date()
      event.save (err) ->
        # then an error is raised
        expect(err).to.have.property('message').that.include 'creation date cannot be modified'
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
        expect(doc).to.have.property('father').that.equal event.id
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an event
      Event.findOne {content: event.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # then linked arrays are replaced by their ids
        expect(doc).to.have.property('children').that.has.lengthOf 1
        expect(doc.children[0]).to.equal event2.id
        done()

    it 'should fetch retrieves linked objects', (done) ->
      # given a unresolved event
      Event.findOne {content: event2.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # when resolving it
        doc.fetch (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked events are provided
          expect(doc).to.have.deep.property('father.id').that.equal event.id
          expect(doc).to.have.deep.property('father.content').that.equal event.content
          expect(doc).to.have.deep.property('father.father').that.equal event.father
          expect(doc).to.have.deep.property 'father.children'
          expect(doc.father.children).to.have.lengthOf 1
          expect(doc.father.children[0]).to.equal event.children[0]
          done()

    it 'should fetch retrieves linked arrays', (done) ->
      # given a unresolved event
      Event.findOne {content: event.content}, (err, doc) ->
        return done "Can't find event: #{err}" if err?
        # when resolving it
        doc.fetch (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked events are provided
          expect(doc).to.have.property('children').that.has.lengthOf 1
          linked = doc.children[0]
          expect(linked).to.have.property('id').that.equal event2.id
          expect(linked).to.have.property('content').that.equal event2.content
          expect(linked).to.have.property('father').that.equal event2.father
          expect(linked).to.have.property('children').that.has.lengthOf 0
          done()

    it 'should fetch retrieves all properties of all objects', (done) ->
      # given a unresolved events
      Event.where().sort(content: 'asc').exec (err, docs) ->
        return done "Can't find event: #{err}" if err?
        # when resolving them
        Event.fetch docs, (err, docs) ->
          return done "Can't resolve links: #{err}" if err?
          expect(docs).to.have.lengthOf 2
          # then the first event has resolved links
          expect(docs[1]).to.have.deep.property('father.id').that.equal event.id
          expect(docs[1]).to.have.deep.property('father.content').that.equal event.content
          expect(docs[1]).to.have.deep.property('father.father').that.equal event.father
          expect(docs[1]).to.have.deep.property('father.children').that.has.lengthOf 1
          expect(docs[1].father.children[0]).to.have.property('id').that.equal event.children[0]
          # then the second event has resolved links
          expect(docs[0]).to.have.property('children').that.has.lengthOf 1
          linked = docs[0].children[0]
          expect(linked).to.have.property('id').that.equal event2.id
          expect(linked).to.have.property('content').that.equal event2.content
          expect(linked).to.have.deep.property('father.id').that.equal event2.father
          expect(linked).to.have.property('children').that.has.lengthOf 0
          done()

    it 'should fetch removes null in arrays', (done) ->
      # given nulls inside array
      event.children = [null, event2, null]
      event.save (err) ->
        return done err if err?
      
        # given an unresolved events
        Event.findById event.id, (err, doc) ->
          return done "Can't find event: #{err}" if err?
          expect(doc).to.have.property('children').that.has.lengthOf 1
          expect(doc.children[0]).to.be.a 'string'
          # when resolving it
          Event.fetch [doc], (err, docs) ->
            return done "Can't resolve links: #{err}" if err?
            # then the property does not contains nulls anymore
            expect(docs[0]).to.satisfy (o) -> o.equals event
            expect(docs[0]).to.have.property('children').that.has.lengthOf 1
            expect(docs[0].children[0]).to.satisfy (o) -> o.equals event2
            done()

    it 'should fetch handle circular references in properties', (done) ->
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
            expect(docs).to.have.lengthOf 2
            # when resolving then
            Event.fetch docs, true, (err, docs) ->
              return done "Can't resolve links: #{err}" if err?
              
              expect(docs).to.have.lengthOf 2
              for doc in docs
                if event.equals doc
                  # then the dynamic properties where resolves
                  expect(doc).to.have.property('father').that.is.null
                  expect(doc).to.have.property('children').that.has.lengthOf 1
                  expect(doc.children[0]).to.satisfy (o) -> o.equals event2
                  # then the circular dependency was broken
                  expect(doc.children[0]).to.have.property('father').that.is.a 'string'
                else if event2.equals doc
                  # then the dynamic properties where resolves
                  expect(doc).to.have.property('father').that.satisfy (o) -> o.equals event
                  expect(doc).to.have.property('children').that.has.lengthOf 0
                  # then the circular dependency was broken
                  expect(doc).to.have.deep.property('father.children').that.has.lengthOf 1
                  expect(doc.father.children[0]).to.be.a 'string'
                else
                  throw new Error  "unkown event: #{doc}"

              # then events can be serialized
              try 
                JSON.stringify docs
              catch err
                throw new Error "Fail to serialize item: #{err}"
              done()

    it 'should fetch handle circular references in from', (done) ->
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
            expect(doc).to.have.property('from').that.satisfy (o) -> o.equals item
            expect(doc).to.have.deep.property('from.chat').that.has.lengthOf 1
            expect(doc.from.chat[0]).to.be.a 'string'
            # when resolving it
            Event.fetch [doc], true, (err, docs) ->
              return done "Can't resolve links: #{err}" if err?
              # then the proeprty were resolved
              expect(docs[0]).to.have.property('from').that.satisfy (o) -> o.equals item
              expect(docs[0]).to.have.deep.property('from.chat').that.has.lengthOf 1
              expect(docs[0].from.chat[0]).to.be.a 'string'

              # given an unresolved item
              Item.findById item.id, (err, doc) ->
                return done "Can't find item: #{err}" if err?
                expect(doc).to.satisfy (o) -> o.equals item
                expect(doc).to.have.property('chat').that.has.lengthOf 1
                expect(doc.chat[0]).to.be.a 'string'
                # when resolving it
                Item.fetch [doc], true, (err, docs) ->
                  return done "Can't resolve links: #{err}" if err?
                  # then the property were resolved
                  expect(docs[0]).to.satisfy (o) -> o.equals item
                  expect(docs[0]).to.have.property('chat').that.has.lengthOf 1
                  expect(docs[0].chat[0]).to.satisfy (o) -> o.equals event
                  expect(docs[0].chat[0].from).to.satisfy (o) -> o.equals item
                  expect(docs[0].chat[0].from).to.have.property('chat').that.has.lengthOf 1
                  expect(docs[0].chat[0].from.chat[0]).to.be.a 'string'
                  # then item can be serialized
                  try 
                    JSON.stringify docs
                  catch err
                    throw new Error "Fail to serialize item: #{err}"
                  done()

    it 'should modelWatcher send linked objects ids and not full objects', (done) ->
      # given a modification on linked properties
      event2.children.push event
      event2.father = event2

      # then a modification was detected on modified properties
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Event'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> event2.equals o
        # then modified object ids are shipped
        expect(instance).to.have.property('father').that.equal event2.id
        expect(instance).to.have.property('children').that.has.lengthOf 1
        expect(instance.children[0]).to.equal event.id
        awaited = true

      # when saving it
      awaited = false
      event2.save (err, saved) ->
        return done err if err?

        # then the saved object has object ids instead of full objects
        expect(saved).to.satisfy (o) -> event2.equals o
        expect(saved).to.have.property('father').that.equal event2.id
        expect(saved).to.have.property('children').that.has.lengthOf 1
        expect(saved.children[0]).to.equal event.id
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()