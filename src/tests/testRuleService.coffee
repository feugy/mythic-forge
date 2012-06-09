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
###

testUtils = require './utils/testUtils'
Executable = require '../main/model/Executable'
Item = require '../main/model/Item'
Map = require '../main/model/Map'
Field = require '../main/model/Field'
Player = require '../main/model/Player'
ItemType = require '../main/model/ItemType'
service = require('../main/service/RuleService').get()
utils = require '../main/utils'
 
map= null
player= null
type1= null
type2= null
item1= null
item2= null
item3= null
field1= null

module.exports = 

  setUp: (end) ->
    # Empties the compilation and source folders content
    testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
      Executable.resetAll -> 
        Field.collection.drop ->
          Map.collection.drop ->
            map = new Map {name: 'map-Test'}
            map.save -> end()

  'given a player and a dumb rule':
    setUp: (end) ->
      # Creates a dumb rule that always match
      script = new Executable 'rule0', """Rule = require '../main/model/Rule'
      class MyRule extends Rule
        constructor: ->
          @name= 'rule 0'
        canExecute: (actor, target, callback) =>
          callback null, true;
        execute: (actor, target, callback) =>
          callback null, 'hello !'
      module.exports = new MyRule()"""
      script.save (err) ->
        # Creates a type
        throw new Error err if err?
        Player.collection.drop ->
          new Player({login: 'Loïc'}).save (err, saved) ->
            throw new Error err if err?
            player = saved
            end()

    'should rule be applicable on player': (test) ->
      # when resolving applicable rules for the player
      service.resolve player._id, (err, results)->
        throw new Error "Unable to resolve rules: #{err}" if err?

        test.ok results isnt null and results isnt undefined
        # then the rule must have matched
        test.ok player._id of results
        test.equal 1, results[player._id].length
        test.equal 'rule 0', results[player._id][0].name 
        test.done()

    'should rule be executed for player': (test) ->
      # given an applicable rule for a target 
      service.resolve player._id, (err, results)->
        throw new Error "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute results[player._id][0].name, player._id, (err, result)->
          throw new Error "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          test.equal result, 'hello !'
          test.done()

  'given 3 items and a dumb rule':
    setUp: (end) ->
      # Creates a dumb rule that always match
      script = new Executable 'rule1', """Rule = require '../main/model/Rule'
      class MyRule extends Rule
        constructor: ->
          @name= 'rule 1'
        canExecute: (actor, target, callback) =>
          callback null, true;
        execute: (actor, target, callback) =>
          callback null, 'hello !'
      module.exports = new MyRule()"""
      script.save (err) ->
        # Creates a type
        throw new Error err if err?
        new ItemType({name: 'character'}).save (err, saved) ->
          throw new Error err if err?
          type1 = saved
          # Drops existing items
          Item.collection.drop ->
            # Creates 3 items
            new Item({map: map, x:0, y:0, type: type1}).save (err, saved) ->
              throw new Error err if err?
              item1 = saved
              new Item({map: map, x:1, y:2, type: type1}).save (err, saved) ->
                throw new Error err if err?
                item2 = saved
                new Item({map: map, x:1, y:2, type: type1}).save (err, saved) ->
                  throw new Error err if err?
                  item3 = saved
                  # Creates a field
                  new Field({map: map, x:1, y:2}).save (err, saved) ->
                    throw new Error err if err?
                    field1 = saved
                    end()

    'should rule be applicable on empty coordinates': (test) ->
      # when resolving applicable rules at a coordinate with no items
      service.resolve item1._id, -1, 0, (err, results)->
        throw new Error "Unable to resolve rules: #{err}" if err?

        test.ok results isnt null and results isnt undefined
        # then the no item found at the coordinate
        for key of results 
          test.fail 'results are not empty'
        test.done()

    'should rule be applicable on coordinates': (test) ->
      # when resolving applicable rules at a coordinate
      service.resolve item1._id, 1, 2, (err, results)->
        throw new Error "Unable to resolve rules: #{err}" if err?
        
        test.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        test.ok item2._id of results, 'The item2\'s id is not in results'
        match = results[item2._id]
        test.equal 1, match.length
        test.equal 'rule 1', match[0]?.name
        # then the dumb rule has matched the third item
        test.ok item3._id of results, 'The item3\'s id is not in results'
        match = results[item3._id]
        test.equal 1, match.length
        test.equal 'rule 1', match[0]?.name
        # then the dumb rule has matched the field
        test.ok field1._id of results, 'The field1\'s id is not in results'
        match = results[field1._id]
        test.equal 1, match.length
        test.equal 'rule 1', match[0]?.name
        test.done()
        
    'should rule be applicable on target': (test) ->
      # when resolving applicable rules for a target
      service.resolve item1._id, item2._id, (err, results)->
        throw new Error "Unable to resolve rules: #{err}" if err?
         
        test.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        test.ok item2._id of results, 'The item2\'s id is not in results'
        match = results[item2._id]
        test.equal 1, match.length
        test.equal 'rule 1', match[0]?.name
        test.done()

    'should rule be executed for target': (test) ->
      # given an applicable rule for a target 
      service.resolve item1._id, item2._id, (err, results)->
        throw new Error "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute results[item2._id][0].name, item1._id, item2._id, (err, result)->
          throw new Error "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          test.equal result, 'hello !'
          test.done()

    'should rule execution modifies item in database': (test) ->
      # given a rule that modified coordinates
      script = new Executable 'rule2', """Rule = require '../main/model/Rule'
      class MoveRule extends Rule
        constructor: ->
          @name= 'rule 2'
        canExecute: (actor, target, callback) =>
          callback null, target.get('x').valueOf() is 1
        execute: (actor, target, callback) =>
          target.x++
          callback null, 'target moved'
      module.exports = new MoveRule()"""

      script.save (err) ->
        throw new Error err if err?

        # given the rules that are applicable for a target 
        service.resolve item1._id, item2._id, (err, results)->
          throw new Error "Unable to resolve rules: #{err}" if err?

          test.equal 2, results[item2._id].length
          rule = rule for rule in results[item2._id] when rule.name is 'rule 2'
          test.ok rule isnt null

          # when executing this rule on that target
          service.execute rule.name, item1._id, item2._id, (err, result)->
            if err?
              test.fail "Unable to execute rules: #{err}"
              return test.done();

            # then the rule is executed.
            test.equal result, 'target moved'
            # then the item was modified on database
            Item.find {x:2}, (err, items) =>
              test.equal 1, items.length
              test.equal 2, items[0].x
              test.done()

  'should linked object be modified and saved by a rule': (test) ->
    # given a rule that need links resolution
    script = new Executable 'rule3', """Rule = require '../main/model/Rule'
    class DriveLeft extends Rule
      constructor: ->
        @name= 'rule 3'
      canExecute: (actor, target, callback) =>
        target.resolve ->
          callback null, target.get('pilot').equals actor
      execute: (actor, target, callback) =>
        target.resolve ->
          target.x++
          target.get('pilot').x++
          callback null, 'driven left'
    module.exports = new DriveLeft()"""
    script.save (err) ->
      # given a character type and a car type
      throw new Error err if err?
      type1 = new ItemType({name: 'character'})
      type1.setProperty 'name', 'string', ''
      type1.save (err, saved) ->
        throw new Error err if err?
        type1 = saved
        type2 = new ItemType({name: 'car'})
        type2.setProperty 'pilot', 'object', 'Item'
        type2.save (err, saved) ->
          throw new Error err if err?
          type2 = saved
          # given 3 items
          new Item({x:9, y:0, type: type1, name:'Michel Vaillant'}).save (err, saved) ->
            throw new Error err if err?
            item1 = saved
            new Item({x:9, y:0, type: type2, pilot:item1}).save (err, saved) ->
              throw new Error err if err?
              item2 = saved
              
              # given the rules that are applicable for a target 
              service.resolve item1._id, item2._id, (err, results)->
                throw new Error "Unable to resolve rules: #{err}" if err?
                throw new Error 'the rule 3 was not resolved' if results[item2._id].length isnt 1

                # when executing this rule on that target
                service.execute results[item2._id][0].name, item1._id, item2._id, (err, result)->
                  throw new Error "Unable to execute rules: #{err}" if err?

                  # then the rule is executed.
                  test.equal result, 'driven left'
                  # then the item was modified on database
                  Item.find {x:10}, (err, items) =>
                    test.equal 2, items.length
                    test.equal 10, items[0].x
                    test.equal 10, items[0].x
                    test.done()

  'should rule create new objects': (test) ->
    # given a rule that creates an object
    script = new Executable 'rule4', """Rule = require '../main/model/Rule'
    Item = require '../main/model/Item'
    module.exports = new (class AddPart extends Rule
      constructor: ->
        @name= 'rule 4'
      canExecute: (actor, target, callback) =>
        callback null, actor.get('stock').length is 0
      execute: (actor, target, callback) =>
        part = new Item {type:actor.type, name: 'part'}
        @created.push part
        actor.set 'stock', [part]
        callback null, 'part added'
    )()"""
    script.save (err) ->
      # given a type
      throw new Error err if err?
      type1 = new ItemType({name: 'container'})
      type1.setProperty 'name', 'string', ''
      type1.setProperty 'stock', 'array', 'Item'
      type1.save (err, saved) ->
        # given one item
        new Item({type: type1, name:'base'}).save (err, saved) ->
          throw new Error err if err?
          item1 = saved
              
          # given the rules that are applicable for himself
          service.resolve item1._id, item1._id, (err, results)->
            throw new Error "Unable to resolve rules: #{err}" if err?
            throw new Error 'the rule 4 was not resolved' if results[item1._id].length isnt 1

            # when executing this rule on that target
            service.execute results[item1._id][0].name, item1._id, item1._id, (err, result)->
              throw new Error "Unable to execute rules: #{err}" if err?

              # then the rule is executed.
              test.equal result, 'part added'
                # then the item was created on database
              Item.findOne {type: type1._id, name: 'part'}, (err, created) =>
                throw new Error "Item not created" if err? or not(created?)

                # then the container was modified on database
                Item.findOne {type: type1._id, name: 'base'}, (err, existing) =>
                  test.equals 1, existing.get('stock').length
                  test.ok created._id.equals existing.get('stock')[0]
                  test.done()

  'should rule delete existing objects': (test) ->
    # given a rule that creates an object
    script = new Executable 'rule5', """Rule = require '../main/model/Rule'
    module.exports = new (class RemovePart extends Rule
      constructor: ->
        @name= 'rule 5'
      canExecute: (actor, target, callback) =>
        callback null, (part for part in actor.get('stock') when target.equals(part))?
      execute: (actor, target, callback) =>
        @removed.push target
        callback null, 'part removed'
    )()"""
    script.save (err) ->
      # given a type
      throw new Error err if err?
      type1 = new ItemType({name: 'container'})
      type1.setProperty 'name', 'string', ''
      type1.setProperty 'stock', 'array', 'Item'
      type1.save (err, saved) ->
        # given two items, the second linked to the first
        new Item({type: type1, name:'part'}).save (err, saved) ->
          throw new Error err if err?
          item2 = saved
          new Item({type: type1, name:'base', stock:[item2]}).save (err, saved) ->
            throw new Error err if err?
            item1 = saved  

            # given the rules that are applicable for the both items
            service.resolve item1._id, item2._id, (err, results)->
              throw new Error "Unable to resolve rules: #{err}" if err?
              throw new Error 'the rule 5 was not resolved' if results[item2._id].length isnt 1

              # when executing this rule on that target
              service.execute results[item2._id][0].name, item1._id, item2._id, (err, result)->
                throw new Error "Unable to execute rules: #{err}" if err?

                # then the rule is executed.
                test.equal result, 'part removed'
                # then the item does not exist in database anymore
                Item.findOne {type: type1._id, name: 'part'}, (err, existing) =>
                  throw new Error "Item not created" if err?

                  test.ok existing is null
                  # then the container does not contain the part
                  Item.findOne {type: type1._id, name: 'base'}, (err, existing) =>
                    throw new Error "Item not created" if err?

                    existing.resolve ->
                      test.equal 1, existing.get('stock').length
                      test.equal null, existing.get('stock')[0]
                      test.done()

  'given an item type and an item': 

    setUp: (end) ->
      ItemType.collection.drop ->
        Item.collection.drop ->
          # given a type
          throw new Error err if err?
          type1 = new ItemType({name: 'dog'})
          type1.setProperty 'name', 'string', ''
          type1.setProperty 'fed', 'integer', 0
          type1.save (err, saved) ->
            type1 = saved
            # given two items
            new Item({type: type1, name:'lassie'}).save (err, saved) ->
              throw new Error err if err?
              item1 = saved
              new Item({type: type1, name:'medor'}).save (err, saved) ->
                throw new Error err if err?
                item2 = saved
                end()  

    'should turn rule be executed': (test) ->
      # given a turn rule on dogs
      script = new Executable 'rule6', """TurnRule = require '../main/model/TurnRule'
      Item = require '../main/model/Item'
      ObjectId = require('mongodb').BSONPure.ObjectID

      module.exports = new (class Dumb extends TurnRule
        constructor: ->
          @name= 'rule 6'
        select: (callback) =>
          Item.find {type: new ObjectId "#{type1._id}"}, callback
        execute: (target, callback) =>
          target.set 'fed', target.get('fed')+1
          callback null, "\#{target.get 'name'} was fed"
      )()"""
      script.save (err) ->
        throw new Error err if err?
        Item.count {type: type1._id}, (err, count) =>
          # when executing a trurn
          service.triggerTurn (err)->
            throw new Error "Unable to trigger turn: #{err}" if err?

            # then the both dogs where fed
            Item.findOne {type: type1._id, name: 'lassie'}, (err, existing) =>
              throw new Error "Unable to find item: #{err}" if err?
              test.equal 1, existing.get 'fed'
           
              Item.findOne {type: type1._id, name: 'medor'}, (err, existing) =>
                throw new Error "Unable to find item: #{err}" if err?
                test.equal 1, existing.get 'fed'
                test.done()