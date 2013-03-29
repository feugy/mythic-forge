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
moment = require 'moment'
utils = require '../hyperion/src/util/common'
versionUtils = require '../hyperion/src/util/versionning'
ruleUtils = require '../hyperion/src/util/rule'
logger = require('../hyperion/src/util/logger').getLogger 'test'
assert = require('chai').assert

repository = pathUtils.normalize utils.confKey 'game.dev'
repo = null
file1 = pathUtils.join repository, 'file1.txt'
file2 = pathUtils.join repository, 'file2.txt'

# The commit utility change file content, adds it and commit it
commit = (spec, done) ->
  spec.file = [spec.file] unless Array.isArray spec.file
  spec.content = [spec.content] unless Array.isArray spec.content

  async.forEach _.zip(spec.file, spec.content), (fileAndContent, next) ->
    fs.writeFile fileAndContent[0], fileAndContent[1], (err) ->
      return next err if err?
      repo.add fileAndContent[0].replace(repository, './client'), (err) ->
        next err
  , (err) ->
    return done err if err?
    repo.commit spec.message, all:true, done

describe 'Utilities tests', -> 

  it 'should path aside to another one be made relative to each other', ->
    a = pathUtils.join 'folder1', 'folder2', 'compiled', 'rule'
    b = pathUtils.join 'folder1', 'folder2', 'lib'
    assert.equal utils.relativePath(a, b), pathUtils.join '..', '..', 'lib'

  it 'should path above another one be made relative to each other', ->
    a = pathUtils.join 'folder1', 'folder2', 'lib', 'compiled', 'rule'
    b = pathUtils.join 'folder1', 'folder2', 'lib'
    assert.equal utils.relativePath(a, b), pathUtils.join '..', '..'

  it 'should path under another one be made relative to each other', ->
    a = pathUtils.join 'folder1', 'folder2', 'lib'
    b = pathUtils.join 'folder1', 'folder2', 'lib', 'compiled', 'rule'
    assert.equal utils.relativePath(a, b), ".#{pathUtils.sep}#{pathUtils.join 'compiled', 'rule'}"

  it 'should paths of another drive be made relative to each other', ->
    a = pathUtils.join 'folder1', 'folder2', 'lib'
    b = pathUtils.join 'root', 'lib'
    assert.equal utils.relativePath(a, b), pathUtils.join '..', '..', '..', 'root', 'lib'

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

  describe 'given timer configured every seconds', ->
    @timeout 4000

    it 'should time event be fired any seconds', (done) ->
      events = []
      now = null
      saveTick = (tick) -> 
        now = moment() unless now?
        events.push tick

      _.delay =>
        ruleUtils.timer.removeListener 'change', saveTick

        assert.ok events.length >= 3
        assert.equal events[0].seconds(), now.seconds()
        assert.equal events[1].seconds(), (now.seconds()+1)%60
        assert.equal events[2].seconds(), (now.seconds()+2)%60
        done()
      , 3100
      ruleUtils.timer.on 'change', saveTick

    it 'should timer be stopped', (done) ->
      events = []
      now = moment()
      stop = null
      saveTick = (tick) -> 
        stop = moment()
        events.push tick
        ruleUtils.timer.stopped = true

      _.delay =>
        ruleUtils.timer.removeListener 'change', saveTick

        assert.equal events.length, 1
        assert.equal events[0].seconds(), (now.seconds()+1)%60
        assert.closeTo stop.diff(events[0]), 0, 999
        done()
      , 2100
      ruleUtils.timer.on 'change', saveTick

    it 'should timer be modified and restarted', (done) ->
      events = []
      future = moment().add 'y', 1
      saveTick = (tick) -> events.push tick
      
      _.delay ->
        ruleUtils.timer.set future
        ruleUtils.timer.stopped = false
      , 1100
      ruleUtils.timer.on 'change', saveTick

      _.delay =>
        ruleUtils.timer.removeListener 'change', saveTick

        assert.equal events.length, 2
        assert.equal events[0].seconds(), (future.seconds()+1)%60
        assert.equal events[1].seconds(), (future.seconds()+2)%60
        assert.equal events[0].year(), moment().year() + 1
        done()
      , 3100
      
  describe 'given an initialized git repository', ->
    @timeout 5000

    tag1 = 'tag1'
    tag2 = 'tag2'

    before (done) ->
      versionUtils.initGameRepo logger, true, (err, root, rep) ->
        return done err if err?
        repo = rep
        done()

    it 'should history be collapse from begining', (done) ->

      # given three commits
      async.forEachSeries [
        {file: file1, message: 'commit 1', content: 'v1'} 
        {file: file1, message: 'commit 2', content: 'v2'} 
        {file: file1, message: 'commit 3', content: 'v3'} 
      ], commit, (err) ->
        return done err if err?

        # when collapsing history from begining
        versionUtils.collapseHistory repo, tag1, (err) ->
          return done "Failed to collapse history: #{err}" if err?
          repo.commits (err, history) ->
            return done "Failed to consult commits: #{err}" if err?
            # then last two commits where collapsed
            assert.equal 2, history.length
            assert.equal history[0].message, "#{tag1}"
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

      # given three commits
      async.forEachSeries [
        {file: file2, message: 'commit 4', content: 'v1'} 
        {file: file2, message: 'commit 5', content: 'v2'} 
        {file: file2, message: 'commit 6', content: 'v3'} 
      ], commit, (err) ->
        return done err if err?

        # when collapsing history from tag1
        versionUtils.collapseHistory repo, tag2, (err) ->
          return done "Failed to collapse history: #{err}" if err?
          repo.commits (err, history) ->
            return done "Failed to consult commits: #{err}" if err?

            # then last three commits where collapsed
            assert.equal 3, history.length
            assert.equal history[0].message, "#{tag2}"

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
      versionUtils.collapseHistory repo, tag2, (err) ->
        assert.isDefined err
        assert.equal err, "cannot reuse existing tag #{tag2}"
        done()

  describe 'given an initialized git repository', ->
    @timeout 5000

    beforeEach (done) ->
      versionUtils.initGameRepo logger, true, (err, root, rep) ->
        return done err if err?
        repo = rep
        # to avoid too quick access on repository
        _.delay done, 100

    it 'should quickTags returns nothing', (done) ->
      versionUtils.quickTags repo, (err, tags) ->
        return done err if err?
        assert.equal 0, tags?.length
        done()

    it 'should quickTags returns tags with name and id', (done) ->
      tag1 = 'tag1'
      tag2 = 'a_more_long_tag_name'
      # given a first commit and tag
      commit {file: file1, message: 'commit 1', content: 'v1'}, (err) ->
        return done err if err?
        repo.create_tag tag1, (err) ->
          return done err if err?
          # given a second commit and tag
          commit {file: file1, message: 'commit 2', content: 'v2'}, (err) ->
            return done err if err?
            repo.create_tag tag2, (err) ->
              return done err if err?

              # when getting tags
              versionUtils.quickTags repo, (err, tags) ->
                return done err if err?
                # then two tags where retrieved
                assert.equal 2, tags?.length
                assert.deepEqual [tag2, tag1], _.pluck tags, 'name'

                # then commit ids are returned
                repo.commits (err, history) ->
                  return done err if err?
                  assert.deepEqual _.pluck(history, 'id'), _.pluck tags, 'id'
                  done()

    it 'should quickHistory returns commits with name, author, message and id', (done) ->
      # given a first commit
      commit {file: file1, message: 'commit 1', content: 'v1'}, (err) ->
        return done err if err?
        # given a second commit on another file
        commit {file: file2, message: 'commit 2', content: 'v1'}, (err) ->
          return done err if err?

          # when getting history
          versionUtils.quickHistory repo, (err, history) ->
            return done err if err?
            # then two commits were retrieved
            assert.equal 2, history?.length

            # then commit details are exact
            repo.commits (err, commits) ->
              return done err if err?
              assert.deepEqual _.pluck(commits, 'id'), _.pluck history, 'id'
              assert.deepEqual _.chain(commits).pluck('author').pluck('name').value(), _.pluck history, 'author'
              assert.deepEqual _.pluck(commits, 'message'), _.pluck history, 'message'
              assert.deepEqual _.pluck(commits, 'committed_date'), _.pluck history, 'date'

              # when getting file history
              versionUtils.quickHistory repo, file1.replace(repository, './client'), (err, fileHistory) ->
                return done err if err?
                # then only one commit was retrieved
                assert.equal 1, fileHistory?.length
                assert.deepEqual fileHistory[0], history[1]
                done()

    it 'should listRestorables returns nothing without deletion', (done) ->
      # given a commited files
      commit {file: file2, message: 'commit 1', content: 'v1'}, (err) ->
        return done err if err?

        # when listing restorable whithout deletion
        versionUtils.listRestorables repo, (err, restorables) ->
          return done err if err?

          # then no results returned
          assert.equal 0, restorables?.length
          done()

    it 'should listRestorables returns deleted files', (done) ->
      # given two commited files
      commit {file: [file1, file2], message: 'commit 1', content: ['v1', 'v1']}, (err) ->
        return done "Failed on first commit: #{err}" if err?
        # given another commit on first file
        commit {file: file1, message: 'commit 2', content: 'v2'}, (err) ->
          return done "Failed on second commit: #{err}" if err?
          # given those files removed and commited
          async.forEach [file1, file2], utils.remove, (err) ->
            return done "Failed on removal #{err}" if err?
            repo.commit 'commit 3', all:true, (err) ->
              return done "Failed on third commit: #{err}" if err?

              # when listing restorables
              versionUtils.listRestorables repo, (err, restorables) ->
                return done "Cannot list restorable: #{err}" if err?
                # then both files are presents
                assert.equal 2, restorables?.length
                paths = _.pluck restorables, 'path'
                assert.include paths, file1.replace(repository, 'client').replace '\\', '/'
                assert.include paths, file2.replace(repository, 'client').replace '\\', '/'
                ids = _.pluck restorables, 'id'
                assert.equal ids[0], ids[1]
                done()