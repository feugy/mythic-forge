# Build instruction

I'm trying Sublime Text 2 on Windows.
This is the configuration I set up to work properly.

1. Download and install Sublime Text 2. Run it.
2. Install the Package manager plugin: follown the (official instructions](http://wbond.net/sublime_packages/package_control/installation)
3. Restart the editor.
4. Add following packages (Ctrl+Shift+P, and `Package Controll: Install Package`):
  1. Git
  2. NodeJS
  3. CoffeeScript

# Node global utilities

Obviously, node is required and must be installed on your system.
Once done, install the following package globally (means executable are available anywhere from command line)

  npm install -g coffee-script
  npm install -g nodeunit

# MongoDB

Mythic-forge make an intensive usage of mongoDB. You'll need to install it and keep it running.
For windows users, follow the [official instructions](http://www.mongodb.org/display/DOCS/Windows+Service)

# Project layout

Create a project, and add the source root folder in it.
The project layout is the following:

    docs/ > Project documentation 
    lib/ > Generated Js from the CoffeeScript compilation
    src/ > CoffeeScript sources
    tests/ > Unitary and integration tests
    package.json > Description file for Npm.

# CoffeScript compilation

Create a customize build system with the following configuration:

    {
      "cmd": ["coffee", "--compile", "--watch","--output", "lib", "src"],
      "working_dir": "YOUR SOURCE FOLDER ABSOLUTE PATH",
      
      "windows": {
          "cmd": ["xcopy", "src\\game", "lib\\game", "/E", "/Y", "/EXCLUDE:.xcopy", "&", "coffee.cmd", "--compile", "--watch","--output", "lib", "src"],
          "encoding": "cp1252",
          "shell": true
        }
    }

Associate your project with it, and hit one time `Ctrl+B`: the src files will be compiled into the lib folder.

# NodeJS debugging.

First, install node-inspector:

    npm install node-inspector -g

Then launch it in a separated command line

    node-inspector

Open with a webkit browser (chrome or safari): [http://localhost:8080/debug?port=5858](http://localhost:8080/debug?port=5858)

Then launch the program in debug mode (for example a unit test):

    node --debug-brk node_modules\nodeunit\bin\nodeunit lib\tests\testActionService.js