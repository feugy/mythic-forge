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
utils = require '../main/utils'
ItemType = require '../main/model/ItemType'
FieldType = require '../main/model/FieldType'
EventType = require '../main/model/EventType'
Map = require '../main/model/Map'
Executable = require '../main/model/Executable'
service = require('../main/service/SearchService').get()
assert = require('chai').assert

itemTypes = []
eventTypes = []
fieldTypes = []
maps = []    
rules = [] 
turnRules = [] 

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
                    properties:
                      name: {type:'string', def:null}
                      height: {type:'float', def:1.80}
                      strength: {type:'integer', def:10}
                      intelligence: {type:'integer', def:10}
                  store: itemTypes
                ,
                  clazz: ItemType
                  args: 
                    name: 'sword'
                    desc: 'a simple bastard sword'
                    properties:
                      color: {type:'string', def:'grey'}
                      strength: {type:'integer', def:10}
                  store: itemTypes
                ,
                  clazz: EventType
                  args: 
                    name: 'penalty'
                    desc: 'occured when player violate a rule'
                    properties:
                      turn: {type:'integer', def:1}
                      strength: {type:'integer', def:5}
                  store: eventTypes
                ,
                  clazz: EventType
                  args: 
                    name: 'talk'
                    desc: 'a speech between players'
                    properties:
                      content: {type:'string', def:null}
                  store: eventTypes
                ,
                  clazz: FieldType
                  args: 
                    name: 'plain'
                    desc: 'vast green herb lands'
                  store: fieldTypes
                ,
                  clazz: FieldType
                  args:
                    name: 'maontain'
                    desc: 'made of rocks and ice'
                  store: fieldTypes
                ,
                  clazz: Executable
                  args: 
                    _id: 'move'
                    content:"""Rule = require '../main/model/Rule'
                      return new (class Move extends Rule
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
                    content:"""Rule = require '../main/model/Rule'
                      return new (class Attack extends Rule
                        constructor: ->
                          @name= 'attack'
                        canExecute: (actor, target, callback) =>
                          callback null, true;
                        execute: (actor, target, callback) =>
                          callback null
                      )()"""
                  store: rules
                ,
                  clazz: Map
                  args: 
                    name: 'world map'
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
                  new def.clazz(def.args).save (err, saved) ->
                    throw new Error err if err?
                    def.store.push saved
                    create created.pop()

                create created.pop()

  it 'should search item types by id', (done) ->
    # when searching an item type by id
    service.searchType {id:"#{itemTypes[0]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the first item type is returned
      assert.equal 1, results?.length
      assert.ok itemTypes[0].equals results[0]
      assert.ok utils.isA results[0], ItemType
      done()

  it 'should search field types by id', (done) ->
    # when searching a field type by id
    service.searchType {id:"#{fieldTypes[1]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the second field type is returned
      assert.equal 1, results?.length
      assert.ok fieldTypes[1].equals results[0]
      assert.ok utils.isA results[0], FieldType
      done()

  it 'should search event types by id', (done) ->
    # when searching an event type by id
    service.searchType {id:"#{eventTypes[0]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the first event type is returned
      assert.equal 1, results?.length
      assert.ok eventTypes[0].equals results[0]
      assert.ok utils.isA results[0], EventType
      done()

  it 'should search maps by id', (done) ->
    # when searching a map by id
    service.searchType {id:"#{maps[1]._id}"}, (err, results)->
      throw new Error err if err?
      # then only the second map is returned
      assert.equal 1, results?.length
      assert.ok maps[1].equals results[0]
      assert.ok utils.isA results[0], Map
      done()