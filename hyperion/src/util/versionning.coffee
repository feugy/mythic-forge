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
'use strict'

_ = require 'underscore'
utils = require '../util/common'
fs = require 'fs-extra'
async = require 'async'
pathUtil = require 'path'
git = require 'gift'

quickTags = (repo, callback) ->
  repo.git 'show-ref', {tags:true}, (err, stdout, stderr) =>
    # ignore error code 1: means no match
    err = null if err?.code is 1
    return callback "failed to read tags: #{err} #{stderr}" if err?
    tags = []

    # parse output that is commit id followed by tag name, with refs/tags/ prefix
    lines = stdout.split '\n'
    for line in lines
      idx = line.indexOf ' '
      continue if idx is -1
      tags.push 
        name: line.substring(idx+1).replace 'refs/tags/', ''
        id: line.substring 0, idx

    callback null, tags

quickHistory = (repo, file, callback) ->
  options = format:'format:"%H %at %aN|%s"'
  unless callback?
    callback = file
    file = []
  else
    file = ['--', file]
    # track renames and removes
    options.follow = true 

  repo.git 'log', options, file, (err, stdout, stderr) =>
    # ignore error code 1: means no match
    # ignore error code 128: bad revision when repository is empty
    err = null if err?.code is 1 or err?.code is 128
    return callback "failed to read history: #{err} #{stderr}" if err?
    history = []

    # parse output that is commit id followed by tag name, with refs/tags/ prefix
    lines = stdout.split '\n'
    for line in lines
      sep1 = line.indexOf ' '
      sep2 = line.indexOf ' ', sep1+1
      sep3 = line.indexOf '|', sep2+1
      continue unless sep1 isnt -1 and sep2 isnt -1 and sep3 isnt -1
      date = new Date()
      date.setTime Number "#{line.substring sep1+1, sep2}000"
      history.push 
        id: line.substring 0, sep1
        date: date
        author: line.substring sep2+1, sep3
        message: line.substring sep3+1

    callback null, history


# git initialization lock
repoInit = false
    
module.exports =

  # Initialize game source folder and its git repository.
  # 
  # @param logger [Object] logger used to trace initialization progress
  # @param callback [Function] initialization end function. Invoked with:
  # @option callback err [String] and error message, or null if no error occured
  # @option callback root [String] absolute path of the game source folder
  # @option callback repo [Object] git repository utility fully initialized
  # 
  # @overload initGameRepo(logger, reset, callback)
  #   Init game repo, but removes existing on if reset is true
  #   @param reset [Boolean] true to remove existing repository
  initGameRepo: (logger, reset, callback) ->
    [callback, reset] = [reset, false] if _.isFunction reset
    
    # in case of current initialization, retry 250ms later
    if repoInit
      return _.delay -> 
          module.exports.initGameRepo logger, reset, callback
        , 250

    root = pathUtil.resolve pathUtil.normalize utils.confKey 'game.dev'
    repository = pathUtil.dirname root
          
    # enforce folders existence at startup, synchronously!
    try 
      repoInit = true
      # force Removal if specified
      if reset and fs.existsSync repository
        try
          utils.removeSync repository 
          logger.debug "previous git repository removed..."
        catch err
          repoInit = false
          return callback err

      utils.enforceFolderSync root, false, logger
      
      finished = (err) ->
        if err
          repoInit = false
          return callback err

        # creates also the git repository
        repo = git repository
        repo.git 'config', {}, ['--file', pathUtil.join(repository, '.git', 'config'), 'user.name', 'mythic-forge'], (err) ->
          if err
            repoInit = false
            return callback err
          repo.git 'config', {}, ['--file', pathUtil.join(repository, '.git', 'config'), 'user.email', 'mythic.forge.adm@gmail.com'], (err) ->
            if err
              repoInit = false
              return callback err
            logger.debug "git repository initialized !"
            repoInit = false
            callback null, root, repo

      # Performs a 'git init' if git repository do not exists
      unless fs.existsSync pathUtil.join repository, '.git'
        logger.debug "initialize git repository at #{repository}..."
        # make repository init not parralelizable, or we'll get git errors while trying to configure user infos
        git.init repository, finished
      else
        logger.debug "using existing git repository..."
        finished()
    catch err
      repoInit = false
      return callback err
      

  # Collapse history, from a given version to previous tag (or begining)
  # Will create a tag to aim at the new collasped commit.
  # The first original commit cannot never be collapsed.
  #
  # @param repo [Git] Git tools configured on the right repository
  # @param tag [String] the tag name that will be used to create the collapse
  # @param callback [Function] collapsing end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  collapseHistory: (repo, to, callback) ->
    # get commit id corresponding to tag
    quickTags repo, (err, tags) ->
      return callback "failed to check tags: #{err}" if err?
      names = _.pluck tags, 'name'

      # checks tags validity
      return callback "cannot reuse existing tag #{to}" if to in names

      finish = ->
        # then reset to it, leaving the working copy unmodified
        repo.git 'reset', mixed:true, from, (err, stdout, stderr) ->
          return callback "failed to go back to revision #{from}: #{err}" if err?

          # now we can add and remove everything in only one commit
          repo.add [], all:true, (err, stdout, stderr) ->
            return callback "failed to add the working copy: #{err}" if err?
            repo.commit "#{to}", all:true, (err, stdout, stderr) ->
              # ignore warnings about empty working copy
              err = null if err? and -1 isnt stdout?.indexOf 'nothing to commit'
              return callback "failed to commit the working copy: #{err}" if err?

              # creates the tag
              repo.create_tag to, (err) ->
                return callback "failed to create tag: #{err}" if eff?
                # and at last run gc to clean repo
                repo.git 'gc', aggressive:true, prune:'tomorrow', (err, stdout, stderr) ->
                  return callback "failed to run garbage collector: #{err}" if err?
                  callback null

      if tags.length > 0
        # get commit is corresponding to last tag
        from = tags.pop().id
        finish()
      else
        # get first commit
        quickHistory repo, (err, history) ->
          return callback "failed to check history: #{err}" if err?
          from = history.pop().id
          finish()

  # The Gift `repo.tags()` is awsomely slow, because it gets full details of tags and their commits
  # This function just returned tag names and their corresponding ids
  #
  # @param repo [Git] Git tools configured on the right repository
  # @param callback [Function] invokation end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  # @option callback tags [Array] an array of tags (may be empty) containing for each tag an object with `name` and `id` attributes
  quickTags: quickTags

  # The Gift `repo.commits()` is limited to a certain amount of commits, and gets full details.
  # This function just returned tag names and their corresponding ids
  #
  # @param repo [Git] Git tools configured on the right repository
  # @param file [String] allows to specify a file on which retrieving commits. Optionnal
  # @param callback [Function] invokation end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  # @option callback history [Array] an array of commits (may be empty) containing for each tag an object with `author`, `message`, `date` and `id` attributes
  quickHistory: quickHistory

  # Utility to list all path of a git repository that have been deleted and could be restored.
  #
  # @param repo [Git] Git tools configured on the right repository
  # @param callback [Function] invokation end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  # @option callback restorables [Array] an array of objects (may be empty) containing `path` and `id` attributes
  listRestorables: (repo, callback) ->
    # git log --diff-filter=D --name-only --pretty=format:"%H"
    repo.git 'log', {'diff-filter': 'D', 'name-only': true, pretty:'format:"%H"'}, (err, stdout, stderr) =>
      # ignore error code 1: means no match
      # ignore error code 128: bad revision when repository is empty
      err = null if err?.code is 1 or err?.code is 128
      return callback "failed to read restorables: #{err} #{stderr}" if err?
      restorables = []

      # parse output that is commit id followed by multiple lines containing paths
      # an empty line distinguish from next commit
      lines = stdout.split '\n'
      commitId = null
      paths = []

      putInRestorables = =>
        restorables.push id: commitId, path: path for path in paths
        commitId = null
        paths = []

      for line in lines
        if commitId is null
          commitId = line 
        else if line is ''
          # all lines of this commit were found
          putInRestorables()
        else
          paths.push line.replace '"', ''
      putInRestorables()

      # remove multiples occurence of a path and only kept the last one
      restorables = _.uniq restorables, false, (element) -> element.path

      callback null, restorables