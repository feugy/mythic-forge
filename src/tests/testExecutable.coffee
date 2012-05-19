Executable = require '../main/model/Executable'
testUtils = require './utils/testUtils'
utils = require '../main/utils'
executable = null
   
root =  utils.confKey 'executable.source'
compiledRoot =  utils.confKey 'executable.target'

module.exports = 
  setUp: (end) ->
    # Empty the source and compilation folders content
    testUtils.cleanFolder root, (err) -> testUtils.cleanFolder compiledRoot, (err) -> end(err)
      
  'should executable be created': (test) -> 
    # given a new executable
    content = 'console.log "hello world"'
    name = 'test1'
    executable = new Executable name, content
    
    # when saving it
    executable.save (err) ->
      if err? 
        test.fail "Can't save executable: #{err}"
        return test.done()

      # then it is in the file system
      Executable.find (err, executables) ->
        if err? 
          test.fail "Can't find executables: #{err}"
          return test.done()
        # then it's the only one executable
        test.equal executables.length, 1
        # then it's values were saved
        test.equal executables[0]._id, name
        test.equal executables[0].content, content
        test.done()

  'given an executable': 
    setUp: (end) ->
      executable = new Executable 'test2', 'console.log("hello world 2");'
      executable.save (err) ->
        end()

    'should executable be removed': (test) ->
      # when removing an executable
      executable.remove ->
        # then it's in the folder anymore
        Executable.find (err, executables) -> 
          if err? 
              test.fail "Can't find executables: #{err}"
              return test.done()
          test.equal executables.length, 0
          test.done()

    'should executable be updated': (test) ->
      # when modifying and saving a executable
      newContent = '# I have accents ! ééàà'
      executable.content = newContent
      executable.save ->

        Executable.find (err, executables) ->
          if err? 
            test.fail "Can't find executables: #{err}"
            return test.done()
          # then it's the only one executable
          test.equal executables.length, 1
          # then only the relevant values were modified
          test.equal executables[0].content, newContent
          test.equal executables[0]._id, 'test2'
          test.done()