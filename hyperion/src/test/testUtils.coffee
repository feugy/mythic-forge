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

utils = require '../main/utils'
assert = require('chai').assert

describe 'Utilities tests', -> 

  it 'should fixed-length token be generated', (done) -> 
    # when generating tokens with fixed length, then length must be compliant
    assert.equal 10, utils.generateToken(10).length
    assert.equal 0, utils.generateToken(0).length
    assert.equal 4, utils.generateToken(4).length
    assert.equal 20, utils.generateToken(20).length
    assert.equal 100, utils.generateToken(100).length
    done()

  it 'should token be generated with only alphabetical character', (done) -> 
    # when generating a token
    token = utils.generateToken 1000
    # then all character are within correct range
    for char in token
      char = char.toUpperCase()
      code = char.charCodeAt 0
      assert.ok code >= 40 and code <= 90, "character #{char} (#{code}) out of bounds"
      assert.ok code < 58 or code > 64, "characters #{char} (#{code}) is forbidden"
    done()