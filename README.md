# Welcome !

Mythic-forge is an online gaming platform for Web developpers.

It allows you to build from scratch a entire 2D multiplayer turn-based game.

You need to download and install it on a serveur.Once launched, you can begin to create and play your own game.


# Current status

A first version of Mythic-forge is running. It's composed of three parts:

    - Chronos, the server, providing a set of REST API for administration and game purposes
    - Prometheus, a administration RIA (Rich Internet App) : your main tool to create and manage your game.
    - A game RIA, used by your gamers, and that you will write and customize with Prometheus. 

Both RIA are written using the last HTML5/Javascript/CSS3 technologies, and relies on Resthub-JS (jQuery   RequireJS).
You'll need good web skills to write your game client.

Chronos is a Java server, that uses Jersey (JAX-RS), Spring, Hibernate (JPA), Lucene, AspectJ, and a lot of complicated stuff that you don't need to master to use it !


# The near future

I'm going to totally rewrite it, using a NodeJS brand new server.
The reasons are multiple:

	. generate faster games with an isometric system that use the same langage both server and client sides
	. benefit from MongoDB flexibility and rapidity
	. enhance my skills in NodeJS, which I'm already using in my work.

Currently, theses sources constitute a prototype that will enforce (or not) these hypotethis.
Thus, it will not be "industrialized" with complete technical documentation or automated tests. But it will come :)


# Other considerations

It's a spare-time project :
	. I'm doing it for fun and practice. 
	. I don't want to create commercial games and earn my life with it.
	. It's highly intended to change and to be refactored.

Therefore, you're free to join and walk a little with me :)


# Previous documentation

Have a look at my first [introduction](http://www.mythic-forge.com/intro.html).