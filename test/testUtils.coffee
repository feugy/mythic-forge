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
{join, sep, normalize, resolve} = require 'path'
git = require 'gift'
moment = require 'moment'
FieldType = require '../hyperion/src/model/FieldType'
utils = require '../hyperion/src/util/common'
versionUtils = require '../hyperion/src/util/versionning'
ruleUtils = require '../hyperion/src/util/rule'
logger = require('../hyperion/src/util/logger').getLogger 'test'
{expect} = require 'chai'

repository = normalize utils.confKey 'game.repo'
repo = null
file1 = join repository, 'file1.txt'
file2 = join repository, 'file2.txt'

# The commit utility change file content, adds it and commit it
commit = (spec, done) ->
  spec.file = [spec.file] unless Array.isArray spec.file
  spec.content = [spec.content] unless Array.isArray spec.content
  # Proceed in series, to avoid concurrent access to git repo
  async.eachSeries _.zip(spec.file, spec.content), (fileAndContent, next) ->
    fs.writeFile fileAndContent[0], fileAndContent[1], (err) ->
      return next err if err?
      repo.add fileAndContent[0].replace(repository, './'), (err) ->
        next err
  , (err) ->
    return done err if err?
    repo.commit spec.message, all:true, done

describe 'Utilities tests', -> 

  it 'should path aside to another one be made relative to each other', ->
    a = join 'folder1', 'folder2', 'compiled', 'rule'
    b = join 'folder1', 'folder2', 'lib'
    expect(utils.relativePath a, b).to.be.equal join '..', '..', 'lib'

  it 'should path above another one be made relative to each other', ->
    a = join 'folder1', 'folder2', 'lib', 'compiled', 'rule'
    b = join 'folder1', 'folder2', 'lib'
    expect(utils.relativePath a, b).to.be.equal join '..', '..'

  it 'should path under another one be made relative to each other', ->
    a = join 'folder1', 'folder2', 'lib'
    b = join 'folder1', 'folder2', 'lib', 'compiled', 'rule'
    expect(utils.relativePath a, b).to.equal ".#{sep}#{join 'compiled', 'rule'}"

  it 'should paths of another drive be made relative to each other', ->
    a = join 'folder1', 'folder2', 'lib'
    b = join 'root', 'lib'
    expect(utils.relativePath a, b).to.be.equal join '..', '..', '..', 'root', 'lib'

  it 'should fixed-length token be generated', (done) -> 
    # when generating tokens with fixed length, then length must be compliant
    expect(utils.generateToken(10)).to.have.lengthOf 10
    expect(utils.generateToken(0)).to.have.lengthOf 0
    expect(utils.generateToken(4)).to.have.lengthOf 4
    expect(utils.generateToken(20)).to.have.lengthOf 20
    expect(utils.generateToken(100)).to.have.lengthOf 100
    done()

  it 'should token be generated with only alphabetical character', (done) -> 
    # when generating a token
    token = utils.generateToken 1000
    # then all character are within correct range
    for char in token
      char = char.toUpperCase()
      code = char.charCodeAt 0
      expect(code, "character #{char} (#{code}) out of bounds").to.be.at.least(40).and.at.most 90
      expect(code, "characters #{char} (#{code}) is forbidden").to.satisfy (c) -> c < 58 or c > 64
    done()

  it 'should plainObjects keep empty objects', ->
    tree = 
      subObj: 
        empty: {}
        emptyArray: []
      subArray: [
        {},
        []
      ]
    # when transforming into plain objects
    result = utils.plainObjects tree

    # then all empty properties are still here
    expect(result).to.have.deep.property('subObj.empty').that.is.deep.equal {}
    expect(result).to.have.deep.property('subObj.emptyArray').that.is.deep.equal []
    expect(result).to.have.property('subArray').that.has.lengthOf 2
    expect(result).to.have.deep.property('subArray[0]').that.is.deep.equal {}
    expect(result).to.have.deep.property('subArray[1]').that.is.deep.equal []

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

        expect(events.length).to.be.at.least 3
        expect(events[0].seconds()).to.be.equal now.seconds()
        expect(events[1].seconds()).to.be.equal (now.seconds()+1)%60
        expect(events[2].seconds()).to.be.equal (now.seconds()+2)%60
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

        expect(events).to.have.lengthOf 1
        expect(events[0].seconds()).to.be.equal (now.seconds()+1)%60
        expect(stop.diff(events[0])).to.be.closeTo 0, 999
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

        expect(events).to.have.lengthOf 2
        expect(events[0].seconds()).to.be.equal (future.seconds()+1)%60
        expect(events[1].seconds()).to.be.equal (future.seconds()+2)%60
        expect(events[0].year()).to.be.equal moment().year() + 1
        done()
      , 3100

  describe 'given a clean model cache', ->

    beforeEach (done) ->
      # empty field types.
      FieldType.collection.drop -> FieldType.loadIdCache done

    it 'should be loaded into cache at creation', (done) ->
      now = moment()
      type = new FieldType id:'montain'
      type.save (err) ->
        return done err if err?
        expect(moment(FieldType.cachedSince 'montain').diff(now)).to.be.closeTo 0, 50
        done()

    it 'should cache since be refreshed at update', (done) ->
      now = moment()
      type = new FieldType id:'montain'
      type.save (err, type) ->
        return done err if err?
        _.delay ->
          type.descImage = 'toto.png'
          save = moment()
          type.save (err) ->
            return done err if err?
            expect(save.diff(now)).to.be.at.least 100
            expect(moment(FieldType.cachedSince 'montain').diff(save)).to.be.closeTo 0, 50
            done()
        , 100

    it 'should cache be cleared at deletion', (done) ->
      type = new FieldType id:'montain'
      type.save (err, type) ->
        return done err if err?
        _.delay ->
          type.remove (err) ->
            return done err if err?
            expect(FieldType.cachedSince('montain')).to.be.equal 0
            done()
        , 100
      
    it 'should cache be evicted after a while', (done) ->
      @timeout 1000
      type = new FieldType id:'montain'
      type.save (err, type) ->
        return done err if err?
        _.delay ->
          return done err if err?
          expect(FieldType.cachedSince('montain')).to.be.equal 0
          done()
        , 700

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
        expect(tags).to.have.lengthOf 0
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
                expect(tags).to.have.lengthOf 2
                expect(_.pluck tags, 'name').to.deep.equal [tag2, tag1]

                # then commit ids are returned
                repo.commits (err, history) ->
                  return done err if err?
                  expect(_.pluck history, 'id').to.deep.equal _.pluck tags, 'id'
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
            expect(history).to.have.lengthOf 2

            # then commit details are exact
            repo.commits (err, commits) ->
              return done err if err?
              expect(_.pluck commits, 'id').to.deep.equal _.pluck history, 'id'
              expect(_.chain(commits).pluck('author').pluck('name').value()).to.deep.equal _.pluck history, 'author'
              expect(_.pluck commits, 'message').to.deep.equal _.pluck history, 'message'
              expect(_.pluck commits, 'committed_date').to.deep.equal _.pluck history, 'date'

              # when getting file history
              versionUtils.quickHistory repo, file1.replace(repository, './'), (err, fileHistory) ->
                return done err if err?
                # then only one commit was retrieved
                expect(fileHistory).to.have.lengthOf 1
                expect(fileHistory[0]).to.deep.equal history[1]
                done()

    it 'should listRestorables returns nothing without deletion', (done) ->
      # given a commited files
      commit {file: file2, message: 'commit 1', content: 'v1'}, (err) ->
        return done err if err?

        # when listing restorable whithout deletion
        versionUtils.listRestorables repo, (err, restorables) ->
          return done err if err?

          # then no results returned
          expect(restorables).to.have.lengthOf 0
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
                expect(restorables).to.have.lengthOf 2
                paths = _.pluck restorables, 'path'
                repository = repository.replace /\\/g, '/'
                expect(paths).to.include file1.replace(/\\/g, '/').replace "#{repository}/", ''
                expect(paths).to.include file2.replace(/\\/g, '/').replace "#{repository}/", ''
                ids = _.pluck restorables, 'id'
                expect(ids[0]).to.be.equal ids[1]
                done()