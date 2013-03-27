# Build instruction

I'm trying Sublime Text 2 on Windows.
This is the configuration I set up to work properly.

1. Download and install Sublime Text 2. Run it.
2. Install the Package manager plugin: follown the (official instructions](http://wbond.net/sublime_packages/package_control/installation)
3. Restart the editor.
4. Add following packages (Ctrl+Shift+P, and `Package Controll: Install Package`):
  1. Git
  2. OnSaveBuild
  3. CoffeeScript

# Git
On windows, you'll need to desactivate non-ascii management :

  git config --global core.quotepath off

# Install node-gyp

Some dependencies (especially Zombie, the headless browser) need a platforme-dependent build.
Node-gyp is intended to build them.
Please follow [instruction](https://github.com/TooTallNate/node-gyp)

For windows users, you'll need to install Python 2.7.3, and a free version of Microsoft Visual Studio Express (2010 for example)

# Install phantomJS

PhatomJS is a popular headless browser: a browser without UI. very handy for automated tests !
Follow the [installation instructions](http://phantomjs.org/download.html) and be sure to have the phatomjs executable on your path.

# Node global utilities

Obviously, node is required and must be installed on your system.
Once done, install the following package globally (means executable are available anywhere from command line)

  npm install -g coffee-script
  npm install -g node-gyp

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
      "cmd": ["cake", "build"],
      "working_dir": "$project_path/$project_base_name",
      
      "windows": {
          "cmd": ["cake.cmd", "build"],
          "encoding": "cp1252"
        }
    }

Associate your project with it, and hit one time `Ctrl+B`: the src files will be compiled into the lib folder.
If you edit the `Preferences > Package Settings > SublimeOnSaveBuild ` user settings, you'll be able to launch build on file save.

# Ace Editor

Rheia uses a lot the famouse Ace Editor.
Unfortunately, he's very difficult to bundle with requireJS (in contrary to what the official site pretends).

If you want to change or upgrade the ace editor version, download the ace code on [github](https://github.com/ajaxorg/ace) and make your own distribution:

    > npm install
    > node ./Makefile.dryice.js --nc -m --target ../ace-builds

Then copy the content of ace-builds/src-noconflict-min into rheia/js/lib/ace-x.x.x-min folder, and update the requirejs path into router.js

# Running tests

Simply enter at the project root:
  
    npm test

But if you want to run only a single test class, do not forget to set NODE_ENV environment variable to 'test'

    set NODE_ENV=test
    mocha -R spec --compilers coffee:coffee-script hyperion/test/testPlayer.coffee

# NodeJS debugging.

First, install node-inspector:

    npm install node-inspector -g

Then launch it in a separated command line

    node-inspector

Open with a webkit browser (chrome or safari): [http://localhost:8080/debug?port=5858](http://localhost:8080/debug?port=5858)

Then launch the program in debug mode (for example a unit test):

  mocha -d --debug-brk .\hyperion\test