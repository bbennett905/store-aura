# store-auras #

A simple auras (particle effects) addon for Sourcemod [Store](https://forums.alliedmods.net/showthread.php?t=255418) plugin.

### Cvars ###

* *sm_aura_visible_to_team_only* <0/1> - Determines if auras are invisible to the opposite team (default: 1)


### Commands ###

* *sm_auravisiblity* - Brings up a menu allowing a client to choose if they want to view all auras, no auras, or only their own aura. 


## Installation ##

Simply drag and drop into your */sourcemod/plugins/* folder.


### Adding Items ###

Items are added just like any other items. There are 4 attributes each item can have:

* file - **[REQUIRED]** Name of the file. Do not include *"/particles/"* in this path. *Ex: "file":"particlefile.pcf"*

* effect - **[REQUIRED]** Name of the effect inside the .pcf file to use. *Ex: "effect":"effectname"*

* material - **[OPTIONAL]** In case your particle effect uses custom materials, set this to the material used so clients can download it. ALWAYS include *"/materials/"* in this path. The .vtf file must have the same name and be in the same path as the .vmt. *Ex: "material":"materials/materialpath.vmt"*

* material2 - **[OPTIONAL]** See above. Used if a particle system has 2 custom materials. *Ex: "material2":"materials/material2path.vmt"*

## For devs ##

Building this plugin requires [CEntity and CCSPlayer methodmaps](https://bitbucket.org/LeToucan/centity). You could also easily modify it to no longer require it, if you so desire.


## Help! ##

If you have a problem with Store or Sourcemod in general, please ask someone else. If you have a problem or request directly relating to this plugin, message me.