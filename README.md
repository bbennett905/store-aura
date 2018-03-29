# store-auras #

A simple auras (particle effects) addon for Sourcemod [Store](https://forums.alliedmods.net/showthread.php?t=255418) plugin. Tested on Store 1.2 Final, SM 1.8.0. Anything earlier probably won't work.

For CS:GO - This plugin has been tested quite a bit, and should work well with both custom particle effects and default effects, although it's mainly intended for custom effects.

For TF2 - Has been briefly tested, but should work pretty much the same as CS:GO. Custom particle effects generally don't work in this game, so you're pretty much limited to things included with the game. Check [here](https://developer.valvesoftware.com/wiki/List_of_TF2_Particles) for a list of default TF2 particles that you should be able to use with this plugin.


## Configuration ##

### Cvars ###

* *sm_aura_visible_to_team_only* <0/1> - Determines if auras are invisible to the opposite team (default: 1)


### Commands ###

* *sm_auravisiblity* - Brings up a menu allowing a client to choose if they want to view all auras, no auras, or only their own aura. 


## Installation ##

Simply drag and drop into your */sourcemod/plugins/* folder.


### Adding Items ###

Items are added just like any other items. There are 4 attributes each item can have:

* effect - **[REQUIRED]** Name of the effect inside the .pcf file to use. *Ex: "effect":"effectname"*

* file - **[OPTIONAL]** Name of the file. Do not include *"/particles/"* in this path. Only necessary if using custom files. *Ex: "file":"particlefile.pcf"*

* material - **[OPTIONAL]** In case your particle effect uses custom materials, set this to the material used so clients can download it. ALWAYS include *"/materials/"* in this path. The .vtf file must have the same name and be in the same path as the .vmt. *Ex: "material":"materials/materialpath.vmt"*

* material2 - **[OPTIONAL]** See above. Used if a particle system has 2 custom materials. *Ex: "material2":"materials/material2path.vmt"*

* model - **[OPTIONAL]** See above. Used if a particle system requires a model. Will also look for a .vvd and .dx90.vtx file in the same path with the same name. *Ex: "model":"models/modelpath.mdl"*

## For devs ##

Building this plugin requires [CEntity and CBasePlayer methodmaps](https://bitbucket.org/LeToucan/centity). You could also easily modify it to no longer require it, if you so desire.

## Help! ##

If you have a problem with Store or Sourcemod in general, please ask someone else. If you have a problem or request directly relating to this plugin, feel free to contact me, but I might not be able to offer much help.
