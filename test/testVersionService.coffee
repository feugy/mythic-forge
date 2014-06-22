###
  Copyright 2010~2014 Damien Feugas
  
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
service = require('../hyperion/src/service/VersionService').get()
{expect} = require 'chai'

root = normalize utils.confKey 'game.repo'
repo = null
file1 = join root, 'file1.txt'
file2 = join root, 'file2.txt'

# The commit utility change file content, adds it and commit it
commit = (spec, done) ->
  spec.file = [spec.file] unless _.isArray spec.file
  spec.content = [spec.content] unless _.isArray spec.content
  # Proceed in series, to avoid concurrent access to git repo
  async.eachSeries _.zip(spec.file, spec.content), (fileAndContent, next) ->
    fs.writeFile fileAndContent[0], fileAndContent[1], (err) ->
      return next err if err?
      service.repo.add fileAndContent[0].replace(root, './'), (err) ->
        next err
  , (err) ->
    return done err if err?
    service.repo.commit spec.message, all:true, done

describe 'VersionService tests', -> 
  @timeout 5000

  beforeEach (done) ->
    service.init true, (err, root, rep) ->
      return done err if err?
      # to avoid too quick access on repository
      _.delay done, 100

  it 'should tags returns nothing', (done) ->
    service.tags (err, tags) ->
      return done err if err?
      expect(tags).to.have.lengthOf 0
      done()

  it 'should tags returns tags with name and id', (done) ->
    tag1 = 'tag1'
    tag2 = 'a_more_long_tag_name'
    # given a first commit and tag
    commit {file: file1, message: 'commit 1', content: 'v1'}, (err) ->
      return done err if err?
      service.repo.create_tag tag1, (err) ->
        return done err if err?
        # given a second commit and tag
        commit {file: file1, message: 'commit 2', content: 'v2'}, (err) ->
          return done err if err?
          service.repo.create_tag tag2, (err) ->
            return done err if err?

            # when getting tags
            service.tags (err, tags) ->
              return done err if err?
              # then two tags where retrieved
              expect(tags).to.have.lengthOf 2
              expect(_.pluck tags, 'name').to.deep.equal [tag2, tag1], 

              # then commit ids are returned
              service.repo.commits (err, history) ->
                return done err if err?
                expect(_.pluck tags, 'id').to.deep.equal _.pluck history, 'id'
                done()

  it 'should history returns commits with name, author, message and id', (done) ->
    # given a first commit
    commit {file: file1, message: 'commit 1', content: 'v1'}, (err) ->
      return done err if err?
      # given a second commit on another file
      commit {file: file2, message: 'commit 2', content: 'v1'}, (err) ->
        return done err if err?

        # when getting history
        service.history (err, history) ->
          return done err if err?
          # then two commits were retrieved
          expect(history).to.have.lengthOf 2

          # then commit details are exact
          service.repo.commits (err, commits) ->
            return done err if err?
            expect(_.pluck history, 'id').to.deep.equal _.pluck commits, 'id'
            expect(_.pluck history, 'author').to.deep.equal _.chain(commits).pluck('author').pluck('name').value()
            expect(_.pluck history, 'message').to.deep.equal _.pluck commits, 'message'
            expect(_.pluck history, 'date').to.deep.equal _.pluck commits, 'committed_date'

            # when getting file history
            service.history file1, (err, fileHistory) ->
              return done err if err?
              # then only one commit was retrieved
              expect(fileHistory).to.have.lengthOf 1
              expect(fileHistory).to.deep.equal [history[1]]
              done()

  it 'should restorables returns nothing without deletion', (done) ->
    # given a commited files
    commit {file: file2, message: 'commit 1', content: 'v1'}, (err) ->
      return done err if err?

      # when listing restorable whithout deletion
      service.restorables (err, restorables) ->
        return done err if err?

        # then no results returned
        expect(restorables).to.have.lengthOf 0
        done()

  it 'should restorables returns deleted files', (done) ->
    # given two commited files
    commit {file: [file1, file2], message: 'commit 1', content: ['v1', 'v1']}, (err) ->
      return done "Failed on first commit: #{err}" if err?
      # given another commit on first file
      commit {file: file1, message: 'commit 2', content: 'v2'}, (err) ->
        return done "Failed on second commit: #{err}" if err?
        # given those files removed and commited
        async.each [file1, file2], utils.remove, (err) ->
          return done "Failed on removal #{err}" if err?
          service.repo.commit 'commit 3', all:true, (err) ->
            return done "Failed on third commit: #{err}" if err?
            # when listing restorables
            service.restorables (err, restorables) ->
              return done "Cannot list restorable: #{err}" if err?
              # then both files are presents
              expect(restorables).to.have.lengthOf 2
              paths = _.pluck restorables, 'path'
              antislash = new RegExp '\\\\', 'g'
              repository = root.replace antislash, '/'
              expect(paths).to.include file1.replace(antislash, '/').replace "#{repository}/", ''
              expect(paths).to.include file2.replace(antislash, '/').replace "#{repository}/", ''
              ids = _.pluck restorables, 'id'
              expect(ids[0]).to.equal ids[1]
              done()