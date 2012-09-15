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
utils = require '../src/utils'
ItemType = require '../src/model/ItemType'
FieldType = require '../src/model/FieldType'
EventType = require '../src/model/EventType'
Map = require '../src/model/Map'
Executable = require '../src/model/Executable'
service = require('../src/service/SearchService').get()
assert = require('chai').assert

itemTypes = []
eventTypes = []
fieldTypes = []
maps = []    
rules = [] 
turnRules = [] 

assert.contains = (array, model, message='') ->
  tmp = array.filter (obj) -> model.equals obj
  assert.ok tmp.length is 1, message
  assert.ok utils.isA(tmp[0], model.constructor)

describe 'SearchService tests', ->

  before (done) ->
    # Empties the compilation and source folders content
    testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
      Executable.resetAll -> 
        Map.collection.drop -> 
          FieldType.collection.drop -> 
            EventType.collection.drop -> 
              ItemType.collection.drop ->
                # creates some fixtures for each searchable objects
                created = [
                  clazz: ItemType
                  args:
                    name: 'character'
                    desc: 'people a player can embody'
                    quantifiable: false
                    properties:
                      name: {type:'string', def:null}
                      height: {type:'float', def:1.80}
                      strength: {type:'integer', def:10}
                      knight: {type:'boolean', def:false}
                  translated:
                    name: 'personnage'
                    desc: "personne qu'un joueur peut incarner"
                  store: itemTypes
                ,
                  clazz: ItemType
                  args: 
                    name: 'sword'
                    desc: 'a simple bastard sword'
                    quantifiable: true
                    properties:
                      color: {type:'string', def:'grey'}
                      strength: {type:'integer', def:10}
                  translated:
                    name: 'épée'
                    desc: "une simple épée batarde"
                  store: itemTypes
                ,
                  clazz: EventType
                  args: 
                    name: 'penalty'
                    desc: 'occured when player violate a rule'
                    properties:
                      turn: {type:'integer', def:1}
                      strength: {type:'integer', def:5}
                  translated:
                    name: 'pénalité'
                    desc: "appliquée lorsqu'un joueur viole une règle"
                  store: eventTypes
                ,
                  clazz: EventType
                  args: 
                    name: 'talk'
                    desc: 'a speech between players'
                    properties:
                      content: {type:'string', def:'---'}
                  translated:
                    name: 'discussion'
                    desc: 'une discussion entre joueurs'
                  store: eventTypes
                ,
                  clazz: FieldType
                  args: 
                    name: 'plain'
                    desc: 'vast green herb lands'
                  translated:
                    name: 'plaine'
                    desc: "vaste étendue d'herbe verte"
                  store: fieldTypes
                ,
                  clazz: FieldType
                  args:
                    name: 'mountain'
                    desc: 'made of rocks and ice'
                  translated:
                    name: 'montagne'
                    desc: 'faite de rocs et de glace'
                  store: fieldTypes
                ,
                  clazz: Executable
                  args: 
                    _id: 'move'
                    content:"""Rule = require '../model/Rule'
                      module.exports = new (class Move extends Rule
                        constructor: ->
                          @name= 'move'
                          @category= 'map'
                        canExecute: (actor, target, callback) =>
                          callback null, true;
                        execute: (actor, target, callback) =>
                          callback null
                      )()"""
                  store: rules
                ,
                  clazz: Executable
                  args:
                    _id: 'attack'
                    content:"""Rule = require '../model/Rule'
                      module.exports = new (class Attack extends Rule
                        constructor: ->
                          @name= 'attack'
                          @active= false
                        canExecute: (actor, target, callback) =>
                          callback null, true;
                        execute: (actor, target, callback) =>
                          callback null
                      )()"""
                  store: rules
                ,                
                  clazz: Executable
                  args:
                    _id: 'sell'
                    content:"""TurnRule = require '../model/TurnRule'
                      module.exports = new (class Sell extends TurnRule
                        constructor: ->
                          @name= 'sell'
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
                    _id: 'monsters'
                    content:"""TurnRule = require '../model/TurnRule'
                      module.exports = new (class Monsters extends TurnRule
                        constructor: ->
                          @name= 'monsters'
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
                    name: 'world map'
                    kind:'square'
                  translated:
                    name: 'carte du monde'
                  store: maps
                ,
                  clazz: Map
                  args: 
                    name: 'underworld'
                    kind:'diamond'
                  translated:
                    name: 'sous-sol'
                  store: maps
                ]
                create = (def) ->
                  return done() unless def?
                  obj = new def.clazz def.args
                  if def.translated
                    obj.set 'locale', 'fr'
                    for attr, translation of def.translated
                      obj.set attr, translation
                    obj.set 'locale', 'default'
                  obj.save (err, saved) ->
                    throw new Error err if err?
                    def.store.push saved
                    create created.splice(0, 1)[0]

                create created.splice(0, 1)[0]

  it 'should search item types by id', (done) ->
    # when searching an item type by id
    service.searchTypes {id:"#{itemTypes[0]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the first item type is returned
      assert.equal results?.length, 1
      assert.contains results, itemTypes[0], 'first item type not returned'
      done()

  it 'should search field types by id', (done) ->
    # when searching a field type by id
    service.searchTypes {id:"#{fieldTypes[1]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the second field type is returned
      assert.equal results?.length, 1
      assert.contains results, fieldTypes[1], 'second field type not returned'
      done()

  it 'should search event types by id', (done) ->
    # when searching an event type by id
    service.searchTypes {id:"#{eventTypes[0]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the first event type is returned
      assert.equal results?.length, 1
      assert.contains results, eventTypes[0], 'first event type not returned'
      done()

  it 'should search maps by id', (done) ->
    # when searching a map by id
    service.searchTypes {id:"#{maps[1]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the second map is returned
      assert.equal results?.length, 1
      assert.contains results, maps[1], 'first map not returned'
      done()

  it 'should search executable by id', (done) ->
    # when searching a rule by id
    service.searchTypes {id:"#{rules[0]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the second map is returned
      assert.equal results?.length, 1
      assert.contains results, rules[0], 'first rule not returned'
      done()

  it 'should search by exact name', (done) ->
    # when searching an item type by name
    service.searchTypes {name:"#{itemTypes[0].get('name')}"}, (err, results)->
      throw new Error err if err?
      # then only the first item type is returned
      assert.equal results?.length, 1
      assert.contains results, itemTypes[0], 'first item type not returned'
      done()

  it 'should search by regexp name', (done) ->
    # when searching by name regexp
    service.searchTypes {name:/t/i}, (err, results)->
      throw new Error err if err?
      # then first item type, both Event types, second Field type, second rule, second turn-rule are returned
      assert.equal results?.length, 6
      assert.contains results, itemTypes[0], 'first item type not returned'
      assert.contains results, eventTypes[0], 'first event type not returned'
      assert.contains results, eventTypes[1], 'second event type not returned'
      assert.contains results, fieldTypes[1], 'second field type not returned'
      assert.contains results, rules[1], 'second rule not returned'
      assert.contains results, turnRules[1], 'second turn-rule not returned'
      done()

  it 'should search by regexp name for other locale', (done) ->
    # when searching by french name regexp
    service.searchTypes {name:/é/i}, 'fr', (err, results)->
      throw new Error err if err?
      # then first event type, second item type are returned
      assert.equal results?.length, 2
      assert.contains results, itemTypes[1], 'second item type not returned'
      assert.contains results, eventTypes[0], 'first event type not returned'
      done()

  it 'should search by exact desc', (done) ->
    # when searching an event type by desc
    service.searchTypes {desc:"#{eventTypes[1].get('desc')}"}, (err, results)->
      throw new Error err if err?
      # then only the second event type is returned
      assert.equal results?.length, 1
      assert.contains results, eventTypes[1], 'second event type not returned'
      done()

  it 'should search by regexp desc', (done) ->
    # when searching by desc regexp
    service.searchTypes {desc:/an/i}, (err, results)->
      throw new Error err if err?
      # then first item type, both field types are returned
      assert.equal results?.length, 3
      assert.contains results, itemTypes[0], 'first item type not returned'
      assert.contains results, fieldTypes[0], 'first field type not returned'
      assert.contains results, fieldTypes[1], 'second field type not returned'
      done()

  it 'should search by regexp desc for other locale', (done) ->
    # when searching by french desc regexp
    service.searchTypes {desc:/joueur/i}, 'fr', (err, results)->
      throw new Error err if err?
      # then first item type, both event types are returned
      assert.equal results?.length, 3
      assert.contains results, itemTypes[0], 'first item type not returned'
      assert.contains results, eventTypes[0], 'first event type not returned'
      assert.contains results, eventTypes[1], 'second event type not returned'
      done()

  it 'should search by exact content', (done) ->
    # when searching a rule by content
    service.searchTypes {content:"#{rules[0].content}"}, (err, results)->
      throw new Error err if err?
      # then only the first rule is returned
      assert.equal results?.length, 1
      assert.contains results, rules[0], 'first rule not returned'
      done()

  it 'should search by regexp content', (done) ->
    # when searching by content regexp
    service.searchTypes {content:/extends rule/i}, (err, results)->
      throw new Error err if err?
      # then both rules are returned
      assert.equal results?.length, 2
      assert.contains results, rules[0], 'first rule not returned'
      assert.contains results, rules[1], 'second rule not returned'
      done()

  it 'should search by property existence', (done) ->
    # when searching by strength property existence
    service.searchTypes {strength: '!'}, (err, results)->
      throw new Error err if err?
      # then both item types, first event type are returned
      assert.equal results?.length, 3
      assert.contains results, itemTypes[0], 'first item type not returned'
      assert.contains results, itemTypes[1], 'second item type not returned'
      assert.contains results, eventTypes[0], 'first event type not returned'
      done()

  it 'should search by property number value', (done) ->
    # when searching by strength property number value
    service.searchTypes {strength: 10}, (err, results)->
      throw new Error err if err?
      # then both item types are returned
      assert.equal results?.length, 2
      assert.contains results, itemTypes[0], 'first item type not returned'
      assert.contains results, itemTypes[1], 'second item type not returned'
      done()

  it 'should search by property string value', (done) ->
    # when searching by content property string value
    service.searchTypes {content: '---'}, (err, results)->
      throw new Error err if err?
      # then second event type is returned
      assert.equal results?.length, 1
      assert.contains results, eventTypes[1], 'second event type not returned'
      done()

  it 'should search by property boolean value', (done) ->
    # when searching by knight property boolean value
    service.searchTypes {knight: false}, (err, results)->
      throw new Error err if err?
      # then first item type is returned
      assert.equal results?.length, 1
      assert.contains results, itemTypes[0], 'first item type not returned'
      done()

  it 'should search by property regexp value', (done) ->
    # when searching by content property regexp value
    service.searchTypes {content: /.*/}, (err, results)->
      throw new Error err if err?
      # then second event type, both rules, both turn-rules are returned
      assert.equal results?.length, 5
      assert.contains results, eventTypes[1], 'second event type not returned'
      assert.contains results, rules[0], 'first rule not returned'
      assert.contains results, rules[1], 'second rule not returned'
      assert.contains results, turnRules[0], 'first turn-rule not returned'
      assert.contains results, turnRules[1], 'second turn-rule not returned'
      done()

  it 'should search by quantifiable', (done) ->
    # when searching by quantifiable
    service.searchTypes {quantifiable: true}, (err, results)->
      throw new Error err if err?
      # then second item type is returned
      assert.equal results?.length, 1
      assert.contains results, itemTypes[1], 'second item type not returned'
      done()

  it 'should combined search with triple or', (done) ->
    # when searching with true possible condition
    service.searchTypes {or: [{name: 'character'}, {name: 'move'}, {strength:'!'}]}, (err, results)->
      throw new Error err if err?
      # then both item types, first event type, first rule are returned
      assert.equal results?.length, 4
      assert.contains results, itemTypes[0], 'first item type not returned'
      assert.contains results, itemTypes[1], 'second item type not returned'
      assert.contains results, eventTypes[0], 'first event type not returned'
      assert.contains results, rules[0], 'first rule not returned'
      done()

  it 'should combined search with triple and', (done) ->
    # when searching with true possible condition
    # TODO service.searchTypes {and: [{name: 'move'}, {content: /extends rule/i}, {category:'map'}]}, (err, results)->
    service.searchTypes {and: [{name: 'move'}, {content: /extends rule/i}]}, (err, results)->
      throw new Error err if err?
      # then first rule is returned
      assert.equal results?.length, 1
      assert.contains results, rules[0], 'first rule not returned'
      done()

  it 'should combined search with and or', (done) ->
    # when searching with true possible condition
    service.searchTypes {or: [{and: [{name: 'attack'}, {content: /extends rule/i}]}, {strength:5}]}, (err, results)->
      throw new Error err if err?
      # then second rule, first event type are returned
      assert.equal results?.length, 2
      assert.contains results, eventTypes[0], 'first event type not returned'
      assert.contains results, rules[1], 'second rule not returned'
      done()

  it 'should search by rank value', (done) ->
    # when searching by rank value
    service.searchTypes {rank: 3}, (err, results)->
      throw new Error err if err?
      # then first turn-rule is returned
      assert.equal results?.length, 1
      assert.contains results, turnRules[0], 'first turn-rule not returned'
      done()

  it 'should search by active value', (done) ->
    # when searching by active value
    service.searchTypes {active: false}, (err, results)->
      throw new Error err if err?
      # then second rule, first turn-rule are returned
      assert.equal results?.length, 2
      assert.contains results, rules[1], 'second rule not returned'
      assert.contains results, turnRules[0], 'first turn-rule not returned'
      done()

  it 'should search by exact category', (done) ->
    # when searching by exact category
    service.searchTypes {category: 'map'}, (err, results)->
      throw new Error err if err?
      # then first rule is returned
      assert.equal results?.length, 1
      assert.contains results, rules[0], 'first rule not returned'
      done()

  it 'should search by category regexp', (done) ->
    # when searching by category regexp
    service.searchTypes {category: /m.*/}, (err, results)->
      throw new Error err if err?
      # then first rule is returned
      assert.equal results?.length, 1
      assert.contains results, rules[0], 'first rule not returned'
      done()

  it 'should string query be usable', (done) ->
    # when searching by category regexp
    service.searchTypes '{"or": [{"and": [{"name": "attack"}, {"content": "/extends rule/i"}]}, {"strength":5}]}', (err, results)->
      throw new Error err if err?
      # then second rule, first event type are returned
      assert.equal results?.length, 2
      assert.contains results, eventTypes[0], 'first event type not returned'
      assert.contains results, rules[1], 'second rule not returned'
      done()
