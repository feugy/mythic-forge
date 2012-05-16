Item = require '../main/model/Item'
checkType = Item.checkType

property = {}

matrix = 

generateTest= (type, def, specs) ->
 test = {
    setUp: (end) ->
      property.type = type
      property.def = def
      end()
 }
 for spec in specs
    test["should #{spec.name} be #{spec.status}"] = do (spec) ->
      return (test) ->
        err = checkType spec.value, property
        if 'accepted' is spec.status
          test.ok err is null or err is undefined
        else 
          test.ok 0 <= err?.indexOf('isn\'t a valid')
        test.done()

  return test

# integer value tests
module.exports['given an integer definition'] = generateTest 'integer', 10, [
  {name: 'null', value: null, status: 'accepted'}
  {name: 'a positive integer', value: 4, status: 'accepted'}
  {name: 'a negative integer', value: -100, status: 'accepted'}
  {name: 'a constructed integer', value: new Number(100), status: 'accepted'}
  {name: 'zero', value: 0, status: 'accepted'}
  {name: 'a positive float', value: 10.56, status: 'rejected'}
  {name: 'a negative float', value: -0.4, status: 'rejected'}
  {name: 'a string', value: 'hi !', status: 'rejected'}
  {name: 'an empty string', value: '', status: 'rejected'}
  {name: 'true', value: true, status: 'rejected'}
  {name: 'false', value: false, status: 'rejected'}
  {name: 'a date', value: new Date(), status: 'rejected'}
  {name: 'an Item', value: new Item(), status: 'rejected'}
  {name: 'an Item array', value: [new Item()], status: 'rejected'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'rejected'}
]

# float value tests
module.exports['given a float definition'] = generateTest 'float', 0.1, [
  {name: 'null', value: null, status: 'accepted'}
  {name: 'a positive integer', value: 4, status: 'accepted'}
  {name: 'a negative integer', value: -100, status: 'accepted'}
  {name: 'zero', value: 0, status: 'accepted'}
  {name: 'a positive float', value: 10.56, status: 'accepted'}
  {name: 'a negative float', value: -0.4, status: 'accepted'}
  {name: 'a constructed float', value: new Number(-1.2), status: 'accepted'}
  {name: 'a string', value: 'hi !', status: 'rejected'}
  {name: 'an empty string', value: '', status: 'rejected'}
  {name: 'true', value: true, status: 'rejected'}
  {name: 'false', value: false, status: 'rejected'}
  {name: 'a date', value: new Date(), status: 'rejected'}
  {name: 'an Item', value: new Item(), status: 'rejected'}
  {name: 'an Item array', value: [new Item()], status: 'rejected'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'rejected'}
]
 
# boolean value tests
module.exports['given a boolean definition'] = generateTest 'boolean', true, [
  {name: 'null', value: null, status: 'accepted'}
  {name: 'an integer', value: -100, status: 'rejected'}
  {name: 'zero', value: 0, status: 'rejected'}
  {name: 'a float', value: 10.56, status: 'rejected'}
  {name: 'a string', value: 'hi !', status: 'rejected'}
  {name: 'an empty string', value: '', status: 'rejected'}
  {name: 'true', value: true, status: 'accepted'}
  {name: 'false', value: false, status: 'accepted'}
  {name: 'off', value: off, status: 'accepted'}
  {name: 'fAlse', value: false, status: 'accepted'}
  {name: 'a constructed boolean', value: new Boolean(false), status: 'accepted'}
  {name: 'a date', value: new Date(), status: 'rejected'}
  {name: 'an Item', value: new Item(), status: 'rejected'}
  {name: 'an Item array', value: [new Item()], status: 'rejected'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'rejected'}
]
 
# string value tests
module.exports['given a string definition'] = generateTest 'string', null, [
  {name: 'null', value: null, status: 'accepted'}
  {name: 'an integer', value: -100, status: 'rejected'}
  {name: 'zero', value: 0, status: 'rejected'}
  {name: 'a float', value: -0.4, status: 'rejected'}
  {name: 'a string', value: 'hi !', status: 'accepted'}
  {name: 'an empty string', value: '', status: 'accepted'}
  {name: 'an constructed string', value: new String('Coucou !'), status: 'rejected'}
  {name: 'true', value: true, status: 'rejected'}
  {name: 'false', value: false, status: 'rejected'}
  {name: 'a date', value: new Date(), status: 'rejected'}
  {name: 'an Item', value: new Item(), status: 'rejected'}
  {name: 'an Item array', value: [new Item()], status: 'rejected'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'rejected'}
]

# text value tests
module.exports['given a text definition'] = generateTest 'text', null, [
  {name: 'null', value: null, status: 'accepted'}
  {name: 'an integer', value: -100, status: 'rejected'}
  {name: 'zero', value: 0, status: 'rejected'}
  {name: 'a float', value: -0.4, status: 'rejected'}
  {name: 'a string', value: 'hi !', status: 'accepted'}
  {name: 'an empty string', value: '', status: 'accepted'}
  {name: 'an constructed string', value: new String('Coucou !'), status: 'rejected'}
  {name: 'true', value: true, status: 'rejected'}
  {name: 'false', value: false, status: 'rejected'}
  {name: 'a date', value: new Date(), status: 'rejected'}
  {name: 'an Item', value: new Item(), status: 'rejected'}
  {name: 'an Item array', value: [new Item()], status: 'rejected'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'rejected'}
]

# date value tests
module.exports['given a date definition'] = generateTest 'date', null, [
  {name: 'null', value: null, status: 'accepted'}
  {name: 'an integer', value: 4, status: 'rejected'}
  {name: 'zero', value: 0, status: 'rejected'}
  {name: 'a float', value: -0.4, status: 'rejected'}
  {name: 'a string', value: 'hi !', status: 'rejected'}
  {name: 'an empty string', value: '', status: 'rejected'}
  {name: 'true', value: true, status: 'rejected'}
  {name: 'false', value: false, status: 'rejected'}
  {name: 'a date', value: new Date(), status: 'accepted'}
  {name: 'an Item', value: new Item(), status: 'rejected'}
  {name: 'an Item array', value: [new Item()], status: 'rejected'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'rejected'}
]

# object value tests
module.exports['given an object definition'] = generateTest 'object', 'Item', [
  {name: 'null', value: null, status: 'accepted'}
  {name: 'an integer', value: 4, status: 'rejected'}
  {name: 'zero', value: 0, status: 'rejected'}
  {name: 'a float', value: -0.4, status: 'rejected'}
  {name: 'a string', value: 'hi !', status: 'rejected'}
  {name: 'an empty string', value: '', status: 'rejected'}
  {name: 'true', value: true, status: 'rejected'}
  {name: 'false', value: false, status: 'rejected'}
  {name: 'a date', value: new Date(), status: 'rejected'}
  {name: 'an Item', value: new Item(), status: 'accepted'}
  {name: 'an Item array', value: [new Item()], status: 'rejected'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'rejected'}
]

# array value tests
module.exports['given an array definition'] = generateTest 'array', 'Item', [
  {name: 'null', value: null, status: 'rejected'}
  {name: 'an integer', value: 4, status: 'rejected'}
  {name: 'zero', value: 0, status: 'rejected'}
  {name: 'a float', value: -0.4, status: 'rejected'}
  {name: 'a string', value: 'hi !', status: 'rejected'}
  {name: 'an empty string', value: '', status: 'rejected'}
  {name: 'true', value: true, status: 'rejected'}
  {name: 'false', value: false, status: 'rejected'}
  {name: 'a date', value: new Date(), status: 'rejected'}
  {name: 'an Item', value: new Item(), status: 'rejected'}
  {name: 'an Item array', value: [new Item()], status: 'accepted'}
  {name: 'an bigger Item array', value: [new Item(), new Item(), new Item()], status: 'accepted'}
  {name: 'an object', value: {test:true}, status: 'rejected'}
  {name: 'an object array', value: [{test:true}], status: 'rejected'}
  {name: 'an empty array', value: [], status: 'accepted'}
]