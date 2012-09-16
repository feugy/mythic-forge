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
fs = require 'fs-extra'
async = require 'async'
pathUtils = require 'path'
git = require 'gift'
utils = require '../src/utils'
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

  describe 'given an initialized git repository', ->

    repository = pathUtils.join '.', 'hyperion', 'lib', 'game-test'
    repo = null
    tag1 = 'tag1'
    tag2 = 'tag2'
    file1 = pathUtils.join repository, 'file1.txt'
    file2 = pathUtils.join repository, 'file2.txt'

    # The commit utility change file content, adds it and commit it
    commit = (spec, done) ->
      fs.writeFile spec.file, spec.content, (err) ->
        return done err if err?
        repo.add spec.file.replace(repository, '.'), (err) ->
          return done err if err?
          repo.commit spec.message, all:true, done

    before (done) ->
      fs.remove repository, (err) ->
        return done err if err?
        fs.mkdir repository, (err) ->
          return done err if err?
          git.init repository, (err) ->
            return done err if err?
            repo = git repository
            done()

    it 'should history be collapse from begining', (done) ->
      @timeout 3000

      # given three commits
      async.forEachSeries [
        {file: file1, message: 'commit 1', content: 'v1'} 
        {file: file1, message: 'commit 2', content: 'v2'} 
        {file: file1, message: 'commit 3', content: 'v3'} 
      ], commit, (err) ->
        return done err if err?

        # when collapsing history from begining
        utils.collapseHistory repo, tag1, (err) ->
          return done "Failed to collapse history: #{err}" if err?
          repo.commits (err, history) ->
            return done "Failed to consult commits: #{err}" if err?
            # then last two commits where collapsed
            assert.equal 2, history.length
            assert.equal history[0].message, "collapse for #{tag1}"
            assert.equal history[1].message, 'commit 1'

            # then a tag was added
            repo.tags (err, tags) ->
              return done err if err?
              assert.deepEqual [tag1], _.pluck tags, 'name'
              
              # then file is still to last state
              fs.readFile file1, 'utf8', (err, content) ->
                return done err if err?
                assert.equal content, 'v3'
                done()

    it 'should history be collapse from previous tag', (done) ->
      @timeout 3000

      # given three commits
      async.forEachSeries [
        {file: file2, message: 'commit 4', content: 'v1'} 
        {file: file2, message: 'commit 5', content: 'v2'} 
        {file: file2, message: 'commit 6', content: 'v3'} 
      ], commit, (err) ->
        return done err if err?

        # when collapsing history from tag1
        utils.collapseHistory repo, tag2, (err) ->
          return done "Failed to collapse history: #{err}" if err?
          repo.commits (err, history) ->
            return done "Failed to consult commits: #{err}" if err?

            # then last three commits where collapsed
            assert.equal 3, history.length
            assert.equal history[0].message, "collapse for #{tag2}"

            # then a tag was added
            repo.tags (err, tags) ->
              return done err if err?
              assert.deepEqual [tag1, tag2], _.pluck tags, 'name'
              
              # then file is still to last state
              fs.readFile file1, 'utf8', (err, content) ->
                return done err if err?
                assert.equal content, 'v3'

                fs.readFile file2, 'utf8', (err, content) ->
                  return done err if err?
                  assert.equal content, 'v3'
                  done()

    it 'should collapse failed on existing tag', (done) ->
      # when collapsing history to unknown tag
      utils.collapseHistory repo, tag2, (err) ->
        assert.isDefined err
        assert.equal err, "cannot reuse existing tag #{tag2}"
        done()