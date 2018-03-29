#pragma semicolon 1

#define PLUGIN_AUTHOR "Lithium"
#define PLUGIN_VERSION "1.6.0"

#include <sourcemod>
#include <sdktools>
#include <store>
#include <smjansson>
#include <cbaseplayer>
#include <sdkhooks>
#include <cookie>

#pragma newdecls required

#define MAX_EFFECT_NAME_LENGTH 64

/*
 *	Auras have 1-5 json attributes. Format:
 *	--------------------------------------------------------
 * 	"effect":"effectname"						[REQUIRED]
 *			Name of the effect, within the specified pcf, to use.
 *  "file":"particlesname.pcf"					[OPTIONAL]
 * 			Do not include the "particles/" in this path. Only necessary with custom effects.
 *	"material":"materials/materialpath.vmt"		[OPTIONAL] 
 *			ALWAYS include "materials/" in these paths. Also looks for the corresponding .vtf file.
 *	"material2":"materials/materialpath2.vmt"	[OPTIONAL]
 *			ALWAYS include "materials/" in these paths. Also looks for the corresponding .vtf file.
 *	"model":"models/modelpath.mdl"				[OPTIONAL]
 *			ALWAYS include "models/" in this path. 
 *			Also looks for the corresponding .vvd and .dx90.vtx files.
 */
 
ConVar g_hVisibleToTeamOnly;
Cookie g_hVisibility;
int g_iVisibility[MAXPLAYERS + 1] = {1, 0};	// 0: Never show, 1: Always show, 2: Show only own aura

int g_iAuraCount;
int g_iFileCount;
int g_iMaterialCount;
int g_iModelCount;
int g_iEquippedEntityIndex[MAXPLAYERS + 1];

StringMap g_hAuraNameIndex;
ArrayList g_hAuraEffects;
ArrayList g_hParticleFiles;
ArrayList g_hMaterialFiles;
ArrayList g_hModelFiles;

public Plugin myinfo = 
{
	name = "[Store] Auras",
	author = PLUGIN_AUTHOR,
	description = "Particle effects on players for store",
	version = PLUGIN_VERSION,
	url = "https://github.com/bbennett905/store-aura/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	g_hVisibleToTeamOnly = CreateConVar("sm_aura_visible_to_team_only", "1", 
		"Restricts aura visibility to own team only");
		
	//This cookie is used so that in case some clients have bad PCs 
	//and get FPS drops from particle effects, they can disable it
	g_hVisibility = new Cookie("AuraCookie", "Enable/Disable Aura visibility", 
		CookieAccess_Protected);
		
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
	SetCookieMenuItem(OnUseCookie, 0, "Aura Visibility");
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	g_hParticleFiles = new ArrayList(PLATFORM_MAX_PATH);
	g_hAuraEffects = new ArrayList(MAX_EFFECT_NAME_LENGTH);
	g_hMaterialFiles = new ArrayList(PLATFORM_MAX_PATH);
	g_hModelFiles = new ArrayList(PLATFORM_MAX_PATH);
	g_hAuraNameIndex = new StringMap();
	
	Store_RegisterItemType("auras", OnEquip, LoadItem);
	
	RegConsoleCmd("sm_auravisibility", Command_AuraVisibility, 
		"Shows a menu aura visibility options");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("auras", OnEquip, LoadItem);
	}
}

public Action Command_AuraVisibility(int iClient, int iArgs)
{
	Menu hMenu = new Menu(Menu_AuraVisibility);
	hMenu.SetTitle("Aura Visibility");
	hMenu.AddItem("0", "None Visible");
	hMenu.AddItem("1", "All Visible");
	hMenu.AddItem("2", "Show Only Own Aura");
	hMenu.Display(iClient, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Menu_AuraVisibility(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}
		case MenuAction_Select:
		{
			char sDisplay[64], sSet[4];
			hMenu.GetItem(iParam2, sSet, sizeof(sSet), _, sDisplay, sizeof(sDisplay));
			switch (StringToInt(sSet))
			{
				case 0:
				{
					g_hVisibility.SetCookieInt(iParam1, 0);
					g_iVisibility[iParam1] = 0;
					PrintToChat(iParam1, "Auras will no longer be shown.");
				}
				case 1:
				{
					g_hVisibility.SetCookieInt(iParam1, 1);
					g_iVisibility[iParam1] = 1;
					PrintToChat(iParam1, "Auras will now always be shown.");
				}
				case 2:
				{
					g_hVisibility.SetCookieInt(iParam1, 2);
					g_iVisibility[iParam1] = 2;
					PrintToChat(iParam1, "Only your own aura will be visible to you.");
				}
			}
		}
	}
}

public void OnUseCookie(int iClient, CookieMenuAction action, any cookie, 
						char[] sBuffer, int iMaxLen)
{
	if(action == CookieMenuAction_SelectOption)
	{
		FakeClientCommand(iClient, "sm_auravisibility");
	}
}

public void OnClientCookiesCached(int iClient)
{
	g_hVisibility.SetCookieDefault(iClient, "1");
	g_iVisibility[iClient] = g_hVisibility.GetCookieInt(iClient);
}

public void OnClientPostAdminCheck(int iClient)
{
	g_iEquippedEntityIndex[iClient] = -1;
}

public void OnMapStart()
{
	for (int i = 0; i < g_iFileCount; i++)
	{
		char sBuffer[PLATFORM_MAX_PATH];
		g_hParticleFiles.GetString(i, sBuffer, sizeof(sBuffer));
		
		char sPath[PLATFORM_MAX_PATH];
		Format(sPath, sizeof(sPath), "particles/%s", sBuffer);
		AddFileToDownloadsTable(sPath);
		PrecacheGeneric(sPath, true);
		
		PrecacheParticleEffect(sBuffer);
	}
	PrecacheEffect();
	
	for (int i = 0; i < g_iMaterialCount; i++)
	{
		char sBuffer[PLATFORM_MAX_PATH];
		g_hMaterialFiles.GetString(i, sBuffer, sizeof(sBuffer));
		AddFileToDownloadsTable(sBuffer);
		
		ReplaceString(sBuffer, sizeof(sBuffer), ".vmt", ".vtf", false);
		AddFileToDownloadsTable(sBuffer);
	}
	
	for (int i = 0; i < g_iModelCount; i++)
	{
		char sBuffer[PLATFORM_MAX_PATH];
		g_hModelFiles.GetString(i, sBuffer, sizeof(sBuffer));
		AddFileToDownloadsTable(sBuffer);
		
		ReplaceString(sBuffer, sizeof(sBuffer), ".mdl", ".vvd", false);
		AddFileToDownloadsTable(sBuffer);
		
		ReplaceString(sBuffer, sizeof(sBuffer), ".vvd", ".dx90.vtx", false);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void Event_PlayerSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	CBasePlayer pClient = CBasePlayer.FromEvent(hEvent, "userid");

	//If they had one equipped but didn't die, kill it
	RemoveParticlesFromPlayer(pClient.Index);

	Store_GetEquippedItemsByType(pClient.AccountID, 
								 "auras", 
								 Store_GetClientLoadout(pClient.Index), 
								 OnGetPlayerAura,
								 pClient);
}

public void OnGetPlayerAura(int[] iItemIDs, int iCount, CBasePlayer pClient)
{	
	if (iCount > 0)
	{
		for (int i = 0; i < iCount; i++)
		{
			char sBuffer[STORE_MAX_NAME_LENGTH];
			Store_GetItemName(iItemIDs[i], sBuffer, sizeof(sBuffer));
			
			int iIndex;
			g_hAuraNameIndex.GetValue(sBuffer, iIndex);
			
			char sEffect[MAX_EFFECT_NAME_LENGTH];
			g_hAuraEffects.GetString(iIndex, sEffect, sizeof(sEffect));

			g_iEquippedEntityIndex[pClient.Index] = AddParticlesToPlayer(pClient.Index, sEffect);
		}
	}
}

public void Event_PlayerDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	CBasePlayer pClient = CBasePlayer.FromEvent(hEvent, "userid");
	
	//Kill the particle system when the player dies
	RemoveParticlesFromPlayer(pClient.Index);
}

public void Store_OnReloadItems() 
{
	if (g_hAuraNameIndex != null) { delete g_hAuraNameIndex; }
	g_hAuraNameIndex = new StringMap();
	
	if (g_hAuraEffects != null) { delete g_hAuraEffects; }
	g_hAuraEffects = new ArrayList(MAX_EFFECT_NAME_LENGTH);
	
	if (g_hParticleFiles != null) { delete g_hParticleFiles; }
	g_hParticleFiles = new ArrayList(PLATFORM_MAX_PATH);
	
	if (g_hMaterialFiles != null) { delete g_hMaterialFiles; }
	g_hMaterialFiles = new ArrayList(PLATFORM_MAX_PATH);
	
	g_iAuraCount = 0;
	g_iFileCount = 0;
	g_iMaterialCount = 0;
	g_iModelCount = 0;
}

public void LoadItem(const char[] sItemName, const char[] sAttrs)
{
	g_hAuraNameIndex.SetValue(sItemName, g_iAuraCount);		//item name
	
	Handle hJson = json_load(sAttrs);
	if (hJson == null)
	{
		LogError("%s Error loading item attributes - '%s'", STORE_PREFIX, sItemName);
		return;
	}
	
	char sInfo[PLATFORM_MAX_PATH];
	int ret = json_object_get_string(hJson, "effect", sInfo, sizeof(sInfo));
	if (ret == -1 || strlen(sInfo) == 0)
	{
		LogError("%s Required attribute 'effect' not found! - '%s'", STORE_PREFIX, sItemName);
		delete hJson;
		return;
	}
	g_hAuraEffects.PushString(sInfo);						//effect name
	g_iAuraCount++;
	
	Handle hIt = json_object_iter(hJson);
	while (hIt != INVALID_HANDLE)
	{
		char sKey[128];
		json_object_iter_key(hIt, sKey, sizeof(sKey));
	
		Handle hVal = json_object_iter_value(hIt);
		
		if (StrEqual(sKey, "file"))
		{
			if (!json_is_string(hVal))
			{
				LogError("JSON Error: 'file' attr was not a string!"); 
			}
			else
			{
				json_string_value(hVal, sInfo, sizeof(sInfo));
				if (strlen(sInfo) != 0)
				{
					if (g_hParticleFiles.FindString(sInfo) == -1)
					{
						g_hParticleFiles.PushString(sInfo);					//file name
						g_iFileCount++;
					}
				}
			}
		} 
		else if (StrEqual(sKey, "material"))
		{
			if (!json_is_string(hVal))
			{
				LogError("JSON Error: 'material' attr was not a string!"); 
			}
			else
			{
				json_string_value(hVal, sInfo, sizeof(sInfo));
				if (strlen(sInfo) != 0)
				{
					if (g_hMaterialFiles.FindString(sInfo) == -1)
					{
						g_hMaterialFiles.PushString(sInfo);				//file name
						g_iMaterialCount++;
					}
				}
			}
		}
		else if (StrEqual(sKey, "material2"))
		{
			if (!json_is_string(hVal))
			{
				LogError("JSON Error: 'material2' attr was not a string!"); 
			}
			else
			{
				json_string_value(hVal, sInfo, sizeof(sInfo));
				if(strlen(sInfo) != 0)
				{
					if (g_hMaterialFiles.FindString(sInfo) == -1)
					{
						g_hMaterialFiles.PushString(sInfo);				//file name
						g_iMaterialCount++;
					}
				}
			}
		}
		else if (StrEqual(sKey, "model"))
		{
			if (!json_is_string(hVal))
			{
				LogError("JSON Error: 'model' attr was not a string!"); 
			}
			else
			{
				json_string_value(hVal, sInfo, sizeof(sInfo));
				if(strlen(sInfo) != 0)
				{
					if (g_hModelFiles.FindString(sInfo) == -1)
					{
						g_hModelFiles.PushString(sInfo);				//file name
						g_iModelCount++;
					}
				}
			}
		}
		
		delete hVal;
		
		hIt = json_object_iter_next(hJson, hIt);
	}
	
	delete hJson;
}

public Store_ItemUseAction OnEquip(int iClient, int iItemId, bool bEquipped)
{
	if (!IsClientInGame(iClient))
		return Store_DoNothing;
	
	char sItemName[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(iItemId, sItemName, sizeof(sItemName));
	
	if (!bEquipped)	//equipping
	{
		if (IsPlayerAlive(iClient))
		{
			RemoveParticlesFromPlayer(iClient);
			
			int iIndex;
			g_hAuraNameIndex.GetValue(sItemName, iIndex);
			
			char sBuffer[MAX_EFFECT_NAME_LENGTH];
			g_hAuraEffects.GetString(iIndex, sBuffer, sizeof(sBuffer));

			g_iEquippedEntityIndex[iClient] = AddParticlesToPlayer(iClient, sBuffer);
		}
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(iItemId, sDisplayName, sizeof(sDisplayName));
		
		PrintToChat(iClient, "%s%t", STORE_PREFIX, "Equipped item", sDisplayName);
		return Store_EquipItem;
	}
	else			//unequipping
	{
		RemoveParticlesFromPlayer(iClient);
		
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(iItemId, sDisplayName, sizeof(sDisplayName));
		PrintToChat(iClient, "%s%t", STORE_PREFIX, "Unequipped item", sDisplayName);
		return Store_UnequipItem;
	}
}

public void RemoveParticlesFromPlayer(int iClient)
{
	if (IsEntParticleSystem(g_iEquippedEntityIndex[iClient]) && 
		g_iEquippedEntityIndex[iClient] > 0) 
	{
		AcceptEntityInput(g_iEquippedEntityIndex[iClient], "Kill");
		g_iEquippedEntityIndex[iClient] = -1;
	}
}

/**
 * Checks if an entity is an info_particle_system
 *
 * @param		int iEntity			Entity Index
 *
 * @return		bool				True if it is an info_particle_system, false if not
 */
stock bool IsEntParticleSystem(int iEntity)
{
	if (IsValidEdict(iEntity))
	{
		char sBuffer[128];
		GetEdictClassname(iEntity, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "info_particle_system", false))
		{
			return true;
		}
	}
	return false;
}

/**
 * Adds an info_particle_system parented to the player
 *
 * @param		int iClient			Client index
 * @param		char[] sEffectName	Name of the particle effect to add
 *
 * @return		int					Entity index of the created particle system, -1 if failed.
 */
public int AddParticlesToPlayer(int iClient, const char[] sEffectName)
{
	int iEntity = CreateEntityByName("info_particle_system");
	if (IsValidEdict(iEntity) && (iClient > 0))
	{
		if (IsPlayerAlive(iClient))
		{
			float vPos[3];
			GetClientAbsOrigin(iClient, vPos);
			TeleportEntity(iEntity, vPos, NULL_VECTOR, NULL_VECTOR);
			
			DispatchKeyValue(iEntity, "effect_name", sEffectName);
			SetVariantString("!activator");
			AcceptEntityInput(iEntity, "SetParent", iClient, iEntity, 0);
			DispatchSpawn(iEntity);
			ActivateEntity(iEntity);
			AcceptEntityInput(iEntity, "Start");

			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iClient);
			SetFlags(iEntity);
			SDKHook(iEntity, SDKHook_SetTransmit, OnSetTransmit);
		}
	}
	return iEntity;
}

public void SetFlags(int iEdict) 
{ 
    if (GetEdictFlags(iEdict) & FL_EDICT_ALWAYS) 
    { 
        SetEdictFlags(iEdict, (GetEdictFlags(iEdict) ^ FL_EDICT_ALWAYS)); 
    } 
} 

public Action OnSetTransmit(int iEnt, int iClient)
{
	CBasePlayer pOwner = CBasePlayer(CEntity.FromIndex(iEnt).Owner.Index);
	SetFlags(iEnt);
	if (!pOwner.IsNull && pOwner.InGame)
	{
		if (g_iVisibility[iClient] == 0) return Plugin_Stop;
		if (g_iVisibility[iClient] == 2 && pOwner.Index != iClient) return Plugin_Stop;
		if (g_hVisibleToTeamOnly.IntValue == 0) return Plugin_Continue;

		int iTeam = CBasePlayer(iClient).Team;
		//Spec should be same for CS and TF2
		if (iTeam == CS_TEAM_SPECTATOR || iTeam == pOwner.Team) return Plugin_Continue;

		return Plugin_Stop;
	}
	return Plugin_Stop;
}

/**
 * Precaches the ParticleEffect
 *
 * @noreturn
 */
stock void PrecacheEffect()
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("EffectDispatch");
	}
	
	bool save = LockStringTables(false);
	AddToStringTable(table, "ParticleEffect");
	LockStringTables(save);
}

/**
 * Precaches a pcf file
 *
 * @param		char[] sEffectName	Name of the file
 *
 * @noreturn
 */
stock void PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("ParticleEffectNames");
	}
	
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}
