#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <kztimer>

Database gH_SQL;
float gF_coords[64][3];
float gF_angles[64][3];
char gS_Map[64];

public Plugin myinfo = 
{
    name = "LJ Room Teleport",
    author = "Evan", 
    description = "Teleport to LJ room",
    version = "1.0",
    url = "imkservers.com"
}

public void OnPluginStart()
{
    RegAdminCmd("sm_setlj", Command_SetLJ, ADMFLAG_GENERIC, "Set the teleport for the LJ room");
    RegAdminCmd("sm_deletelj", Command_DeleteLJ, ADMFLAG_GENERIC, "Delete the teleport for the LJ room");
    RegConsoleCmd("sm_lj", Command_LJ, "Teleports to LJ room");

    SQL_DBConnect();
}

public void OnMapStart()
{
    GetCurrentMap(gS_Map, sizeof(gS_Map));
}

public Action Command_SetLJ(int client, int args)
{
    char sQuery[512]; 
    
    FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM `ljroom` WHERE map = '%s';", gS_Map);
    gH_SQL.Query(SQL_CreateLJ_Callback, sQuery, GetClientSerial(client));  
}

public Action Command_DeleteLJ(int client, int args)
{
    char sQuery[512];
    FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `ljroom` WHERE map = '%s';", gS_Map);
    gH_SQL.Query(SQL_DeleteLJ_Callback, sQuery, GetClientSerial(client));
}

public Action Command_LJ(int client, int args)
{
    char sQuery[512];
    FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM `ljroom` WHERE map = '%s';", gS_Map);
    gH_SQL.Query(SQL_GetLJ_Callback, sQuery, GetClientSerial(client));  
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Table could not be created. Reason: %s", error);

		return;
	}
}

public void SQL_CreateLJ_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientFromSerial(data);
    if((results == null || results.RowCount > 0) && IsValidClient(client))
	{
		PrintToChat(client, "LJ teleport already exists. Delete the existing one before creating a new one.");

		return;
	}
    
    char sQuery[512];
    float origin[3];
    float angle[3];
    
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
    GetClientEyeAngles(client, angle);
    gF_coords[client][0] = origin[0];
    gF_coords[client][1] = origin[1];
    gF_coords[client][2] = origin[2];
    gF_angles[client][0] = angle[0];
    gF_angles[client][1] = angle[1];
    
    FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `ljroom` VALUES('%s', %.2f, %.2f, %.2f, %.2f, %.2f);", gS_Map, origin[0], origin[1], origin[2], angle[0], angle[1]);
    gH_SQL.Query(SQL_CreateLJ2_Callback, sQuery, GetClientSerial(client)); 
}

public void SQL_CreateLJ2_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientFromSerial(data);
    if(results == null)
	{
		return;
	}
    
    if(IsValidClient(client))
    {
        PrintToChat(client, "LJ teleport successfully created. ");
    }
}

public void SQL_GetLJ_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientFromSerial(data);
    if((results == null || results.RowCount == 0) && IsValidClient(client))
	{
        PrintToChat(client, "This map does not have a LJ room.");
        return;
	}

    float origin[3];
    float angle[3];
    
    while(results.FetchRow())
	{
		results.FetchString(0, gS_Map, 64);

		origin[0] = results.FetchFloat(1);
        origin[1] = results.FetchFloat(2);
        origin[2] = results.FetchFloat(3);       
        angle[0] = results.FetchFloat(4);
        angle[1] = results.FetchFloat(5);
    }
   
    if(IsValidClient(client))
    {
        KZTimer_StopTimer(client);
        TeleportEntity(client, origin, angle, NULL_VECTOR);   
    }
}

public void SQL_DeleteLJ_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientFromSerial(data);
    if(results == null)
	{
		LogError("Deletion failed. Reason: %s", error);

		return;
	}
    
    if(IsValidClient(client))
    {
        PrintToChat(client, "Successfully deleted LJ teleport.");
    }
}

void SQL_DBConnect()
{
    gH_SQL = GetTimerDatabaseHandle();
    if(gH_SQL != null)
    {
        char sQuery[512];
        
        FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ljroom`(map VARCHAR(30) NOT NULL, `x` FLOAT(8) NOT NULL, `y` FLOAT(8) NOT NULL, `z` FLOAT(8) NOT NULL, `x1` FLOAT(8) NOT NULL, `y1` FLOAT(8) NOT NULL);");
                                
        gH_SQL.Query(SQL_CreateTable_Callback, sQuery);      
    }    
}

stock Database GetTimerDatabaseHandle()
{
	Database db = null;
	char sError[255];

	if(SQL_CheckConfig("kzlj"))
	{
		if((db = SQL_Connect("kzlj", true, sError, sizeof(sError))) == null)
		{
			SetFailState("Failed to connect to database. Reason: %s", sError);
		}
	}

	return db;
}

stock bool IsValidClient(client)
{
    if(client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client))
    {    
        return true;
    }    
    
    return false;
} 
