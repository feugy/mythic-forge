###
  Copyright 2010~2014 Damien Feugas
  
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

    buttons:
      rename: 'rename'
      
    labels:
      fsItemName: 'name'
      newFile: 'Create a file'
      newFolder: 'Create a folder'
      openFSItem: 'Openr "%s"'
      removeFSItem: 'Remove "%s"'
      renameFSItem: 'Rename/move "%s"'
      rootFolder: 'root'

    msgs:
      closeFileConfirm: "<p>You've modified file <b>%s</b>.</p><p>Du you whish to save modifications before closing tab ?</p>"
      externalChangeFSItem: "This file has been externally modified. Its values where updated"
      fsItemCreationFailed: "<p><b>%1$s</b> cannot be saved on server:</p><p>%2$s</p>" 
      newFile: 'Please choose a name (with its extension) for file in <b>%s</b>:'
      newFolder: 'Please choose a name for folder in <b>%s</b>:'
      removeFileConfirm: "<p>Do you really whish to remove file <b>%s</b> ?</p>"
      removeFolderConfirm: "<p>Do you really whish to remove folder <b>%s</b> and all its content ?</p>"
      renameFile: 'Please choose a new name (or path) for file:'
      renameFolder: 'Please choose a new name (or path) for folder:'

    tips:
      newFile: 'Creates a new file in the selected parent or at root'
      newFolder: 'Creates a new folder in the selected parent or at root'
      uploadInSelected: 'Uploads a new file in the selected parent or at root'
      removeFile: "Removes the currently edited file"
      removeFolder: 'Removes the selecte file or folder'
      renameSelected: 'Renames/moves the selected file or folder'
      saveFile: "Saves the currently edited file"
      searchFiles: """
        <p>Fiter explorer's files depending on their content.</p>
        <p>You can use regular expression, by starting and finishing with '/' character.</p>
        <p>Modifiers 'i' and 'm' are supported: for example <var>/app(llication)?/i</var></p>
        <p>You can choose extensions of searched files, separated by comas. For example <var>css,styl</var> to search in style sheets.</p>
        <p>To exclude extensions, prefixed them with '-'. For example: <var>-jpg,png,gif</var> to search everywhere except in images.</p>
      """