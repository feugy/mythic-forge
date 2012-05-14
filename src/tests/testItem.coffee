Item = require '../main/model/Item'
item = null

module.exports = 
  setUp: (end) ->
    Item.collection.drop ->
      end()

  'should item be created': (test) -> 
    # given a new Item
    item = new Item()
    item.x = 10
    item.y = -5
    
    # when saving it
    item.save (err) ->
      if err? 
        test.fail "Can't save item: #{err}"
        return test.done()

      # then it is in mongo
      Item.find {}, (err, docs) ->
        # then it's the only one document
        test.equal docs.length, 1
        # then it's values were saved
        test.equal docs[0].x, 10
        test.equal docs[0].y, -5
        test.done()

  'given an Item': 
    setUp: (end) ->
      item = new Item()
      item.x = 150
      item.y = 300
      item.save ->
        end()

    'should item be removed': (test) ->
      # when removing an item
      item.remove ->

      # then it's in mongo anymore
      Item.find {}, (err, docs) ->
        test.equal docs.length, 0
        test.done()

    'should item be updated': (test) ->
      # when modifying and saving an item
      item.x = -100
      item.save ->

        Item.find {}, (err, docs) ->
          # then it's the only one document
          test.equal docs.length, 1
          # then only the relevant values were modified
          test.equal docs[0].x, -100
          test.equal docs[0].y, 300
          test.done()