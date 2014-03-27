# Bugs
  - possibilité d'aller dans la base des autres
  - joueur sans personnage : ni mort, mais doit encore passer les tours
  - valeur affichée comme résultat du premier tir: undefined
TypeError: Cannot read property 'effects' of undefined at http://mythic-forge.com/game/1395906357324/script/main.js:11:24932 <http://mythic-forge.com/game/1395906357324/script/main.js>  at Object.r.navigate (http://mythic-forge.com/game/1395906357324/script/main.js:11:25521 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at Object.r.stopReplay (http://mythic-forge.com/game/1395906357324/script/main.js:11:24384 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at u._onStopReplay (http://mythic-forge.com/game/1395906357324/script/main.js:9:30711 <http://mythic-forge.com/game/1395906357324/script/main.js> ) 
at http://mythic-forge.com/game/1395906357324/script/main.js:6:20184 <http://mythic-forge.com/game/1395906357324/script/main.js>  at http://mythic-forge.com/game/1395906357324/script/main.js:6:27061 <http://mythic-forge.com/game/1395906357324/script/main.js>  at u.$eval (http://mythic-forge.com/game/1395906357324/script/main.js:5:17797 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at u.$apply (http://mythic-forge.com/game/1395906357324/script/main.js:5:18075 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at HTMLAnchorElement.<anonymous> (http://mythic-forge.com/game/1395906357324/script/main.js:6:27043 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at HTMLAnchorElement.ot.event.dispatch (http://mythic-forge.com/game/1395906357324/script/main.js:2:17579 <http://mythic-forge.com/game/1395906357324/script/main.js> ) 
  - FF 27 et 28 > pas de connectivité WS
  - soucis du requestAnimationFrame sous Chrome (features detection)
  - disparition du message d'info déploiement
  - suicide du missile launcher > mauvais décompte des actions
  - déplacement apply already in progress
  - tir décomptabilisé sur cible mouvante: pas d'affichage dans l'historique
  - attaque corps à corps: pistolAxe|gloveSword vs. dreadnought
Cannot call method 'match' of undefined at module.exports.rollDices (/home/feugy/deephulk/compiled/common.js:122:18) at Promise.<anonymous> (/home/feugy/deephulk/compiled/assault.js:111:28) at Promise.<anonymous> (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/mpromise/lib/promise.js:177:8) at Promise.EventEmitter.emit (events.js:95:17) at Promise.emit (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/mpromise/lib/promise.js:84:38) at Promise.fulfill (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/mpromise/lib/promise.js:97:20) at Promise.resolve (/home/feugy/mythic-forge/node_modules/mongoose/lib/promise.js:108:15) at Promise.<anonymous> 
(/home/feugy/mythic-forge/node_modules/mongoose/node_modules/mpromise/lib/promise.js:177:8) at Promise.EventEmitter.emit (events.js:95:17) at Promise.emit (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/mpromise/lib/promise.js:84:38) at Promise.fulfill (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/mpromise/lib/promise.js:97:20) at /home/feugy/mythic-forge/node_modules/mongoose/lib/query.js:1052:26 at model.Document.init (/home/feugy/mythic-forge/node_modules/mongoose/lib/document.js:250:11) at model._done (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/hooks/hooks.js:59:24) at _next (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/hooks/hooks.js:52:28) at fnWrapper (/home/feugy/mythic-forge/node_modules/mongoose/node_modules/hooks/hooks.js:159:8) at /home/feugy/mythic-forge/hyperion/lib/model/typeFactory.js:485:16 at /home/feugy/mythic-forge/hyperion/lib/model/typeFactory.js:325:16 at [object Object]._onTimeout (/home/feugy/mythic-forge/node_modules/underscore/underscore.js:647:47) at Timer.listOnTimeout [as ontimeout] (timers.js:110:15) 
  - flood 'no document found' dans le chat
  - déploiement blip: parfois a 0 (ork)

# TODO
  - cannon d'assaut pas clair a utiliser
  - indication replay en cours, fin du replay en cas de nouveau tour ?
  - zone pas assez visible sur les diagonales, pas toujours mise à jour
  - zoom recharge tout (ou zoom non bloquant, ou zoom pas sur la molette, pas de disparition des tooltips)
  - changement de la navigation sur la carte: drag'n drop plutôt que haptic
  - remplacer les zones deployables par une ouverture de porte
  - missions
  - image commandant du chaos
  - miniature commandant du chaos
  - action déplacement par défaut
  - action sur le clavier (raccourcis)
  - status d'activité des autres joueur ?
  - afficher les jets de des ou probabilité de réussite du jet
  - position partagée et plus de possibilité de déplacement

# TODO plus tard
  - équipements
  - ordres
  - événements
  - campagne et évolution
  - classement
  - path finding
  - animations (déplacement, tir, corps à corps, mort)