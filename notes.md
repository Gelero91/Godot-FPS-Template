DONE :

- CSGmesh permet de créer des volumes et les tailler, il faut les "bake" pour pouvoir les utiliser comme mesh.
- les escaliers en grid map ont été tricky. J'ai essayé différentes techniques de détection à base de raycast pour les terrains irréguliers (escaliers) comme unreal. Sans succès - à réitéré. Les caractéristiques du joueur sont à revoir.
pour l'escalier en gridmap, il faut bake le CSG Collision Mesh de l'escalier avec une rampe pour contourner les problèmes inhérentes à la gridmap (à vérifier). Le CSG Mesh de l'escalier doit être baked sans la rampe pur ne l'avoir que comme une zone de collision.
- faire des portes ouvrables :
	J'ai suivi un tutoriel qui utilise un raycast au niveau de la caméra pour détecter les objets utilisable. Un script lui a été atttribuer pour appeler l'action de l'objet utilisable. Il est donc applicable à toutes les interactions.
	Puis, j'ai créé un mesh de porte, j'ai ajouté un point de rotation sous forme d'un simple noeud (les charnières ou "hinge" dans l'arborescence) que j'ai animé (avec deux key pour passer d'une orientation de 0 à 90 degrés, et inversement, produisant un batement de la porte pour l'ouverture et la fermeture).
	L'animation a été interpolée (les petites dents de scie à gauche des key d'animation) en "cubic".
	Un code basique gère l'intéraction avec la porte et le lancement de l'animation.
- raffiner script du joueur pour le rendre plus agréable à l'exploration (nervosité, ralentissement, inertie, spint) : encore du code généré en placeholder, mais très agréable à utiliser.
- une arme à la première personne :
	- Trick as hell : création de l'arme, animation, de la 3DArea (pour collisions), group (création de "enemy")
	- script pour animation "idle" (malgré "play animation on load)
	- script pour l'animation d'attaque
	- utilisation de "easing" pour fluidifier les animations
	- hitbox (Area3D) de l'arme (attaché à au mesh de l'arme')
	- hitbox (Area3D - group "enemy") de l'enemi
	- script pour détecter que les hitbox se touchent => message dans la console
- système d'arme fps : https://youtu.be/3-SDNBCZA7M?si=hI-CaYV6y930Za4g
TO DO :

- peut-on créer des portes dans les meshlib ? ou il faut les poser manuellement ? Même question pour les objets utilisables.

- vie/attaque
- des ennemis
- objets de soins

- creer une ambiance de chateau gothique :
	- Rendu : fog sombre, attenuation de lumière
	- fenêtre en arche
	- couloirs en arche
	- portes en bois
		- animation ?
	- des décorations ?
	- plus tard, des modèles détailles avec texture

- portes (utiliser même technique et même script):
	- doubles portes battantes
	- porte coulissante/double coulissante
