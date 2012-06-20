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

Item = require '../main/model/Item'
checkType = Item.checkType
assert = require('chai').assert

property = {}

matrix = 

generateTest = (type, def, specs) ->
  return ->
    beforeEach (done) ->
      property.type = type
      property.def = def
      done()
  
    for spec in specs
      it "should #{spec.name} be #{spec.status}", ->
        err = checkType spec.value, property
        if 'accepted' is spec.status
          assert.ok err is null or err is undefined
        else 
          assert.ok 0 <= err?.indexOf('isn\'t a valid')

# integer value tests
describe 'Item dynamic properties tests', ->

  describe 'given an integer definition', generateTest 'integer', 10, [
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
  describe 'given a float definition', generateTest 'float', 0.1, [
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
  describe 'given a boolean definition', generateTest 'boolean', true, [
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
  describe 'given a string definition', generateTest 'string', null, [
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
  describe 'given a text definition', generateTest 'text', null, [
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
  describe 'given a date definition', generateTest 'date', null, [
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
  describe 'given an object definition', generateTest 'object', 'Item', [
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
  describe 'given an array definition', generateTest 'array', 'Item', [
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