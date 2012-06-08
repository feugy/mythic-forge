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

fs = require 'fs'
p = require 'path'
async = require 'async'

module.exports =

  # Remove everything inside the specified folder, but does not removes the folder itself.
  # Do not recurse inside sub-folders
  #
  # @param path [String] full path to rhe concerned folder
  # @param  callback [Function] end callback, executed with one parameter:
  #   @param err [String] error message. Null if no error occured.
  cleanFolder: (path, callback) ->
    fs.readdir path, (err, files) ->
      if files?
        removeFile = (file, callback) -> 
          fs.unlink(p.join(path, file), (err)-> callback(err))
        async.forEach files, removeFile, (err) -> callback(err)