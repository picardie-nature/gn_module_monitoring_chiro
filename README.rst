Sous-module chiro pour le module GeoNature-Monitorings
******************************************************


Sous-module permettant la saisie d'observations de chiroptères 🦇 en gîtes.




Champs spécifiques
******************

**Sites**

* Nom du site : Nom courant du site (généralement un lieu-dit, ex : Carrière de machin-chose)
* Code : un code unique et court pour le site (ex : M_8784)
* Descritpion : un texte décrivant le site
* Type : type de site, selon la nomenclature de GeoNature (TODO : a préciser)

**Visites**

Pas de champs sépcifiques, seulement les champs génériques de monitorings (dates, observateurs, commentaires, jeux de données)

**Observations**

* Statut d'observation : Présent/Absent (utiliser Absent avec le taxon Chiroptera pour indiquer un site sans chiro)
* Dénombrement : Effectif compté pour le taxon (TODO : permettre estimation min/max ?)
* Commentaire : champs libre relatif à l'observation (différent du commentaire général de la visite)
* Statut biologique : selon le nomenclature (Hibernation, reproduction...)
* Stade de vie : Adulte par défaut

Il est également possible de saisir des taxons hors-chiro (souvent : papillons, araignées, mammifères, champigons, etc.)

Attributs hybrides
******************

Les champs "hybrides" (exemple : hybrid_effectif_max_site ) sont cachés 
lors de la saisie. Ils doivent être renseignés dans la base via un trigger (pas encore implémentés),
et peuvent être affichés à l'utilisateur. Les triggers doivent mettre à jour le champs *data* (json) des tables *t_site_complements* et *t_visit_complements*

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
