Sous-module chiro pour le module GeoNature-Monitorings
******************************************************


Sous-module permettant la saisie d'observations de chiroptères 🦇 en gîtes.

Attributs hybrides
******************

Les champs "hybrides" (exemple : hybrid_effectif_max_site ) sont cachés 
lors de la saisie. Ils doivent être renseignés dans la base via un trigger (pas encore implémentés),
et peuvent être affichés à l'utilisateur.

* *hybrid_effectif_max_site* : effectif max connu sur le site lors d'une visite (au cours des X dernières années ?)
* *hybrid_n_taxon_site* : Nombre d'espèces (chiro) connues sur le site (au cours des X dernières années ?)
* *hybrid_n_taxon* : Nombre d'espèces (chiro) observées lors de la visite
* *hybrid_effectif* : Effectif total dénombré au cours de la visite

La même logique peut être utilisée pour remplir le champs _base_site_code_ (dans notre cas, c'est pour une raison historique :
les sites étant initialement nommés par un code du type P_noIncremet (ex : P_3212).

Les triggers peuvent donc être activés ou non selon les besoins.

Performances
************

L'affichage d'un grand nombre de site (> 1000) peut provoquer des ralentissement 🐢 coté client.
La suppression de la transparence des marqueurs permet d'alléger fortement la charge du client.
Le module monitoring ne permet pas (encore ?) de personaliser les marqueurs pour chaque sous-module,
la modification doit donc se faire directement dans le code de gn_monitorings (⚠️  affecte donc tous les sous-module).
Voir ici : https://github.com/PnX-SI/gn_module_monitoring/issues/55
