'use strict'

define ['underscore', 'atlas', 'chai', 'async'], (_, AtlasFactory, chai, async) ->

  expect = chai.expect
  player = null
  adminNS = null
  types = {}
  models = {}

  makeRid = -> 
    "req#{Math.random()*10000}"

  create = (spec, end) ->
    rid = makeRid()
    adminNS.emit 'save', rid, spec.className, spec.obj
    adminNS.on 'save-resp', callback = (reqId, err, className, model) ->
      return unless reqId is rid
      adminNS.removeListener 'save-resp', callback
      return end err if err?
      spec.container[model.id] = model
      end()

  emitter = new (class EventEmitter

    events: {}

    emitted: []

    on: (type, listener) =>
      @events[type] = [] unless type of @events
      @events[type].push listener

    off: (type, listener) =>
      unless type?
        @events = {}
      else unless listener?
        delete @events[type]
      else
        idx = @events[type].indexOf listener
        @events[type].splice idx, 1 if idx isnt -1

    emit: (type, args...) =>
      @emitted.push type:type, args:args
      return unless type of @events
      listener.apply @, args for listener in @events[type]
  )()

  window.Atlas = AtlasFactory emitter
  
  describe 'Atlas tests', ->

    beforeEach ->
      emitter.emitted = []

    it 'should existing player be connected', (done) ->
      # given a token
      $.ajax 
        url: "#{conf.apiBaseUrl}/auth/login"
        type: 'POST'
        crossDomain: true
        data: 
          username: 'admin'
          password: 'admin'
        dataType: 'json'
        error: (xhr, status, err) -> done err
        success: (data, status, xkr) ->
          return done data.error if data.error?

          # when connecting with this token
          Atlas.connect data.token, (err, result) ->
            player = result
            # then player is returned
            expect(err).not.to.exist
            expect(player).to.exist
            expect(player).to.be.an.instanceOf Atlas.Player
            expect(player.email).to.be.equal 'admin'
            # then a connected event was issued
            expect(emitter.emitted).to.have.length 2
            expect(emitter.emitted[1].type).to.be.equal 'connected'
            expect(emitter.emitted[1].args[0]).to.be.deep.equal player
            expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
            expect(emitter.emitted[0].args[0]).to.be.equal 'creation'
            expect(emitter.emitted[0].args[1]).to.be.deep.equal player
            adminNS = Atlas.socket.of "/admin"
            adminNS.on 'connect', done

    describe 'given some models and types', ->

      before (done) ->
        # create types
        async.each [
          {className: 'ItemType', container: types, obj: id: 'testCharacter', quantifiable: false, properties: strength:{type: 'integer', def:10}, linked:{type: 'array', def:'any'}}
          {className: 'EventType', container: types, obj: id: 'testTalk', properties: content:{type: 'text', def:'s.o.s.'}, to:{type: 'object', def: 'item'}}
          {className: 'Map', container: models, obj: id: 'testMap1', kind: 'square'}
        ], create, (err) ->
          return done err if err?
          # then create instances
          async.each [
            {className: 'Item', container: models, obj: id: 'john', strength: 20, type: id: 'testCharacter'}
            {className: 'Item', container: models, obj: id: 'bob', type: id: 'testCharacter'}
          ], create, (err) ->
            return done err if err?
            async.each [
              {className: 'Event', container: models, obj: id: 'evt1', from: 'john', type: id: 'testTalk'}
              {className: 'Event', container: models, obj: id: 'evt2', from: 'bob', content: 'yeah !', type: id: 'testTalk'}
            ], create, done

      after (done) ->
        # remove elements
        async.each _.values(models).concat(_.values types), (obj, next) ->
          rid = makeRid()
          adminNS.emit 'remove', rid, obj._className, obj
          adminNS.on 'remove-resp', callback = (reqId, err) ->
            return unless reqId is rid
            adminNS.removeListener 'remove-resp', callback
            next err
        , done

      it 'should this character added to player', (done) ->
        # when saving the player with this character
        adminNS.emit 'save', makeRid(), 'Player', 
          id: player.id
          email: 'admin'
          password: player.password
          provider: player.provider
          characters: [models.john]
        adminNS.once 'save-resp', (reqId, err) ->
          return done "Failed to save player: #{err}" if err?
          # then player model is automatically updated
          expect(player.characters).to.have.lengthOf 1
          expect(player.characters[0]).to.be.an.instanceOf Atlas.Item
          expect(player.characters[0]).to.have.property 'id', 'john'
          expect(player.characters[0]).to.have.property 'strength', 20
          # then a modelChanged event was issued
          expect(emitter.emitted).to.have.length 1
          expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
          expect(emitter.emitted[0].args[0]).to.equal 'update'
          expect(emitter.emitted[0].args[1]).to.deep.equal player
          expect(emitter.emitted[0].args[2]).to.deep.equal ['characters', 'prefs']
          done()

      it 'should character be added to a map', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          expect(character.map).not.to.exist
          # when adding the character to the map
          models.john.map = models.testMap1
          models.john.x = 5
          models.john.y = -2
          adminNS.emit 'save', makeRid(), 'Item', models.john
          adminNS.once 'save-resp', (reqId, err) ->
            return done "Failed to save character: #{err}" if err?
            # then character model is automatically updated
            expect(character.map).to.be.an.instanceOf Atlas.Map
            expect(character.map).to.have.property 'id', 'testMap1'
            expect(character.map).to.be.deep.equal player.characters[0].map
            expect(character.x).to.be.equal 5
            expect(character.y).to.be.equal -2
            # then a modelChanged event was issued
            expect(emitter.emitted).to.have.length 1
            expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
            expect(emitter.emitted[0].args[0]).to.equal 'update'
            expect(emitter.emitted[0].args[1]).to.deep.equal character
            expect(emitter.emitted[0].args[2]).to.deep.equal ['imageNum', 'y', 'x', 'map']
            done()

      it 'should event have populated from cache and server', (done) -> 
        # when fetching events by ids
        Atlas.Event.fetch ['evt1', 'evt2'], (err, events) ->
          return done "Failed to select events: #{err}" if err?
          expect(events).to.have.length 2
          # then default properties have been applied
          expect(events[0]).to.have.property 'id', 'evt1'
          expect(events[0]).to.have.property 'content', 's.o.s.'
          # then from have been populated from cache
          expect(events[0].from).to.be.an.instanceOf Atlas.Item
          expect(events[0].from).to.have.property 'id', 'john'
          expect(events[1]).to.have.property 'id', 'evt2'
          expect(events[1]).to.have.property 'content', 'yeah !'
          # then from have been populated from server
          expect(events[1].from).to.be.an.instanceOf Atlas.Item
          expect(events[1].from).to.have.property 'id', 'bob'
          Atlas.Item.findCached ['john', 'bob'], (err, items) ->
            return done "Failed to select items: #{err}" if err?
            expect(events[0].from).to.be.deep.equal items[0]
            expect(events[1].from).to.be.deep.equal items[1]
            done()

      it 'should character have linked object', (done) ->
        # given a brand new event with linked object
        create {className: 'Event', container: models, obj: id: 'evt3', to: 'bob', type: id: 'testTalk'}, (err) ->
          return done "Failed to create new event #{err}" if err?
          # given a brand new item with linked array
          create {className: 'Item', container: models, obj: id: 'tim', linked: ['bob', 'evt3'], type: id: 'testCharacter'}, (err) ->
            return done "Failed to create new item #{err}" if err?
            # when fetching the item
            Atlas.Item.fetch ['tim'], (err, items) ->
              return done "Failed to select item #{err}" if err?
              expect(items).to.have.length 1
              # then item is retrieved
              expect(items[0]).to.be.an.instanceOf Atlas.Item
              expect(items[0]).to.have.property 'id', 'tim'
              expect(items[0].type).to.be.an.instanceOf Atlas.ItemType
              expect(items[0].type).to.have.property 'id', 'testCharacter'
              expect(items[0]).to.have.property 'linked'
              # then item as linked array resolved
              expect(items[0].linked).to.have.length 2
              expect(items[0].linked[0]).to.be.an.instanceOf Atlas.Item
              expect(items[0].linked[0]).to.have.property 'id', 'bob'
              expect(items[0].linked[0].type).to.be.an.instanceOf Atlas.ItemType
              expect(items[0].linked[0].type).to.have.property 'id', 'testCharacter'
              expect(items[0].linked[0]).to.have.property 'strength', 10
              expect(items[0].linked[1]).to.be.an.instanceOf Atlas.Event
              expect(items[0].linked[1]).to.have.property 'id', 'evt3'
              expect(items[0].linked[1].type).to.be.an.instanceOf Atlas.EventType
              expect(items[0].linked[1].type).to.have.property 'id', 'testTalk'
              expect(items[0].linked[1]).to.have.property 'content', 's.o.s.'
              # then linked object has their own linked object resolved
              expect(items[0].linked[1]).to.have.property 'to'
              expect(items[0].linked[1].to).to.be.an.instanceOf Atlas.Item
              expect(items[0].linked[1].to).to.have.property 'id', 'bob'
              done()

      it 'should character linked object be changed', (done) ->
        # when modifiing an item
        models.bob.strength = 20
        models.bob.linked = ['evt1']
        create {className: 'Item', container: models, obj: models.bob}, (err) ->
          return done "Failed to select item #{err}" if err?
          # then a modelChanged event was issued
          expect(emitter.emitted).to.have.length 1
          expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
          expect(emitter.emitted[0].args[0]).to.equal 'update'
          expect(emitter.emitted[0].args[1]).to.have.property 'id', 'bob'
          expect(emitter.emitted[0].args[2]).to.deep.equal ['strength', 'linked']
          # when getting locally cached related object
          Atlas.Item.findById 'tim', (err, item) ->
            return done "Failed to select item #{err}" if err?
            expect(item).to.exist
            # then item is retrieved
            expect(item).to.be.an.instanceOf Atlas.Item
            expect(item).to.have.property 'id', 'tim'
            expect(item.type).to.be.an.instanceOf Atlas.ItemType
            expect(item.type).to.have.property 'id', 'testCharacter'
            expect(item).to.have.property 'linked'
            # then item as linked array resolved
            expect(item.linked).to.have.length 2
            expect(item.linked[0]).to.be.an.instanceOf Atlas.Item
            expect(item.linked[0]).to.have.property 'id', 'bob'
            expect(item.linked[0].type).to.be.an.instanceOf Atlas.ItemType
            expect(item.linked[0].type).to.have.property 'id', 'testCharacter'
            expect(item.linked[0]).to.have.property 'strength', 20
            expect(item.linked[1]).to.be.an.instanceOf Atlas.Event
            expect(item.linked[1]).to.have.property 'id', 'evt3'
            expect(item.linked[1].type).to.be.an.instanceOf Atlas.EventType
            expect(item.linked[1].type).to.have.property 'id', 'testTalk'
            expect(item.linked[1]).to.have.property 'content', 's.o.s.'
            # then linked object has their own linked object resolved
            expect(item.linked[0]).to.have.property 'linked'
            expect(item.linked[0].linked).to.have.length 1
            expect(item.linked[0].linked[0]).to.be.an.instanceOf Atlas.Event
            expect(item.linked[0].linked[0]).to.have.property 'id', 'evt1'
            expect(item.linked[1]).to.have.property 'to'
            expect(item.linked[1].to).to.be.an.instanceOf Atlas.Item
            expect(item.linked[1].to).to.have.property 'id', 'bob'
            done()

      it 'should character be removed from a map', (done) -> 
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          expect(character.map).to.exist
          # when removing characteritem from the map
          delete models.john.map
          adminNS.emit 'save', makeRid(), 'Item', models.john
          adminNS.once 'save-resp', (reqId, err) ->
            return done "Failed to save character: #{err}" if err?
            # then character model is automatically updated
            expect(character.map).not.to.exist
            expect(player.characters[0].map).not.to.exist
            # then a modelChanged event was issued
            expect(emitter.emitted).to.have.length 1
            expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
            expect(emitter.emitted[0].args[0]).to.equal 'update'
            expect(emitter.emitted[0].args[1]).to.deep.equal character
            expect(emitter.emitted[0].args[2]).to.deep.equal ['map', 'linked']
            done()

      it 'should character be removed', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          # when removing character
          adminNS.emit 'remove', makeRid(), 'Item', models.john
          adminNS.once 'remove-resp', (reqId, err) ->
            return done "Failed to remove character: #{err}" if err?
            delete models.john
            # then player is automatically updated
            expect(player.characters).to.have.length 0
            # then a modelChanged event was issued
            expect(emitter.emitted).to.have.length 2
            expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
            expect(emitter.emitted[0].args[0]).to.equal 'update'
            expect(emitter.emitted[0].args[1]).to.deep.equal player
            expect(emitter.emitted[0].args[2]).to.deep.equal ['characters']
            expect(emitter.emitted[1].type).to.be.equal 'modelChanged'
            expect(emitter.emitted[1].args[0]).to.equal 'deletion'
            expect(emitter.emitted[1].args[1]).to.deep.equal character
            # then character is not in cache anymore
            Atlas.Item.findById 'john', (err, character) ->
              return done "Failed to remove character: #{err}" if err?
              expect(character).not.to.exist
              done()

    # Phantom is under test environment, where security is disabled
    if -1 is navigator.userAgent.indexOf 'PhantomJS'

      it.skip 'should unknown token not be connected', (done) ->
        Atlas.disconnect ->
          # given a token
          Atlas.connect 'unknown', (err, player) ->
            expect(err).to.be.an.instanceOf Error
            expect(err.message).to.equal 'handshake unauthorized'
            expect(player).not.to.exist
            done()