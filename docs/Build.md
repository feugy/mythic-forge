# Build instructions

Everything start from your system console.
So be prepared to run some commands !

## NodeJS and global utilities

NodeJS is used for server side. [Install the latest version](http://nodejs.org/download/) on your system.
On Unix OS, you'll need NPM (stands for Node Package Manager) which is separated from NodeJS core.

## Install node-gyp

Some dependencies (especially MongoDB driver) are need a platform-dependent build.
Node-gyp is intended to build them.
Please follow [instruction](https://github.com/TooTallNate/node-gyp)

For windows users, you'll need to install [Python 2.7.3](https://www.python.org/download/releases/2.7.3/), and a free version of [Microsoft Visual Studio Express](http://www.microsoft.com/france/visual-studio/essayez/express.aspx) (2010 or 2012 for example)

Once done, install node-gyp globally 
  > npm install -g node-gyp# NodeJS

## MongoDB

Mythic-forge make an intensive usage of [MongoDB](http://www.mongodb.org/). You'll need to install it and keep it running.
Install a 2.6.x version from [10Gen](http://docs.mongodb.org/manual/installation/)

## PhantomJS

[PhatomJS](http://phantomjs.org/) is a popular headless browser: a browser without UI. very handy for automated tests !
Follow the [installation instructions](http://phantomjs.org/download.html) and be sure to have the phatomjs executable on your path.

# Building and Developping

## Bulding with gulp

[Gulp](http://gulpjs.com/) is a wonderfull build system based on a single JavaScript file (gulpfile.js)
I suggest you to install it globally (means executable are available anywhere from command line)
  
  > npm install -g gulp

Then build the code by running the following command from the folder where you cloned the code:

 and starts the tests,
  > gulp build


`test` is a gulp task defined in the `gulpfile.js` descriptor, which is itself dependend from the `build` task.
You can run any gulp task from the command line.
The following tasks are availables:
  - watch (default) - clean, compiles coffee-script, and use watcher to recompile on the fly
  - clean - removed hyperion/lib folder
  - build - compiles coffee-script from hyperion/src to hyperion/lib 
  - test - runs all tests with mocha (configuration in test/mocha.opts)
  - deploy - compile, minify and make production ready version of rheia administration client

## Developp and test

Also you'd like to use an IDE, "compilation" will be launched from command line with gulp.
To make a single build, run 

  > gulp build

But you'll probably prefer to use 

  > gulp watch

Which watch the source files, and rebuild on every changes.

Regularly, run the tests:

  > gulp test

Or:

  > npm test

MongoDB and a net connection will be required, and it's likely to long 2 minutes (more than 650 tests)
Tests are written in BDD style with the wellknown [mocha test runner]() and [chai assertion library]().

If you whish to launch a single test file, you can do it with mocha directly (you'll need to install it globally with Npm)

  > mocha test\yourTestFile.coffee

**But** be warned that the `NODE_ENV` environnement variable must be set to `test` value before running test.
Or your developpement DB will be dropped !

## Git

Don't forget to properly configure Git.
You'll need to desactivate non-ascii management, and to commit unix-style line ends.
User name and email are also required if you want to contribute.
Run the following commands from the folder in which you cloned the code.

  > git config core.quotepath off
  > git config core.autocrlf true
  > git config user.email "your email"
  > git config user.name "your name"


## Editor

I'm trying Sublime Text 3 on Windows.
This is the configuration I set up to work properly.

  1. Download and install Sublime Text 3. Run it.
  2. Install the Package manager plugin: follown the (official instructions](http://wbond.net/sublime_packages/package_control/installation)
  3. Restart the editor.
  4. Add following packages (Ctrl+Shift+P, and `Package Controll: Install Package`):
    1. SublimeGit
    2. Better CoffeeScript
    3. Stylus
    4. Gulp
    5. SublimeMerge

But you're free to use whatever you want. Just be warned that IDE specific files must not be commited.

I run the `gulp watch` from Sublime, and launch test from a separate command line

## NodeJS debugging.

First, install node-inspector:

    npm install node-inspector -g

Then launch it in a separated command line

    node-inspector

Open with a webkit browser (chrome or safari): [http://localhost:8080/debug?port=5858](http://localhost:8080/debug?port=5858)

Then launch the program in debug mode (for example a unit test):

  mocha -d --debug-brk .\test\yourTestFile.coffee