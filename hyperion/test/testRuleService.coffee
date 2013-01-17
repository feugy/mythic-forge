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

_ = require 'underscore'
async = require 'async'
testUtils = require './utils/testUtils'
Executable = require '../src/model/Executable'
Item = require '../src/model/Item'
Event = require '../src/model/Event'
Map = require '../src/model/Map'
Field = require '../src/model/Field'
Player = require '../src/model/Player'
ItemType = require '../src/model/ItemType'
EventType = require '../src/model/EventType'
FieldType = require '../src/model/FieldType'
service = require('../src/service/RuleService').get()
notifier = require('../src/service/Notifier').get()
utils = require '../src/util/common'
assert = require('chai').assert
 
map= null
map2= null
player= null
type1= null
type2= null
item1= null
item2= null
item3= null
item4= null
event1 = null
field1= null
field2= null
script= null
notifications = []

describe 'RuleService tests', ->
  
  beforeEach (done) ->
    notifications = []           
    # given a registered notification listener
    notifier.on notifier.NOTIFICATION, (event, args...) ->
      return unless event is 'turns'
      notifications.push args
    ItemType.collection.drop -> Item.collection.drop ->
      # Empties the compilation and source folders content
      testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
        Executable.resetAll -> 
          Field.collection.drop ->
            Map.collection.drop ->
              map = new Map {name: 'map-Test'}
              map.save (err) ->
                return done err if err?
                map2 = new Map {name: 'map-Test-2'}
                map2.save -> done()

  afterEach (done) ->
    # remove notifier listeners
    notifier.removeAllListeners notifier.NOTIFICATION
    done()

  it 'should linked object be modified and saved by a rule', (done) ->
    # given a rule that need links resolution
    script = new Executable 
      _id:'rule3', 
      content: """Rule = require '../model/Rule'
        class DriveLeft extends Rule
          constructor: ->
            @name= 'rule 3'
          canExecute: (actor, target, callback) =>
            target.getLinked ->
              callback null, if target.pilot.equals actor then [] else null
          execute: (actor, target, params, callback) =>
            target.getLinked ->
              target.x++
              target.pilot.x++
              callback null, 'driven left'
        module.exports = new DriveLeft()"""
    script.save (err) ->
      # given a character type and a car type
      return done err if err?
      type1 = new ItemType({name: 'character'})
      type1.setProperty 'name', 'string', ''
      type1.save (err, saved) ->
        return done err if err?
        type1 = saved
        type2 = new ItemType({name: 'car'})
        type2.setProperty 'pilot', 'object', 'Item'
        type2.save (err, saved) ->
          return done err if err?
          type2 = saved
          # given 3 items
          new Item({x:9, y:0, type: type1, name:'Michel Vaillant'}).save (err, saved) ->
            return done err if err?
            item1 = saved
            new Item({x:9, y:0, type: type2, pilot:item1}).save (err, saved) ->
              return done err if err?
              item2 = saved
              
              # given the rules that are applicable for a target 
              service.resolve item1._id, item2._id, (err, results)->
                return done "Unable to resolve rules: #{err}" if err?
                return done 'the rule 3 was not resolved' if results['rule 3'].length isnt 1

                # when executing this rule on that target
                service.execute 'rule 3', item1._id, item2._id, {}, (err, result)->
                  return done "Unable to execute rules: #{err}" if err?

                  # then the rule is executed.
                  assert.equal result, 'driven left'
                  # then the item was modified on database
                  Item.find {x:10}, (err, items) =>
                    return done "Unable to retrieve items: #{err}" if err?
                    assert.equal 2, items.length
                    assert.equal 10, items[0].x
                    assert.equal 10, items[0].x
                    done()

  it 'should rule create new objects', (done) ->
    # given a rule that creates an object
    script = new Executable
      _id:'rule4', 
      content: """Rule = require '../model/Rule'
        Item = require '../model/Item'
        module.exports = new (class AddPart extends Rule
          constructor: ->
            @name= 'rule 4'
          canExecute: (actor, target, callback) =>
            callback null, if actor.stock.length is 0 then [] else null
          execute: (actor, target, params, callback) =>
            part = new Item {type:actor.type, name: 'part'}
            @saved.push part
            actor.stock = [part]
            callback null, 'part added'
        )()"""
    script.save (err) ->
      # given a type
      return done err if err?
      type1 = new ItemType({name: 'container'})
      type1.setProperty 'name', 'string', ''
      type1.setProperty 'stock', 'array', 'Item'
      type1.save (err, saved) ->
        # given one item
        new Item({type: type1, name:'base'}).save (err, saved) ->
          return done err if err?
          item1 = saved
              
          # given the rules that are applicable for himself
          service.resolve item1._id, item1._id, (err, results)->
            return done "Unable to resolve rules: #{err}" if err?
            return done 'the rule 4 was not resolved' if results['rule 4'].length isnt 1

            # when executing this rule on that target
            service.execute 'rule 4', item1._id, item1._id, {}, (err, result)->
              return done "Unable to execute rules: #{err}" if err?

              # then the rule is executed.
              assert.equal result, 'part added'
                # then the item was created on database
              Item.findOne {type: type1._id, name: 'part'}, (err, created) =>
                return done "Item not created" if err? or not(created?)

                # then the container was modified on database
                Item.findOne {type: type1._id, name: 'base'}, (err, existing) =>
                  assert.equal 1, existing.stock.length
                  assert.ok created._id.equals existing.stock[0]
                  done()

  it 'should rule delete existing objects', (done) ->
    # given a rule that creates an object
    script = new Executable
      _id:'rule5', 
      content: """Rule = require '../model/Rule'
        module.exports = new (class RemovePart extends Rule
          constructor: ->
            @name= 'rule 5'
          canExecute: (actor, target, callback) =>
            callback null, []
          execute: (actor, target, params, callback) =>
            @removed.push target
            callback null, 'part removed'
        )()"""
    script.save (err) ->
      # given a type
      return done err if err?
      new ItemType(
        name: 'container'
        properties: 
          name: 
            type: 'string'
            def: ''
          stock: 
            type: 'array'
            def: 'Item'
          compose:
            type: 'object'
            def: 'Item'
      ).save (err, saved) ->
        return done err if err?
        type1 = saved
        # given two items, the second linked to the first
        new Item(type: type1, name:'part').save (err, saved) ->
          return done err if err?
          item2 = saved
          new Item(type: type1, name:'base', stock:[item2]).save (err, saved) ->
            return done err if err?
            item1 = saved  

            # given the rules that are applicable for the both items
            service.resolve item1._id, item2._id, (err, results)->
              return done "Unable to resolve rules: #{err}" if err?
              return done 'the rule 5 was not resolved' if results['rule 5'].length isnt 1

              # when executing this rule on that target
              service.execute 'rule 5', item1._id, item2._id, {}, (err, result)->
                return done "Unable to execute rules: #{err}" if err?

                # then the rule is executed.
                assert.equal result, 'part removed'
                # then the item does not exist in database anymore
                Item.findOne {type: type1._id, name: 'part'}, (err, existing) =>
                  return done "Item not created" if err?

                  assert.ok existing is null
                  # then the container does not contain the part
                  Item.findOne {type: type1._id, name: 'base'}, (err, existing) =>
                    return done "Item not created" if err?

                    existing.getLinked ->
                      assert.equal 0, existing.stock.length
                      done()

  describe 'given a player and a dumb rule', ->

    beforeEach (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule0'
        content:"""Rule = require '../model/Rule'
          class MyRule extends Rule
            constructor: ->
              @name= 'rule 0'
            canExecute: (actor, target, callback) =>
              callback null, []
            execute: (actor, target, params, callback) =>
              callback null, 'hello !'
          module.exports = new MyRule()"""
      script.save (err, saved) ->
        # Creates a type
        return done err if err?
        script = saved
        Player.collection.drop ->
          new Player({email: 'Loïc', password:'toto'}).save (err, saved) ->
            return done err if err?
            player = saved
            done()

    # Restore admin player for further tests
    after (done) ->
      new Player(email:'admin', password: 'admin', isAdmin:true).save done

    it 'should rule be applicable on player', (done) ->
      # when resolving applicable rules for the player
      service.resolve player._id, (err, results)->
        console.dir err
        return done "Unable to resolve rules: #{err}" if err?

        assert.ok results isnt null and results isnt undefined
        # then the rule must have matched
        assert.property results, 'rule 0'
        assert.equal 1, results['rule 0'].length
        assert.ok player.equals results['rule 0'][0].target
        done()

    it 'should rule be executed for player', (done) ->
      # given an applicable rule for a target 
      service.resolve player._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule 0', player._id, {}, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          assert.equal result, 'hello !'
          done()

    it 'should rule be exportable to client', (done) ->
      # when exporting rules to client
      service.export (err, rules) ->
        return done "Unable to export rules: #{err}" if err?

        assert.property rules, 'rule0'
        rule = rules.rule0

        # then requires have been replaced by a single define
        assert.equal 0, rule.indexOf('define(\'rule0\', [\'model/Rule\'], function(Rule){\n'), 'no define() call'
        assert.equal rule.length-3, rule.indexOf('});'), 'define() not properly closed'
        assert.equal -1, rule.indexOf('require'), 'still require() in rule'
        assert.equal -1, rule.indexOf(' Rule,'), 'still scope definition in rule'

        # then module.exports was replaced by return
        assert.equal -1, rule.indexOf('module.exports ='), 'still module.exports'
        
        # then the execute() funciton isnt available
        assert.equal -1, rule.indexOf('execute'), 'still execute() in rule' 
        assert.equal -1, rule.indexOf('hello !'), 'still execute() code in rule'
        done()

    it 'should rule be updated and modifications applicable', (done) ->
      # given a modification on rule content
      script.content = """Rule = require '../model/Rule'
        class MyRule extends Rule
          constructor: ->
            @name= 'rule 0'
          canExecute: (actor, target, callback) =>
            callback null, []
          execute: (actor, target, params, callback) =>
            callback null, 'hello modified !'
        module.exports = new MyRule()"""
      script.save (err) ->
        return done err if err?
        # given an applicable rule for a target 
        service.resolve player._id, (err, results)->
          return done "Unable to resolve rules: #{err}" if err?

          # when executing this rule on that target
          service.execute 'rule 0', player._id, {}, (err, result)->
            return done "Unable to execute rules: #{err}" if err?

            # then the modficiation was taken in account
            assert.equal result, 'hello modified !'
            done()

  describe 'given items, events, fields and a dumb rule', ->

    beforeEach (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule1', 
        content: """Rule = require '../model/Rule'
          class MyRule extends Rule
            constructor: ->
              @name= 'rule 1'
            canExecute: (actor, target, callback) =>
              callback null, []
            execute: (actor, target, params, callback) =>
              callback null, 'hello !'
          module.exports = new MyRule()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        new ItemType(
          name: 'spare'
          properties: 
            name: 
              type: 'string'
              def: ''
            parts: 
              type: 'array'
              def: 'Item'
            compose:
              type: 'object'
              def: 'Item'
        ).save (err, saved) ->
          return done err if err?
          type1 = saved
          new FieldType(name: 'plain').save (err, saved) ->
            return done err if err?
            fieldType = saved
            new EventType(name: 'communication').save (err, saved) ->
              return done err if err?
              eventType = saved
              # Drop existing events
              Event.collection.drop ->
                new Event(type: eventType).save (err, saved) ->
                  return done err if err?
                  event1 = saved
                  # Drops existing items
                  Item.collection.drop -> Field.collection.drop ->
                    # Creates some items
                    new Item(map: map, x:0, y:0, type: type1).save (err, saved) ->
                      return done err if err?
                      item1 = saved
                      new Item(map: map, x:1, y:2, type: type1).save (err, saved) ->
                        return done err if err?
                        item2 = saved
                        new Item(map: map, x:1, y:2, type: type1).save (err, saved) ->
                          return done err if err?
                          item3 = saved
                          new Item(map: map2, x:1, y:2, type: type1).save (err, saved) ->
                            return done err if err?
                            item4 = saved
                            # Creates field
                            new Field(mapId: map._id, typeId: fieldType._id, x:1, y:2).save (err, saved) ->
                              return done err if err?
                              field1 = saved
                              new Field(mapId: map2._id, typeId: fieldType._id, x:1, y:2).save (err, saved) ->
                                return done err if err?
                                field2 = saved
                                done()

    it 'should rule be applicable on empty coordinates', (done) ->
      # when resolving applicable rules at a coordinate with no items
      service.resolve item1._id, -1, 0, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        assert.ok results isnt null and results isnt undefined
        # then the no item found at the coordinate
        for key of results 
          assert.fail 'results are not empty'
        done()

    it 'should rule be applicable on coordinates', (done) ->
      # when resolving applicable rules at a coordinate
      service.resolve item1._id, 1, 2, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        assert.ok results isnt null and results isnt undefined
        # then the dumb rule has only matched objects from the first map
        assert.property results, 'rule 1'
        results = results['rule 1']
        assert.equal results.length, 3
        # then the dumb rule has matched the second item
        match = _.find results, (res) -> item2.equals res.target
        assert.isNotNull match, 'The item2\'s id is not in results'
        # then the dumb rule has matched the third item
        match = _.find results, (res) -> item3.equals res.target
        assert.isNotNull match, 'The item3\'s id is not in results'
        # then the dumb rule has matched the first field
        match = _.find results, (res) -> field1.equals res.target
        assert.isNotNull match, 'The field1\'s id is not in results'
        done()
        
    it 'should rule be applicable on coordinates with map isolation', (done) ->
      # when resolving applicable rules at a coordinate of the second map
      service.resolve item4._id, 1, 2, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        assert.ok results isnt null and results isnt undefined
        # then the dumb rule has only matched objects from the first map
        assert.property results, 'rule 1'
        results = results['rule 1']
        assert.equal results.length, 2
        # then the dumb rule has matched the fourth item
        match = _.find results, (res) -> item4.equals res.target
        assert.isNotNull match, 'The item4\'s id is not in results'
        # then the dumb rule has matched the second field
        match = _.find results, (res) -> field2.equals res.target
        assert.isNotNull match, 'The field2\'s id is not in results'
        done()

    it 'should rule be applicable on item target', (done) ->
      # when resolving applicable rules for a target
      service.resolve item1._id, item2._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?
         
        assert.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        assert.property results, 'rule 1'
        match = _.find results['rule 1'], (res) -> item2.equals res.target
        assert.isNotNull match, 'The item2\'s id is not in results'
        done()

    it 'should rule be executed for item target', (done) ->
      # given an applicable rule for a target 
      service.resolve item1._id, item2._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule 1', item1._id, item2._id, {}, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          assert.equal result, 'hello !'
          done()
        
    it 'should rule be applicable on event target', (done) ->
      # when resolving applicable rules for a target
      service.resolve item1._id, event1._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?
         
        assert.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        assert.property results, 'rule 1'
        match = _.find results['rule 1'], (res) -> event1.equals res.target
        assert.isNotNull match, 'The event1\'s id is not in results'
        done()

    it 'should rule be executed for event target', (done) ->
      # given an applicable rule for a target 
      service.resolve item1._id, event1._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule 1', item1._id, event1._id, {}, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          assert.equal result, 'hello !'
          done()
        
    it 'should rule be applicable on field target', (done) ->
      # when resolving applicable rules for a target
      service.resolve item1._id, field1._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?
         
        assert.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        assert.property results, 'rule 1'
        match = _.find results['rule 1'], (res) -> field1.equals res.target
        assert.isNotNull match, 'The field1\'s id is not in results'
        done()

    it 'should rule be executed for field target', (done) ->
      # given an applicable rule for a target 
      service.resolve item1._id, field1._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule 1', item1._id, field1._id, {}, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          assert.equal result, 'hello !'
          done()

    it 'should rule execution modifies item in database', (done) ->
      # given a rule that modified coordinates
      script = new Executable
        _id:'rule2', 
        content: """Rule = require '../model/Rule'
          class MoveRule extends Rule
            constructor: ->
              @name= 'rule 2'
            canExecute: (actor, target, callback) =>
              callback null, if target.x is 1 then [] else null
            execute: (actor, target, params, callback) =>
              target.x++
              callback null, 'target moved'
          module.exports = new MoveRule()"""

      script.save (err) ->
        return done err if err?

        # given the rules that are applicable for a target 
        service.resolve item1._id, item2._id, (err, results)->
          return done "Unable to resolve rules: #{err}" if err?

          assert.property results, 'rule 2'
          assert.equal 1, results['rule 2'].length

          # when executing this rule on that target
          service.execute 'rule 2', item1._id, item2._id, {}, (err, result)->
            if err?
              assert.fail "Unable to execute rules: #{err}"
              return done();

            # then the rule is executed.
            assert.equal result, 'target moved'
            # then the item was modified on database
            Item.find {x:2}, (err, items) =>
              return done "failed to retrieve items: #{err}" if err?
              assert.equal 1, items.length
              assert.equal 2, items[0].x
              done()

    it 'should modification be detected on dynamic attributes', (done) ->
      # given a rule that modified dynamic attributes
      new Executable(
        _id:'rule22'
        content: """Rule = require '../model/Rule'
          class AssembleRule extends Rule
            constructor: ->
              @name= 'rule 22'
            canExecute: (actor, target, callback) =>
              callback null, if target.type is actor.type and target isnt actor then [] else null
            execute: (actor, target, params, callback) =>
              target.compose = actor
              actor.parts.push target
              callback null, 'target assembled'
          module.exports = new AssembleRule()"""
      ).save (err) ->
        return done err if err?
        # when executing this rule on that target
        service.execute 'rule 22', item1._id, item2._id, {}, (err, result)->
          return done "Unable to execute rules: #{err}" if err?
          # then the rule is executed.
          assert.equal result, 'target assembled'

          # then the first item was modified on database
          Item.findById item1._id, (err, item) =>
            return done "failed to retrieve item: #{err}" if err?
            assert.ok item1.equals item
            assert.equal item.parts.length, 1
            assert.ok item2._id.equals(item.parts[0]), 'item1 do not have item2 in its parts'

            # then the second item was modified on database
            Item.findById item2._id, (err, item) =>
              return done "failed to retrieve item: #{err}" if err?
              assert.ok item2.equals item
              assert.ok item1._id.equals(item.compose), 'item2 do not compose item1'
              done()

  describe 'given an item type and an item', ->

    beforeEach (done) ->
      ItemType.collection.drop ->
        Item.collection.drop ->
          # given a type
          return done err if err?
          type1 = new ItemType({name: 'dog'})
          type1.setProperty 'name', 'string', ''
          type1.setProperty 'fed', 'integer', 0
          type1.setProperty 'execution', 'string', ''
          type1.save (err, saved) ->
            type1 = saved
            # given two items
            new Item({type: type1, name:'lassie'}).save (err, saved) ->
              return done err if err?
              item1 = saved
              new Item({type: type1, name:'medor'}).save (err, saved) ->
                return done err if err?
                item2 = saved
                done()  

    it.skip 'should turn rule be executed', (done) ->
      # given a turn rule on dogs
      script = new Executable _id:'rule6', content: """TurnRule = require '../model/TurnRule'
          Item = require '../model/Item'
          ObjectId = require('mongodb').BSONPure.ObjectID

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @name= 'rule 6'
            select: (callback) =>
              Item.find {type: new ObjectId "#{type1._id}"}, callback
            execute: (target, callback) =>
              target.fed++
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then the both dogs where fed
          Item.findOne {type: type1._id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            assert.equal 1, existing.fed, 'lassie wasn\'t fed'
         
            Item.findOne {type: type1._id, name: 'medor'}, (err, existing) =>
              return done "Unable to find item: #{err}" if err?
              assert.equal 1, existing.fed, 'medor wasn\'t fed'
              done()

    it.skip 'should turn rule be executed in right order', (done) ->
      async.forEach [
        # given a first turn rule on lassie with rank 10
        new Executable _id:'rule7', content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 7'
                @rank= 10
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                target.fed = 1
                target.execution = target.execution+','+@name
                callback null
            )()"""
      ,
        # given a another turn rule on lassie with rank 1
        new Executable _id:'rule8', content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 8'
                @rank= 1
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                target.fed = 10
                target.execution = target.execution+','+@name
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          assert.equal 6, notifications.length
          assert.equal notifications[0][0], 'begin'
          assert.equal notifications[1][0], 'rule'
          assert.equal notifications[1][1], 'rule 8'
          assert.equal notifications[2][0], 'success'
          assert.equal notifications[2][1], 'rule 8'
          assert.equal notifications[3][0], 'rule'
          assert.equal notifications[3][1], 'rule 7'
          assert.equal notifications[4][0], 'success'
          assert.equal notifications[4][1], 'rule 7'
          assert.equal notifications[5][0], 'end'
        
          # then lassie fed status was reseted, and execution order is correct
          Item.findOne {type: type1._id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            assert.equal ',rule 8,rule 7', existing.execution, 'wrong execution order'
            assert.equal 1, existing.fed, 'lassie was fed'
            done()

    it.skip 'should turn selection failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken select 
        new Executable
          _id:'rule12'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 12'
              select: (callback) =>
                callback "selection failure"
              execute: (target, callback) =>
                callback null
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          _id:'rule13'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 13'
                @rank= 2
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          assert.equal 6, notifications.length
          assert.equal notifications[0][0], 'begin'
          assert.equal notifications[1][0], 'rule'
          assert.equal notifications[1][1], 'rule 12'
          assert.equal notifications[2][0], 'failure'
          assert.equal notifications[2][1], 'rule 12'
          assert.isNotNull notifications[2][2]
          assert.include notifications[2][2], 'selection failure'
          assert.equal notifications[3][0], 'rule'
          assert.equal notifications[3][1], 'rule 13'
          assert.equal notifications[4][0], 'success'
          assert.equal notifications[4][1], 'rule 13'
          assert.equal notifications[5][0], 'end'
          done()

    it.skip 'should turn asynchronous selection failure be reported', (done) ->
      # Creates a rule with an asynchronous error in execute
      script = new Executable 
        _id:'rule27', 
        content: """TurnRule = require '../model/TurnRule'
          Item = require '../model/Item'
          _ = require 'underscore'

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @name= 'rule 27'
            select: (callback) =>
              _.defer => throw new Error @name+' throw error'
            execute: (target, callback) =>
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          assert.equal 4, notifications.length
          assert.equal notifications[0][0], 'begin'
          assert.equal notifications[1][0], 'rule'
          assert.equal notifications[1][1], 'rule 27'
          assert.equal notifications[2][0], 'failure'
          assert.equal notifications[2][1], 'rule 27'
          assert.isNotNull notifications[2][2]
          assert.include notifications[2][2], 'failed to select'
          assert.equal notifications[3][0], 'end'
          done()

    it.skip 'should turn execution failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken execute 
        new Executable
          _id:'rule14'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 14'
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback 'execution failure'
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          _id:'rule15'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 15'
                @rank= 2
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          assert.equal 6, notifications.length
          assert.equal notifications[0][0], 'begin'
          assert.equal notifications[1][0], 'rule'
          assert.equal notifications[1][1], 'rule 14'
          assert.equal notifications[2][0], 'failure'
          assert.equal notifications[2][1], 'rule 14'
          assert.isNotNull notifications[2][2]
          assert.include notifications[2][2], 'execution failure'
          assert.equal notifications[3][0], 'rule'
          assert.equal notifications[3][1], 'rule 15'
          assert.equal notifications[4][0], 'success'
          assert.equal notifications[4][1], 'rule 15'
          assert.equal notifications[5][0], 'end'
          done()
        
    it.skip 'should turn asynchronous execution failure be reported', (done) ->
      # Creates a rule with an asynchronous error in execute
      script = new Executable 
        _id:'rule28', 
        content: """TurnRule = require '../model/TurnRule'
          Item = require '../model/Item'
          _ = require 'underscore'

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @name= 'rule 28'
            select: (callback) =>
              Item.find {name: 'lassie'}, callback
            execute: (target, callback) =>
              _.defer => throw new Error @name+' throw error'
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          assert.equal 4, notifications.length
          assert.equal notifications[0][0], 'begin'
          assert.equal notifications[1][0], 'rule'
          assert.equal notifications[1][1], 'rule 28'
          assert.equal notifications[2][0], 'failure'
          assert.equal notifications[2][1], 'rule 28'
          assert.isNotNull notifications[2][2]
          assert.include notifications[2][2], 'failed to select or execute'
          assert.equal notifications[3][0], 'end'
          done()

    it.skip 'should turn update failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken update 
        new Executable
          _id:'rule16'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 16'
              select: (callback) =>
                Item.find {name: 'medor'}, callback
              execute: (target, callback) =>
                target.fed = 18
                target.save = (cb) -> cb new Error 'update failure'
                callback null
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          _id:'rule17'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 17'
                @rank= 2
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          assert.equal 6, notifications.length
          assert.equal notifications[0][0], 'begin'
          assert.equal notifications[1][0], 'rule'
          assert.equal notifications[1][1], 'rule 16'
          assert.equal notifications[2][0], 'failure'
          assert.equal notifications[2][1], 'rule 16'
          assert.isNotNull notifications[2][2]
          assert.include notifications[2][2], 'update failure'
          assert.equal notifications[3][0], 'rule'
          assert.equal notifications[3][1], 'rule 17'
          assert.equal notifications[4][0], 'success'
          assert.equal notifications[4][1], 'rule 17'
          assert.equal notifications[5][0], 'end'
          done()

    it.skip 'should turn compilation failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken require
        new Executable
          _id:'rule18'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../unknown'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 18'
              select: (callback) =>
                callback null
              execute: (target, callback) =>
                callback null
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          _id:'rule19'
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 19'
                @rank= 2
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          assert.equal 5, notifications.length
          assert.equal notifications[0][0], 'begin'
          assert.equal notifications[1][0], 'error'
          assert.equal notifications[1][1], 'rule18'
          assert.isNotNull notifications[1][2]
          assert.include notifications[1][2], 'failed to require'
          assert.equal notifications[2][0], 'rule'
          assert.equal notifications[2][1], 'rule 19'
          assert.equal notifications[3][0], 'success'
          assert.equal notifications[3][1], 'rule 19'
          assert.equal notifications[4][0], 'end'
          done()

    it.skip 'should disabled turn rule not be executed', (done) ->
      # given a disabled turn rule on lassie
      script = new Executable
        _id:'rule9', 
        content: """TurnRule = require '../model/TurnRule'
          Item = require '../model/Item'

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @name= 'rule 9'
              @active = false
            select: (callback) =>
              Item.find {name: "#{item1.name}"}, callback
            execute: (target, callback) =>
              target.fed = -1
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then lassie wasn't fed
          Item.findOne {type: type1._id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            assert.equal 0, existing.fed, 'disabled rule was executed'
            done()

    it 'should disabled rule not be resolved', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule10', 
        content: """Rule = require '../model/Rule'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 10'
              @active = false
            canExecute: (actor, target, callback) =>
              callback null, []
            execute: (actor, target, params, callback) =>
              target.name = 'changed !'
              callback null, 'hello !'
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when resolving rule
        service.resolve item1._id, item1._id, (err, results) ->
          return done "Unable to resolve rules: #{err}" if err?
          # then the rule was not resolved
          assert.notProperty results, 'rule 6', 'Disabled rule was resolved'
          done()

    it 'should disabled rule not be executed', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule11', 
        content: """Rule = require '../model/Rule'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 11'
              @active = false
            canExecute: (actor, target, callback) =>
              callback null, []
            execute: (actor, target, params, callback) =>
              target.name = 'changed !'
              callback null, 'hello !'
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when executing rule
        service.execute 'rule 11', item1._id, item1._id, {}, (err, results) ->
          # then the rule was not resolved
          assert.ok err?.indexOf('does not apply') isnt -1, 'Disabled rule was executed'
          done()

    it.skip 'should not turn rule be exportable to client', (done) ->
      # when exporting rules to client
      service.export (err, rules) ->
        return done "Unable to export rules: #{err}" if err?
        for key of rules
          assert.fail 'no rules may have been returned'
        done()

    it 'should failling rule not be resolved', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule20', 
        content: """Rule = require '../model/Rule'
          require '../unknown'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 20'
            canExecute: (actor, target, callback) =>
              callback null, []
            execute: (actor, target, params, callback) =>
              callback null
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when resolving rule
        service.resolve item1._id, item1._id, (err) ->
          # then the error is reported
          assert.isNotNull err
          assert.include err, 'failed to require'
          done()

    it 'should asynchronous failling rule not be resolved', (done) ->
      # Creates a rule with an asynchronous error in canExecute
      script = new Executable 
        _id:'rule25', 
        content: """Rule = require '../model/Rule'
          _ = require 'underscore'
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 25'
            canExecute: (actor, target, callback) =>
              _.defer => throw new Error @name+' throw error'
            execute: (actor, target, params, callback) =>
              callback null, null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing rule
        service.resolve item1._id, item1._id, (err) ->
          # then the error is reported
          assert.isNotNull err
          assert.include err, 'rule 25 throw error'
          done()

    it 'should failling rule not be executed', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule21', 
        content: """Rule = require '../model/Rule'
          require '../unknown'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 21'
            canExecute: (actor, target, callback) =>
              callback null, []
            execute: (actor, target, params, callback) =>
              callback null
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when executing rule
        service.execute 'rule 21', item1._id, item1._id, {}, (err, results) ->
          # then the error is reported
          assert.isNotNull err
          assert.include err, 'failed to require'
          done()

    it 'should asynchronous failling rule not be executed', (done) ->
      # Creates a rule with an asynchronous error in execute
      script = new Executable 
        _id:'rule26', 
        content: """Rule = require '../model/Rule'
          _ = require 'underscore'
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 26'
            canExecute: (actor, target, callback) =>
              callback null, []
            execute: (actor, target, params, callback) =>
              _.defer => throw new Error @name+' throw error'
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing rule
        service.execute 'rule 26', item1._id, item1._id, {}, (err, results) ->
          # then the error is reported
          assert.isNotNull err
          assert.include err, 'rule 26 throw error'
          done()

    it 'should incorrect parameter rule not be executed', (done) ->
      # Creates a rule with invalid parameter
      script = new Executable 
        _id:'rule23', 
        content: """Rule = require '../model/Rule'
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 23'
            canExecute: (actor, target, callback) =>
              callback null, [
                name: 'p1'
                type: 'object'
              ]
            execute: (actor, target, params, callback) =>
              callback null
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when executing rule
        service.execute 'rule 23', item1._id, item1._id, {p1: item1}, (err, results) ->
          # then the error is reported
          assert.isNotNull err
          assert.include err, 'Invalid parameter for rule 23'
          done()

    it 'should parameterized rule be executed', (done) ->
      # Creates a rule with valid parameter
      script = new Executable 
        _id:'rule24', 
        content: """Rule = require '../model/Rule'
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 24'
            canExecute: (actor, target, callback) =>
              callback null, [
                name: 'p1'
                type: 'object'
                within: [actor, target]
              ]
            execute: (actor, target, params, callback) =>
              callback null, params.p1
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing rule
        service.execute 'rule 24', item1._id, item1._id, {p1: item1._id.toString()}, (err, results) ->
          # then no error reported, and parameter was properly used
          return done err if err?
          assert.ok item1._id.equals results
          done()