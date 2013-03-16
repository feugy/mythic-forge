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

fs = require 'fs-extra'
pathUtils = require 'path'
async = require 'async'
_ = require 'underscore'

processOp = (path, err, callback) ->
  unless err?
    return callback null 
  switch err.code 
    when 'EPERM'
      # removal not allowed: try to change permissions
      fs.chmod path, '755', (err) ->
        return callback new Error "failed to change #{path} permission before removal: #{err}" if err?
        module.exports.remove path, callback
    when 'ENOTEMPTY', 'EBUSY'
      # not empty folder: just let some time to OS to really perform deletion
      _.defer ->
        module.exports.remove path, callback
      , 50
    when 'ENOENT'
      # no file/folder: it's a success :)
      callback null
    else
      callback new Error "failed to remove #{path}: #{err}"

module.exports =

  # Remove everything inside the specified folder, but does not removes the folder itself.
  # Do not recurse inside sub-folders
  #
  # @param path [String] full path to rhe concerned folder
  # @param callback [Function] end callback, executed with one parameter:
  # @option callback err [String] error message. Null if no error occured.
  cleanFolder: (path, callback) ->
    fs.readdir path, (err, files) ->
      return callback err if err?
      
      async.forEachSeries files, (file, next) ->
        module.exports.remove pathUtils.join(path, file), next
      , (err) ->
        return callback err if err?
        _.defer -> 
          callback null
        , 50

  # rimraf's remove (used in fs-extra) have many problems on windows: provide a custom naive implementation for tests
  #
  # @param path removed file of folder
  # @param callback [Function] end callback, executed with one parameter:
  # @option callback err [String] error message. Null if no error occured.
  remove: (path, callback) ->
    fs.stat path, (err, stats) ->
      processOp path, err, (err) ->
        return callback err if err?
        # a file: unlink it
        if stats.isFile()
          return fs.unlink path, (err) -> processOp path, err, callback
        # a folder, recurse with async
        fs.readdir path, (err, contents) ->
          return callback new Error "failed to remove #{path}: #{err}" if err?
          async.forEach (pathUtils.join path, content for content in contents), module.exports.remove, (err) ->
            return callback err if err?
            # remove folder once empty
            fs.rmdir path, (err) -> processOp path, err, callback