utils = require './utils/testUtils'
Executable = require '../main/model/Executable'
Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
service = require('../main/service/ActionService').get()
     
# TODO : configuration
root = 'D:/Programmation/Workspace2/mythic-forge-proto/game'
compiledRoot = 'D:/Programmation/Workspace2/mythic-forge-proto/lib/compiled'
 
item1 = null
item2 = null
item3 = null

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
            if err?
              throw new Error err
            type = new ItemType()
            type.name = 'character'
            type.save ->
              # Drops existing items
              Item.collection.drop ->
                # Creates 3 items
                item1 = new Item()
                item1.x = 0
                item1.y = 0
                item1.typeId = type._id
                item1.save ->
                  item2 = new Item()
                  item2.x = 1
                  item2.y = 2
                  item2.typeId = type._id
                  item2.save ->
                    item3 = new Item()
                    item3.x = 1
                    item3.y = 2
                    item3.typeId = type._id
                    item3.save ->
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

    'should rule execution modified item in database': (test) ->
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
