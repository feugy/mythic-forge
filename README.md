[![Build Status](https://travis-ci.org/feugy/mythic-forge.png)](https://travis-ci.org/feugy/mythic-forge)
[![Dependency Status](https://david-dm.org/feugy/mythic-forge.png)](https://david-dm.org/feugy/mythic-forge)
[![Tips](http://img.shields.io/gittip/feugy.png)](https://www.gittip.com/feugy/)
                    
## Welcome !

Mythic-forge is an online gaming platform for Web developpers.

It allows you to build from scratch a entire 2D multiplayer game.

You'll need to download and install it on a serveur. Once launched, you can begin to create and play your own game.


## What kind of games can I make ?

- Web-based:

  It means that your game will be played with a (modern) web browser: Firefox or Chrome (and their respective mobile versions)

- 2D:

  Mythic-forge is based on 2D tiles, which means you can make maps (or levels) with square, diamond or even hexagonal tiles.
  
- Multiplayer:

  Many players can simultaneously play on your game. You choose to make them play alone, in groups, all together.

- Centralized:

  Every action is performed on the server, and only the server. It garantees that nobody can break your laws.
  
- Real-time:

  Every action done by a player is immediately broadcasted to all connected players: it garantees that all will play in the same universe !

- Turn-based:

  A special feature allows to set regularly planned rules. In a word: a turn. 
  
  
Mythic-forge was designed to make RPGs in the first place. But it's generic enough to powered a large variety of games !
For now, it does not have scripting built-ins (to make campaign, or just non player characters), but you can achieve it in rules.

Unfortunately, it does not suit to: 3D games, plateform games, shooters.
  

## Where do I start ?

Grab the code from github:
  
  > git clone https://github.com/feugy/mythic-forge

Then follows [Build instructions](blob/master/docs/Build.md)


## Project layout

The project layout is the following:

    atlas/          # Game client root library, used to interract with server
    docs/           # Project documentation 
    conf/           # plateform specific configuration files. You probably need to change `dev.conf`
    hyperion/       # Server code
      bin/            # Server executable
      lib/            # Generated Js from the CoffeeScript compilation (not commited !)
      src/            # Server CoffeeScript sources
    licence/        # Well... licence information :)
    node_modules/   # Server's dependencies, got by Npm (not commited !)
    rheia/          # Admin client code
      nls/            # Language bundles
      src/            # Admin client CoffeeScript sources
      style/          # Stylus style sheets and images         
      template/       # HTML Hogan template
      vendor/         # Admin client's dependencies
    tests/          # Unitary and integration tests
    gulpfile.js    # Description file for Npm.
    package.json    # Description file for Npm.


## Other considerations

It's a spare-time project :

  - I'm doing it for fun and practice. 
  - I don't want to create commercial games and earn my life with it.
  - Even if tried to make it stable and bug-free, it may radically change or be refactored.

Therefore, you're free to join and walk a little with me :)


## Previous documentation

Have a look at my first [introduction](http://www.mythic-forge.com/intro.html).