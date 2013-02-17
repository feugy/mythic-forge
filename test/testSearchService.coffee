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

testUtils = require './utils/testUtils'
utils = require '../hyperion/src/util/common'
ItemType = require '../hyperion/src/model/ItemType'
FieldType = require '../hyperion/src/model/FieldType'
EventType = require '../hyperion/src/model/EventType'
Item = require '../hyperion/src/model/Item'
Event = require '../hyperion/src/model/Event'
Player = require '../hyperion/src/model/Player'
Map = require '../hyperion/src/model/Map'
Executable = require '../hyperion/src/model/Executable'
service = require('../hyperion/src/service/SearchService').get()
assert = require('chai').assert

assert.contains = (array, model, message='') ->
  tmp = array.filter (obj) -> model.equals obj
  assert.ok tmp.length is 1, message
  assert.ok utils.isA(tmp[0], model.constructor)

describe 'SearchService tests', ->

  describe 'searchInstances', ->
    character = null
    sword = null
    talk = null
    world = null
    underworld = null
    john = null
    jack = null
    dupond = null
    talk1 = null
    talk2 = null
    talk3 = null
    ivanhoe = null
    roland = null  
    arthur = null           
    gladius = null
    durandal = null
    excalibur = null
    broken = null

    before (done) ->
      Player.collection.drop -> Map.collection.drop -> EventType.collection.drop -> ItemType.collection.drop -> Item.collection.drop -> Event.collection.drop -> Player.collection.drop -> Map.loadIdCache ->
        # creates some fixtures types
        character = new ItemType id: 'character', desc: 'people a player can embody', quantifiable: false, properties:
          name: {type:'string', def:null}
          stock: {type:'array', def:'Item'}
          strength: {type:'integer', def:10}
          knight: {type:'boolean', def:false}
        character.save (err, saved) ->
          return done err if err?
          character = saved
          sword = new ItemType id: 'sword', desc: 'a simple bastard sword', quantifiable: true, properties:
            color: {type:'string', def:'grey'}
            strength: {type:'integer', def:10}
          sword.save (err, saved) ->
            return done err if err?
            sword = saved
            talk = new EventType id: 'talk', desc: 'a speech between players', properties:
              content: {type:'string', def:'---'}
              to: {type:'object', def: 'Item'}
            talk.save (err, saved) ->
              return done err if err?
              talk = saved
              world = new Map id: 'world_map', kind: 'square'
              world.save (err, saved) ->
                return done err if err?
                world = saved
                underworld = new Map id: 'underworld', kind: 'diamond'
                underworld.save (err, saved) ->
                  return done err if err?
                  underworld = saved
                  # and now some instances fixtures
                  new Item(type: sword, color:'silver', strength: 10, quantity: 1).save (err, saved) ->
                    return done err if err?
                    gladius = saved
                    new Item(type: sword, color:'silver', strength: 15, quantity: 1).save (err, saved) ->
                      return done err if err?
                      durandal = saved
                      new Item(type: sword, color:'gold', strength: 20, quantity: 1).save (err, saved) ->
                        return done err if err?
                        excalibur = saved
                        new Item(type: sword, color:'black', strength: 5, quantity: 3).save (err, saved) ->
                          return done err if err?
                          broken = saved

                          new Item(type: character, name:'Ivanhoe', strength: 20, stock:[gladius, broken], map: world, knight:true).save (err, saved) ->
                            return done err if err?
                            ivanhoe = saved
                            new Item(type: character, name:'Roland', strength: 15, stock:[durandal], map: underworld, knight:true).save (err, saved) ->
                              return done err if err?
                              roland = saved
                              new Item(type: character, name:'Arthur', strength: 10, stock:[excalibur], map: world, knight:false).save (err, saved) ->
                                return done err if err?
                                arthur = saved

                                new Event(type:talk, content:'hi there !!', from: ivanhoe).save (err, saved) ->
                                  return done err if err?
                                  talk1 = saved
                                  new Event(type:talk, content:'hi !', from: ivanhoe, to:roland).save (err, saved) ->
                                    return done err if err?
                                    talk2 = saved
                                    new Event(type:talk, content:"Hi. I'm Rolland", from: roland, to: ivanhoe).save (err, saved) ->
                                      return done err if err?
                                      talk3 = saved

                                      new Player(email: 'Jack', provider: null, password: 'test', firstName:'Jack', lastName:'Bauer', characters:[ivanhoe]).save (err, saved) ->
                                        return done err if err?
                                        jack = saved
                                        new Player(email: 'john.doe@gmail.com', provider: 'Gmail', firstName:'John', lastName:'Doe', characters:[roland], prefs:{rank:1}).save (err, saved) ->
                                          return done err if err?
                                          john = saved
                                          new Player(email: 'DupondEtDupont@twitter.com', provider: 'Twitter', prefs:{rank:10}).save (err, saved) ->
                                            return done err if err?
                                            dupond = saved

                                            done();

    # Restore admin player for further tests
    after (done) ->
      new Player(email:'admin', password: 'admin', isAdmin:true).save done

    it 'should search by map existence', (done) ->
      service.searchInstances {map:'!'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 3
        assert.contains results, ivanhoe, 'ivanhoe not returned'
        assert.contains results, arthur, 'arthur not returned'
        assert.contains results, roland, 'roland not returned'
        done()

    it 'should search by map id', (done) ->
      service.searchInstances {map:"#{world.id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, ivanhoe, 'ivanhoe not returned'
        assert.contains results, arthur, 'arthur not returned'
        done()

    it 'should search by map kind', (done) ->
      service.searchInstances {'map.kind':"square"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, ivanhoe, 'ivanhoe not returned'
        assert.contains results, arthur, 'arthur not returned'
        done()

    it 'should search by map regexp', (done) ->
      service.searchInstances {'map.id':/under/i}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, roland, 'roland not returned'
        done()

    it 'should search by type id', (done) ->
      service.searchInstances {type:"#{talk.id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 3
        assert.contains results, talk1, 'talk1 not returned'
        assert.contains results, talk2, 'talk2 not returned'
        assert.contains results, talk3, 'talk3 not returned'
        done()

    it 'should search by type property', (done) ->
      service.searchInstances {'type.color': '!'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 4
        assert.contains results, durandal, 'durandal not returned'
        assert.contains results, gladius, 'gladius not returned'
        assert.contains results, broken, 'broken not returned'
        assert.contains results, excalibur, 'excalibur not returned'
        done()

    it 'should search by type regexp', (done) ->
      service.searchInstances {'type.id':/char|swo/i}, (err, results)->
        return done err if err?
        assert.equal results?.length, 7
        assert.contains results, durandal, 'durandal not returned'
        assert.contains results, gladius, 'gladius not returned'
        assert.contains results, broken, 'broken not returned'
        assert.contains results, excalibur, 'excalibur not returned'
        assert.contains results, arthur, 'arthur not returned'
        assert.contains results, roland, 'roland not returned'
        assert.contains results, ivanhoe, 'ivanhoe not returned'
        done()

    it 'should search by multiple terms and type criteria', (done) ->
      service.searchInstances {and:[{'type.id':/r/i}, {strength:10}]}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, arthur, 'arthur not returned'
        assert.contains results, gladius, 'gladius not returned'
        done()

    it 'should search by criteria on linked array', (done) ->
      service.searchInstances {'stock.color': 'silver'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, ivanhoe, 'ivanhoe not returned'
        assert.contains results, roland, 'roland not returned'
        done()

    it 'should search by linked array id', (done) ->
      service.searchInstances {'stock': excalibur.id.toString()}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, arthur, 'arthur not returned'
        done()

    it 'should search by criteria on linked object', (done) ->
      service.searchInstances {'to.strength': 15}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, talk2, 'talk2 not returned'
        done()

    it 'should search by linked object id', (done) ->
      service.searchInstances {'to': ivanhoe.id.toString()}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, talk3, 'talk3 not returned'
        done()

    it 'should search event by from id', (done) ->
      service.searchInstances {'from': ivanhoe.id.toString()}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, talk1, 'talk1 not returned'
        assert.contains results, talk2, 'talk2 not returned'
        done()

    it 'should search event by from property', (done) ->
      service.searchInstances {'from.name': 'Roland'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, talk3, 'talk3 not returned'
        done()

    it 'should search items by id', (done) ->
      service.searchInstances {id:"#{durandal.id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, durandal, 'durandal not returned'
        done()

    it 'should search events by id', (done) ->
      service.searchInstances {id:"#{talk2.id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, talk2, 'talk2 not returned'
        done()

    it 'should search by arbitrary property existence', (done) ->
      service.searchInstances {to:'!'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, talk2, 'talk2 not returned'
        assert.contains results, talk3, 'talk3 not returned'
        done()

    it 'should search by arbitrary property number value', (done) ->
      service.searchInstances {strength: 10}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, arthur, 'arthur not returned'
        assert.contains results, gladius, 'gladius not returned'
        done()

    it 'should search by quantity number value', (done) ->
      service.searchInstances {quantity: 3}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, broken, 'broken not returned'
        done()

    it 'should search players by id', (done) ->
      service.searchInstances {id:"#{dupond.id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, dupond, 'dupond not returned'
        done()

    it 'should search players by exact email', (done) ->
      service.searchInstances {email:"#{john.email}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, john, 'john not returned'
        done()

    it 'should search players by regexp email', (done) ->
      service.searchInstances {email:/j/i}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, jack, 'jack not returned'
        assert.contains results, john, 'john not returned'
        done()

    it 'should search players by provider', (done) ->
      service.searchInstances {provider:'!'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, john, 'john not returned'
        assert.contains results, dupond, 'dupond not returned'
        done()

    it 'should search players by preferences', (done) ->
      service.searchInstances {'prefs.rank':1}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, john, 'john not returned'
        done()

    it 'should search players by character existence', (done) ->
      service.searchInstances {characters: '!'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, john, 'john not returned'
        assert.contains results, jack, 'jack not returned'
        done()

    it 'should search players by character id', (done) ->
      service.searchInstances {characters: roland.id.toString()}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, john, 'john not returned'
        done()

    it 'should search players by character property value', (done) ->
      service.searchInstances {'characters.strength': 20}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, jack, 'jack not returned'
        done()

    it 'should string query be usable', (done) ->
      service.searchInstances '{"and":[{"type.id":"/r/i"}, {"strength":10}]}', (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, arthur, 'arthur not returned'
        assert.contains results, gladius, 'gladius not returned'
        done()

    it 'should search with boolean operator between condition', (done) ->
      service.searchInstances {or:[{and:[{'type.id':/r/i}, {strength: 10}]}, {'prefs.rank': 1}, {to:'!'}]}, (err, results)->
        return done err if err?
        assert.equal results?.length, 5
        assert.contains results, gladius, 'gladius not returned'
        assert.contains results, arthur, 'arthur not returned'
        assert.contains results, john, 'john not returned'
        assert.contains results, talk2, 'talk2 not returned'
        assert.contains results, talk3, 'talk3 not returned'
        done()

    it 'should failed on invalid string query', (done) ->
      service.searchInstances '{"and":[{"type.id":"/r/i"}, {"strength":10}]', (err) ->
        assert.include err, 'Unexpected end of input'
        done()

    it 'should failed on invalid json query', (done) ->
      service.searchInstances {and:{"type.id":/r/i}}, (err) ->
        assert.include err, '$and expression must be a nonempty array'
        done()

  describe 'searchTypes', ->
    itemTypes = []
    eventTypes = []
    fieldTypes = []
    maps = []    
    rules = [] 
    turnRules = [] 

    before (done) ->
      # Empties the compilation and source folders content
      testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
        Executable.resetAll true, (err) -> 
          return done err if err?
          Map.collection.drop -> 
            FieldType.collection.drop -> 
              EventType.collection.drop -> 
                ItemType.collection.drop -> ItemType.loadIdCache ->
                  # creates some fixtures for each searchable objects
                  created = [
                    clazz: ItemType
                    args:
                      id: 'character'
                      quantifiable: false
                      properties:
                        name: {type:'string', def:null}
                        height: {type:'float', def:1.80}
                        strength: {type:'integer', def:10}
                        knight: {type:'boolean', def:false}
                    store: itemTypes
                  ,
                    clazz: ItemType
                    args: 
                      id: 'sword'
                      quantifiable: true
                      properties:
                        color: {type:'string', def:'grey'}
                        strength: {type:'integer', def:10}
                    store: itemTypes
                  ,
                    clazz: EventType
                    args: 
                      id: 'penalty'
                      properties:
                        turn: {type:'integer', def:1}
                        strength: {type:'integer', def:5}
                    store: eventTypes
                  ,
                    clazz: EventType
                    args: 
                      id: 'talk'
                      properties:
                        content: {type:'string', def:'---'}
                    store: eventTypes
                  ,
                    clazz: FieldType
                    args: 
                      id: 'plain'
                    store: fieldTypes
                  ,
                    clazz: FieldType
                    args:
                      id: 'mountain'
                    store: fieldTypes
                  ,
                    clazz: Executable
                    args: 
                      id: 'move'
                      content:"""Rule = require '../model/Rule'
                        module.exports = new (class Move extends Rule
                          constructor: ->
                            @category= 'map'
                          canExecute: (actor, target, callback) =>
                            callback null, []
                          execute: (actor, target, params, callback) =>
                            callback null
                        )()"""
                    store: rules
                  ,
                    clazz: Executable
                    args:
                      id: 'attack'
                      content:"""Rule = require '../model/Rule'
                        module.exports = new (class Attack extends Rule
                          constructor: ->
                            @active= false
                          canExecute: (actor, target, callback) =>
                            callback null, []
                          execute: (actor, target, params, callback) =>
                            callback null
                        )()"""
                    store: rules
                  ,                
                    clazz: Executable
                    args:
                      id: 'sell'
                      content:"""TurnRule = require '../model/TurnRule'
                        module.exports = new (class Sell extends TurnRule
                          constructor: ->
                            @rank= 3
                            @active= false
                          select: (callback) =>
                            callback null, []
                          execute: (target, callback) =>
                            callback null
                        )()"""
                    store: turnRules
                  ,                
                    clazz: Executable
                    args:
                      id: 'monsters'
                      content:"""TurnRule = require '../model/TurnRule'
                        module.exports = new (class Monsters extends TurnRule
                          constructor: ->
                            @rank= 10
                          select: (callback) =>
                            callback null, []
                          execute: (target, callback) =>
                            callback null
                        )()"""
                    store: turnRules
                  ,
                    clazz: Map
                    args: 
                      name: 'world_map'
                      kind:'square'
                    store: maps
                  ,
                    clazz: Map
                    args: 
                      name: 'underworld'
                      kind:'diamond'
                    store: maps
                  ]
                  create = (def) ->
                    return done() unless def?
                    obj = new def.clazz def.args
                    obj.save (err, saved) ->
                      return done err if err?
                      def.store.push saved
                      create created.splice(0, 1)[0]

                  create created.splice(0, 1)[0]

    it 'should search item types by id', (done) ->
      service.searchTypes {id:"#{itemTypes[0].id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, itemTypes[0], 'first item type not returned'
        done()

    it 'should search field types by id', (done) ->
      service.searchTypes {id:"#{fieldTypes[1].id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, fieldTypes[1], 'second field type not returned'
        done()

    it 'should search event types by id', (done) ->
      service.searchTypes {id:"#{eventTypes[0].id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, eventTypes[0], 'first event type not returned'
        done()

    it 'should search maps by id', (done) ->
      service.searchTypes {id:"#{maps[1].id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, maps[1], 'first map not returned'
        done()

    it 'should search executable by id', (done) ->
      service.searchTypes {id:"#{rules[0].id}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, rules[0], 'first rule not returned'
        done()

    it 'should search by regexp id', (done) ->
      service.searchTypes {id:/t/i}, (err, results)->
        return done err if err?
        assert.equal results?.length, 6
        assert.contains results, itemTypes[0], 'first item type not returned'
        assert.contains results, eventTypes[0], 'first event type not returned'
        assert.contains results, eventTypes[1], 'second event type not returned'
        assert.contains results, fieldTypes[1], 'second field type not returned'
        assert.contains results, rules[1], 'second rule not returned'
        assert.contains results, turnRules[1], 'second turn-rule not returned'
        done()

    it 'should search by exact content', (done) ->
      service.searchTypes {content:"#{rules[0].content}"}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, rules[0], 'first rule not returned'
        done()

    it 'should search by regexp content', (done) ->
      service.searchTypes {content:/extends rule/i}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, rules[0], 'first rule not returned'
        assert.contains results, rules[1], 'second rule not returned'
        done()

    it 'should search by property existence', (done) ->
      service.searchTypes {strength: '!'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 3
        assert.contains results, itemTypes[0], 'first item type not returned'
        assert.contains results, itemTypes[1], 'second item type not returned'
        assert.contains results, eventTypes[0], 'first event type not returned'
        done()

    it 'should search by property number value', (done) ->
      service.searchTypes {strength: 10}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, itemTypes[0], 'first item type not returned'
        assert.contains results, itemTypes[1], 'second item type not returned'
        done()

    it 'should search by property string value', (done) ->
      service.searchTypes {content: '---'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, eventTypes[1], 'second event type not returned'
        done()

    it 'should search by property boolean value', (done) ->
      service.searchTypes {knight: false}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, itemTypes[0], 'first item type not returned'
        done()

    it 'should search by property regexp value', (done) ->
      service.searchTypes {content: /.*/}, (err, results)->
        return done err if err?
        assert.equal results?.length, 5
        assert.contains results, eventTypes[1], 'second event type not returned'
        assert.contains results, rules[0], 'first rule not returned'
        assert.contains results, rules[1], 'second rule not returned'
        assert.contains results, turnRules[0], 'first turn-rule not returned'
        assert.contains results, turnRules[1], 'second turn-rule not returned'
        done()

    it 'should search by quantifiable', (done) ->
      service.searchTypes {quantifiable: true}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, itemTypes[1], 'second item type not returned'
        done()

    it 'should combined search with triple or', (done) ->
      service.searchTypes {or: [{id: 'character'}, {id: 'move'}, {strength:'!'}]}, (err, results)->
        return done err if err?
        assert.equal results?.length, 4
        assert.contains results, itemTypes[0], 'first item type not returned'
        assert.contains results, itemTypes[1], 'second item type not returned'
        assert.contains results, eventTypes[0], 'first event type not returned'
        assert.contains results, rules[0], 'first rule not returned'
        done()

    it 'should combined search with triple and', (done) ->
      service.searchTypes {and: [{id: 'move'}, {content: /extends rule/i}, {category:'map'}]}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, rules[0], 'first rule not returned'
        done()

    it 'should combined search with and or', (done) ->
      service.searchTypes {or: [{and: [{id: 'attack'}, {content: /extends rule/i}]}, {strength:5}]}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, eventTypes[0], 'first event type not returned'
        assert.contains results, rules[1], 'second rule not returned'
        done()

    it 'should search by rank value', (done) ->
      service.searchTypes {rank: 3}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, turnRules[0], 'first turn-rule not returned'
        done()

    it 'should search by active value', (done) ->
      service.searchTypes {active: false}, (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, rules[1], 'second rule not returned'
        assert.contains results, turnRules[0], 'first turn-rule not returned'
        done()

    it 'should search by exact category', (done) ->
      service.searchTypes {category: 'map'}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, rules[0], 'first rule not returned'
        done()

    it 'should search by category regexp', (done) ->
      service.searchTypes {category: /m.*/}, (err, results)->
        return done err if err?
        assert.equal results?.length, 1
        assert.contains results, rules[0], 'first rule not returned'
        done()

    it 'should string query be usable', (done) ->
      service.searchTypes '{"or": [{"and": [{"id": "attack"}, {"content": "/extends rule/i"}]}, {"strength":5}]}', (err, results)->
        return done err if err?
        assert.equal results?.length, 2
        assert.contains results, eventTypes[0], 'first event type not returned'
        assert.contains results, rules[1], 'second rule not returned'
        done()