utils = require './utils/testUtils'
Executable = require '../main/model/Executable'
Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
service = require('../main/service/ActionService').get()
     
# TODO : configuration
root = 'D:/Programmation/Workspace2/mythic-forge-proto/game'
compiledRoot = 'D:/Programmation/Workspace2/mythic-forge-proto/lib/compiled'
 
type1= null
type2= null
item1= null
item2= null
item3= null

module.exports = 

  'given 3 items and a dumb rule':
    setUp: (end) ->
      # Empties the compiled folder content
      utils.cleanFolder compiledRoot, (err) ->
        # Empties the root folder content
        utils.cleanFolder root, (err) ->
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
                new Item({x:0, y:0, type: type1}).save (err, saved) ->
                  throw new Error err if err?
                  item1 = saved
                  new Item({x:1, y:2, type: type1}).save (err, saved) ->
                    throw new Error err if err?
                    item2 = saved
                    new Item({x:1, y:2, type: type1}).save (err, saved) ->
                      throw new Error err if err?
                      item3 = saved
                      end(err)

    'should rule be applicable on empty coordinates': (test) ->
      # when resolving applicable rules at a coordinate with no items
      service.resolve item1, -1, 0, (err, results)->
        if err?
          test.fail "Unable to resolve rules: #{err}"
          return test.done();
        
        test.ok results isnt null and results isnt undefined
        # then the no item found at the coordinate
        for key of results 
          test.fail 'results are not empty'
        test.done()

    'should rule be applicable on coordinates': (test) ->
      # when resolving applicable rules at a coordinate
      service.resolve item1, 1, 2, (err, results)->
        if err?
          test.fail "Unable to resolve rules: #{err}"
          return test.done();
        
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
        test.done()
        
    'should rule be applicable on target': (test) ->
      # when resolving applicable rules for a target
      service.resolve item1, item2, (err, results)->
        if err?
          test.fail "Unable to resolve rules: #{err}"
          return test.done();
         
        test.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        test.ok item2._id of results, 'The item2\'s id is not in results'
        match = results[item2._id]
        test.equal 1, match.length
        test.equal 'rule 1', match[0]?.name
        test.done()

    'should rule be executed for target': (test) ->
      # given an applicable rule for a target 
      service.resolve item1, item2, (err, results)->
        if err?
          test.fail "Unable to resolve rules: #{err}"
          return test.done();

        # when executing this rule on that target
        service.execute results[item2._id][0], item1, item2, (err, result)->
          if err?
            test.fail "Unable to execute rules: #{err}"
            return test.done();

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
          callback null, target.x.valueOf() == 1
        execute: (actor, target, callback) =>
          target.x++
          callback null, 'target moved'
      module.exports = new MoveRule()"""

      script.save (err) ->
        if err?
          throw new Error err

        # given the rules that are applicable for a target 
        service.resolve item1, item2, (err, results)->
          if err?
            test.fail "Unable to resolve rules: #{err}"
            return test.done();

          test.equal 2, results[item2._id].length
          rule = (rule for rule in results[item2._id] when rule.name == 'rule 2')[0];
          test.ok rule isnt null

          # when executing this rule on that target
          service.execute rule, item1, item2, (err, result)->
            if err?
              test.fail "Unable to execute rules: #{err}"
              return test.done();

            # then the rule is executed.
            test.equal result, 'target moved'
            # then the item was modified
            test.equal 2, item2.x
            # then the item was modified on database
            Item.find {x:2}, (err, items) =>
              test.equal 1, items.length
              test.equal 2, items[0].x
              test.done()

  'given 2 items and a rule that resolve links and modify things':
    setUp: (end) ->
      # Empties the compiled folder content
      utils.cleanFolder compiledRoot, (err) ->
        # Empties the root folder content
        utils.cleanFolder root, (err) ->
          # Creates a rule that need links resolution
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
            # Creates a character type and a car type
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
                # Drops existing items
                Item.collection.drop ->
                  # Creates 3 items
                  new Item({x:0, y:0, type: type1, name:'Michel Vaillant'}).save (err, saved) ->
                    throw new Error err if err?
                    item1 = saved
                    new Item({x:0, y:0, type: type2, pilot:item1}).save (err, saved) ->
                      throw new Error err if err?
                      item2 = saved
                      end(err)

    'should rule execution modifies item in database': (test) ->
      # given the rules that are applicable for a target 
      service.resolve item1, item2, (err, results)->
        if err?
          test.fail "Unable to resolve rules: #{err}"
          return test.done();

        if results[item2._id].length isnt 1
          test.fail 'the rule 2 was not resolved'
          return test.done()

        # when executing this rule on that target
        service.execute results[item2._id][0], item1, item2, (err, result)->
          if err?
            test.fail "Unable to execute rules: #{err}"
            return test.done();

          # then the rule is executed.
          test.equal result, 'driven left'
          # then the item was modified
          test.equal 1, item2.x
          test.equal 1, item1.x
          # then the item was modified on database
          Item.find {x:1}, (err, items) =>
            test.equal 2, items.length
            console.dir items
            test.equal item1.equals items[0]
            test.equal item2.equals items[1]
            test.done()

