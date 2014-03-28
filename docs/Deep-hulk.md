# Bugs
  - erreur inconnue:
TypeError: Cannot read property 'effects' of undefined at http://mythic-forge.com/game/1395906357324/script/main.js:11:24932 <http://mythic-forge.com/game/1395906357324/script/main.js>  at Object.r.navigate (http://mythic-forge.com/game/1395906357324/script/main.js:11:25521 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at Object.r.stopReplay (http://mythic-forge.com/game/1395906357324/script/main.js:11:24384 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at u._onStopReplay (http://mythic-forge.com/game/1395906357324/script/main.js:9:30711 <http://mythic-forge.com/game/1395906357324/script/main.js> ) 
at http://mythic-forge.com/game/1395906357324/script/main.js:6:20184 <http://mythic-forge.com/game/1395906357324/script/main.js>  at http://mythic-forge.com/game/1395906357324/script/main.js:6:27061 <http://mythic-forge.com/game/1395906357324/script/main.js>  at u.$eval (http://mythic-forge.com/game/1395906357324/script/main.js:5:17797 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at u.$apply (http://mythic-forge.com/game/1395906357324/script/main.js:5:18075 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at HTMLAnchorElement.<anonymous> (http://mythic-forge.com/game/1395906357324/script/main.js:6:27043 <http://mythic-forge.com/game/1395906357324/script/main.js> ) at HTMLAnchorElement.ot.event.dispatch (http://mythic-forge.com/game/1395906357324/script/main.js:2:17579 <http://mythic-forge.com/game/1395906357324/script/main.js> ) 
  - disparition du message d'info déploiement
  - suicide du missile launcher > mauvais décompte des actions
  - déplacement apply already in progress
  - tir décomptabilisé sur cible mouvante: pas d'affichage dans l'historique
  - flood 'no document found' dans le chat
  - déploiement blip: parfois a 0 (ork)
  - reconnection au niveau Atlas/dev

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
  - explication des armes
  - explication commandes
  - explication du déploiement/de la sortie des marines
  - message d'erreur connection
  - position partagée et plus de possibilité de déplacement

# TODO plus tard
  - équipements
  - ordres
  - événements
  - campagne et évolution
  - classement
  - path finding
  - animations (déplacement, tir, corps à corps, mort)