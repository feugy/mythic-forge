# Bugs
  - erreur inconnue:
TypeError: Cannot read property 'effects' of undefined at http://mythic-forge.com/game/1395906357324/script/main.js:11:24932 <http://mythic-forge.com/game/1395906357324/script/main.js>  at Object.r.navigate (http://mythic-forge.com/game/1395906357324/script/main.js:11:25521 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at Object.r.stopReplay (http://mythic-forge.com/game/1395906357324/script/main.js:11:24384 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at u._onStopReplay (http://mythic-forge.com/game/1395906357324/script/main.js:9:30711 <http://mythic-forge.com/game/1395906357324/script/main.js> ) 
at http://mythic-forge.com/game/1395906357324/script/main.js:6:20184 <http://mythic-forge.com/game/1395906357324/script/main.js>  at http://mythic-forge.com/game/1395906357324/script/main.js:6:27061 <http://mythic-forge.com/game/1395906357324/script/main.js>  at u.$eval (http://mythic-forge.com/game/1395906357324/script/main.js:5:17797 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at u.$apply (http://mythic-forge.com/game/1395906357324/script/main.js:5:18075 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at HTMLAnchorElement.<anonymous> (http://mythic-forge.com/game/1395906357324/script/main.js:6:27043 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at HTMLAnchorElement.ot.event.dispatch (http://mythic-forge.com/game/1395906357324/script/main.js:2:17579 <http://mythic-forge.com/game/1395906357324/script/main.js> ) 
  - disparition du message d'info d�ploiement
  - suicide du missile launcher > mauvais d�compte des actions
  - d�placement apply already in progress
  - tir d�comptabilis� sur cible mouvante: pas d'affichage dans l'historique
  - flood 'no document found' dans le chat
  - d�ploiement blip: parfois a 0 (ork)
  - reconnection au niveau Atlas/dev

# TODO
  - cannon d'assaut pas clair a utiliser
  - indication replay en cours, fin du replay en cas de nouveau tour ?
  - zone pas assez visible sur les diagonales, pas toujours mise � jour
  - zoom recharge tout (ou zoom non bloquant, ou zoom pas sur la molette, pas de disparition des tooltips)
  - changement de la navigation sur la carte: drag'n drop plut�t que haptic
  - remplacer les zones deployables par une ouverture de porte
  - missions
  - image commandant du chaos
  - miniature commandant du chaos
  - action d�placement par d�faut
  - action sur le clavier (raccourcis)
  - status d'activit� des autres joueur ?
  - afficher les jets de des ou probabilit� de r�ussite du jet
  - explication des armes
  - explication commandes
  - explication du d�ploiement/de la sortie des marines
  - message d'erreur connection
  - position partag�e et plus de possibilit� de d�placement

# TODO plus tard
  - �quipements
  - ordres
  - �v�nements
  - campagne et �volution
  - classement
  - path finding
  - animations (d�placement, tir, corps � corps, mort)