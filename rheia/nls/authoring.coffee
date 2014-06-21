###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     at your option any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

define
  fr: true
  root: 
    titles:
      newFolder: "Folder creation"
      newFile: "File creation"
      renameFSItem: "Rename/move"
      restorables: "Renamed/removed files"

    buttons:
      rename: 'rename'
      
    labels:
      newFolder: 'Create a folder'
      newFile: 'Create a file'
      rootFolder: 'root'
      fsItemName: 'name'
      openFSItem: 'Openr "%s"'
      renameFSItem: 'Rename/move "%s"'
      removeFSItem: 'Remove "%s"'
      commitDetails: '%3$s: %1$s (%2$s)'
      history: 'history'

    msgs:
      newFolder: 'Please choose a name for folder in <b>%s</b>:'
      newFile: 'Please choose a name (with its extension) for file in <b>%s</b>:'
      renameFolder: 'Please choose a new name (or path) for folder:'
      renameFile: 'Please choose a new name (or path) for file:'
      removeFileConfirm: "<p>Do you really whish to remove file <b>%s</b> ?</p>"
      removeFolderConfirm: "<p>Do you really whish to remove folder <b>%s</b> and all its content ?</p>"
      closeFileConfirm: "<p>You've modified file <b>%s</b>.</p><p>Du you whish to save modifications before closing tab ?</p>"
      fsItemCreationFailed: "<p><b>%1$s</b> cannot be saved on server:</p><p>%2$s</p>" 
      restorables: "<p>This is the whole list of removed/renamed files.</p><p>Click on one file to get its content, and then save it to restore it.</p>"
      noRestorables: "<p>No files to restore.</p>"

    tips:
      newFolder: 'Creates a new folder in the selected parent or at root'
      newFile: 'Creates a new file in the selected parent or at root'
      uploadInSelected: 'Uploads a new file in the selected parent or at root'
      renameSelected: 'Renames/moves the selected file or folder'
      removeFolder: 'Removes the selecte file or folder'
      saveFile: "Saves the currently edited file"
      removeFile: "Removes the currently edited file"
      restorables: "Displays list of removed/renamed files"