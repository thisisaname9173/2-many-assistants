AddCSLuaFile("autorun/client/ai_groq_client.lua")

if not SERVER then return end

AI_GROQ = AI_GROQ or {}
AI_GROQ.Config = AI_GROQ.Config or {}
AI_GROQ.ChatLog = AI_GROQ.ChatLog or {}
AI_GROQ.ErrorLog = AI_GROQ.ErrorLog or {}
AI_GROQ.PlayerCooldowns = AI_GROQ.PlayerCooldowns or {}
AI_GROQ.PlayerMemory = AI_GROQ.PlayerMemory or {}
AI_GROQ.PlayerSpawnRecords = AI_GROQ.PlayerSpawnRecords or {}
AI_GROQ.ConfigRequestTimes = AI_GROQ.ConfigRequestTimes or {}
AI_GROQ.LastRequestTime = 0
AI_GROQ.MemoryLimit = 4
AI_GROQ.MaxActionsPerResponse = 3
AI_GROQ.MaxSpawnsPerMinute = 4
AI_GROQ.MaxLiveSpawnsPerPlayer = 8

AI_GROQ.Config.Endpoints = {
	groq = "https://api.groq.com/openai/v1/chat/completions",
	openai = "https://api.openai.com/v1/chat/completions",
	openrouter = "https://openrouter.ai/api/v1/chat/completions",
	anthropic = "https://api.anthropic.com/v1/messages",
	gemini = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
	huggingface = "https://router.huggingface.co/v1/chat/completions",
	cerebras = "https://api.cerebras.ai/v1/chat/completions",
	deepseek = "https://api.deepseek.com/chat/completions",
	xai = "https://api.x.ai/v1/chat/completions"
}

AI_GROQ.Config.DefaultModels = {
	groq = "llama-3.3-70b-versatile",
	openai = "gpt-4o-mini",
	openrouter = "openai/gpt-4o-mini",
	anthropic = "claude-3-5-haiku-20241022",
	gemini = "gemini-2.0-flash",
	huggingface = "meta-llama/Llama-3.3-70B-Instruct",
	cerebras = "llama-3.3-70b",
	deepseek = "deepseek-chat",
	xai = "grok-2-latest"
}

AI_GROQ.Config.SupportedProviders = {
	groq = true,
	openai = true,
	openrouter = true,
	anthropic = true,
	gemini = true,
	huggingface = true,
	cerebras = true,
	deepseek = true,
	xai = true
}

AI_GROQ.Config.Timeout = 20

AI_GROQ.Config.SystemPrompt = [[You are a Garry's Mod assistant. Respond with strict JSON only.
Allowed actions:
- show_window: opens a popup window for the player. Fields: title, message.
- spawn_prop: spawns a valid installed prop model for the player. Fields: model, message.
- equip_item: equips a weapon registered in the server spawn menu. Fields: weapon, message.
- spawn_entity: spawns a registered scripted entity from the server spawn menu. Fields: class, message.
- spawn_npc: spawns a registered NPC from the server spawn menu. Fields: class, model, weapon, message.
- spawn_vehicle: spawns a registered vehicle from the server spawn menu. Fields: class, model, message.
- error: if you cannot comply. Fields: message.
Rules:
- Use valid installed content registered by Garry's Mod or an installed addon, and use creative freedom when choosing it.
- Check whether a spawn-menu entry is admin-only before using it. Non-admins must be refused admin-only content.
- Never return code, Lua, console commands, or instructions that would change server configuration.
- Return no more than three actions in one response. Spawn actions are subject to server-side limits and authorization checks.
- IMPORTANT: Every action MUST include a "message" field that describes what you did in a natural, creative way from the AI's perspective.
- For spawn_prop and equip_item, the message should be a chat message telling the player what you spawned or equipped (be creative and fun).
- Example messages: "Here's a chair for you!", "I equipped you with a crowbar", "Got you a nice place to sit", etc.
- For spawn_prop, use the exact model requested by the player when it is a valid installed prop.
- For equip_item, use the exact registered weapon classname requested by the player.
- Use spawn_entity, spawn_npc, and spawn_vehicle when the player asks for an entity, NPC, or vehicle instead of a prop or weapon.
- If the request is vague, pick the safest useful action.
Return JSON like {"action":"show_window","title":"Hello","message":"Hello from AI"}.
You may return multiple actions at once by supplying an "actions" array, for example:
{"actions":[{"action":"show_window","title":"Hi","message":"Check this out!"},{"action":"spawn_prop","model":"models/props_c17/FurnitureChair001a.mdl","message":"I got you a comfy chair!"}]}
When the user is simply chatting normally and not asking for a tool/action, respond with a conversational action of type "error" and a friendly message field such as "Hey! How can I help?" or "That sounds interesting.".
Do not include markdown or commentary.]]

AI_GROQ.Config.ModelBlacklist = {
	"grenade", "bomb", "explosive", "rpg", "rocket", "c4",
	"satchel", "dynamite", "frag", "napalm", "gas", "molotov", "fire"
}
AI_GROQ.Config.DefaultModelBlacklist = table.Copy(AI_GROQ.Config.ModelBlacklist)

AI_GROQ.Config.WeaponBlacklist = {
	"rpg", "rocket", "grenade", "frag", "satchel", "c4",
	"dynamite", "molotov", "nail", "explosive"
}
AI_GROQ.Config.DefaultWeaponBlacklist = table.Copy(AI_GROQ.Config.WeaponBlacklist)

CreateConVar("ai_provider", "groq", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "AI provider to use: groq | openai | openrouter | anthropic | gemini | huggingface | cerebras | deepseek | xai")
CreateConVar("ai_api_key_groq", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "Groq API key")
CreateConVar("ai_api_key_openai", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "OpenAI API key")
CreateConVar("ai_api_key_openrouter", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "OpenRouter API key")
CreateConVar("ai_api_key_anthropic", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "Anthropic API key")
CreateConVar("ai_api_key_gemini", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "Google Gemini API key")
CreateConVar("ai_api_key_huggingface", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "Hugging Face API key")
CreateConVar("ai_api_key_cerebras", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "Cerebras API key")
CreateConVar("ai_api_key_deepseek", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "DeepSeek API key")
CreateConVar("ai_api_key_xai", "", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "xAI Grok API key")
CreateConVar("ai_model", "llama-3.3-70b-versatile", bit.bor(FCVAR_ARCHIVE, FCVAR_UNLOGGED), "AI model to use for supported providers")
CreateConVar("ai_cooldown", "2", FCVAR_ARCHIVE, "Cooldown in seconds between AI requests per player")
CreateConVar("ai_request_interval", "1.5", FCVAR_ARCHIVE, "Minimum delay in seconds between outgoing API requests to prevent rate limits")
CreateConVar("ai_max_retries", "3", FCVAR_ARCHIVE, "Maximum retries when encountering HTTP 429 rate limit errors")
CreateConVar("ai_retry_delay", "2", FCVAR_ARCHIVE, "Base delay in seconds for exponential backoff on HTTP 429")
CreateConVar("ai_model_blacklist", table.concat(AI_GROQ.Config.ModelBlacklist, ","), FCVAR_ARCHIVE, "Comma-separated model patterns blocked from AI spawning")
CreateConVar("ai_weapon_blacklist", table.concat(AI_GROQ.Config.WeaponBlacklist, ","), FCVAR_ARCHIVE, "Comma-separated weapon patterns blocked from AI equipping")
CreateConVar("ai_groq_enabled", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Enable the Groq AI assistant")
CreateConVar("ai_groq_persona", "", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Optional persona instructions appended to the AI system prompt")
CreateConVar("ai_groq_lua_exec_enabled", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Deprecated; AI Lua execution is disabled")
CreateConVar("ai_groq_chat_enabled", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Enable plain chat mode for non-!ai messages")

local luaExecCVar = GetConVar("ai_groq_lua_exec_enabled")
if luaExecCVar then luaExecCVar:SetBool(false) end

util.AddNetworkString("AI_GROQ_OpenWindow")
util.AddNetworkString("AI_GROQ_OpenConfig")
util.AddNetworkString("AI_GROQ_RequestConfig")
util.AddNetworkString("AI_GROQ_UpdateConfig")

function AI_GROQ.GetPlayerCooldown(ply)
	if not IsValid(ply) then return 0 end
	local lastTime = AI_GROQ.PlayerCooldowns[ply]
	if not lastTime then return 0 end
	local cvar = GetConVar("ai_cooldown")
	local cooldown = math.max(2, cvar and cvar:GetFloat() or 2)
	local elapsed = CurTime() - lastTime
	if elapsed < cooldown then
		return cooldown - elapsed
	end
	return 0
end

function AI_GROQ.SetPlayerCooldown(ply)
	if IsValid(ply) then
		AI_GROQ.PlayerCooldowns[ply] = CurTime()
	end
end

function AI_GROQ.IsValidProvider(provider)
	if not provider or type(provider) ~= "string" then return false end
	return AI_GROQ.Config.SupportedProviders[string.lower(provider)] == true
end

function AI_GROQ.GetApiProvider()
	local cvar = GetConVar("ai_provider")
	local provider = string.lower(cvar and cvar:GetString() or "groq")
	if not AI_GROQ.IsValidProvider(provider) then
		provider = "groq"
	end
	return provider
end

function AI_GROQ.SanitizeKey(key)
	if not key or type(key) ~= "string" then return "" end
	key = string.Trim(key)
	key = string.gsub(key, '^["\']', '')
	key = string.gsub(key, '["\']$', '')
	key = string.Trim(key)
	if string.sub(string.lower(key), 1, 7) == "bearer " then
		key = string.Trim(string.sub(key, 8))
	end
	return key
end

function AI_GROQ.GetApiKey()
	local provider = AI_GROQ.GetApiProvider()
	local cvar = GetConVar("ai_api_key_" .. provider)
	local key = cvar and cvar:GetString() or ""
	return AI_GROQ.SanitizeKey(key), provider
end

function AI_GROQ.GetDefaultModel(provider)
	provider = string.lower(tostring(provider or AI_GROQ.GetApiProvider()))
	return AI_GROQ.Config.DefaultModels[provider] or "llama-3.3-70b-versatile"
end

function AI_GROQ.GetModel(provider)
	provider = string.lower(tostring(provider or AI_GROQ.GetApiProvider()))
	local cvar = GetConVar("ai_model")
	local model = string.Trim(cvar and cvar:GetString() or "")
	if model == "" then
		return AI_GROQ.GetDefaultModel(provider)
	end
	for otherProvider, defaultModel in pairs(AI_GROQ.Config.DefaultModels) do
		if otherProvider ~= provider and model == defaultModel then
			return AI_GROQ.GetDefaultModel(provider)
		end
	end

	return model
end

function AI_GROQ.GetProviderEndpoint(provider)
	provider = string.lower(tostring(provider or "groq"))
	return AI_GROQ.Config.Endpoints[provider] or AI_GROQ.Config.Endpoints.groq
end

function AI_GROQ.GetProviderHeaders(provider, key)
	key = AI_GROQ.SanitizeKey(key)
	if provider == "anthropic" then
		return {
			["x-api-key"] = key,
			["anthropic-version"] = "2023-06-01",
			["Content-Type"] = "application/json",
			["Accept"] = "application/json"
		}
	end
	if provider == "openrouter" then
		return {
			["Authorization"] = "Bearer " .. key,
			["Content-Type"] = "application/json",
			["HTTP-Referer"] = "https://garrysmod.com",
			["X-Title"] = "GMod AI Assistant",
			["Accept"] = "application/json"
		}
	end
	return {
		["Authorization"] = "Bearer " .. key,
		["Content-Type"] = "application/json",
		["Accept"] = "application/json"
	}
end

function AI_GROQ.IsEnabled()
	local cvar = GetConVar("ai_groq_enabled")
	return cvar and cvar:GetBool() or false
end

function AI_GROQ.IsChatModeEnabled()
	local cvar = GetConVar("ai_groq_chat_enabled")
	return cvar and cvar:GetBool() or false
end

function AI_GROQ.IsULXAdmin(ply)
	if not IsValid(ply) then return false end
	return ply:IsAdmin() or ply:IsSuperAdmin()
end

function AI_GROQ.GetPlayerRankContext(ply)
	if not IsValid(ply) then
		return "- Player rank: Console/Unknown"
	end

	local rankLines = {}
	local userGroup = ply:GetUserGroup() or "user"
	table.insert(rankLines, "- Player rank: " .. userGroup)
	table.insert(rankLines, "- IsAdmin: " .. tostring(ply:IsAdmin()))
	table.insert(rankLines, "- IsSuperAdmin: " .. tostring(ply:IsSuperAdmin()))

	if ulx and type(ulx.getUserGroup) == "function" then
		local ulxGroup = ulx.getUserGroup(ply) or "unknown"
		table.insert(rankLines, "- ULX group: " .. ulxGroup)
	end

	if ULib and ULib.ucl and ULib.ucl.query then
		local ulxFlags = {}
		for _, flag in ipairs({"ulx access", "ulx admin", "ulx menu", "ulx kick", "ulx ban", "ulx adduser"}) do
			if ULib.ucl.query(ply, flag) then
				table.insert(ulxFlags, flag)
			end
		end
		if #ulxFlags > 0 then
			table.insert(rankLines, "- ULX flags: " .. table.concat(ulxFlags, ", "))
		end
	end

	return table.concat(rankLines, "\n")
end

function AI_GROQ.ClearChatLog()
	AI_GROQ.ChatLog = {}
end

function AI_GROQ.SafeText(value, maxLength)
	local text = tostring(value or "")
	text = string.gsub(text, "[%c]", " ")
	text = string.Trim(text)
	if #text > maxLength then
		text = string.sub(text, 1, maxLength)
	end
	return text
end

function AI_GROQ.AppendChatLog(ply, text, mode)
	AI_GROQ.ChatLog[#AI_GROQ.ChatLog + 1] = {
		time = RealTime(),
		player = AI_GROQ.SafeText(IsValid(ply) and ply:Nick() or "Console", 64),
		mode = mode or "chat",
		text = AI_GROQ.SafeText(text, 1000)
	}
	if #AI_GROQ.ChatLog > 200 then
		table.remove(AI_GROQ.ChatLog, 1)
	end
end

function AI_GROQ.PrintChatLog(ply)
	local maxLines = 100
	for i = math.max(1, #AI_GROQ.ChatLog - maxLines + 1), #AI_GROQ.ChatLog do
		local entry = AI_GROQ.ChatLog[i]
		local line = string.format("[%0.2f] %s (%s): %s", entry.time, entry.player, entry.mode, entry.text)
		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, line)
		else
			print(line)
		end
	end
end

function AI_GROQ.GetPlayerMemory(ply)
	if not IsValid(ply) then return {} end
	AI_GROQ.PlayerMemory[ply] = AI_GROQ.PlayerMemory[ply] or {}
	return AI_GROQ.PlayerMemory[ply]
end

function AI_GROQ.AddPlayerMemory(ply, userText, aiReply)
	if not IsValid(ply) then return end
	local memory = AI_GROQ.GetPlayerMemory(ply)
	memory[#memory + 1] = {
		user = AI_GROQ.SafeText(userText, 1000),
		ai = AI_GROQ.SafeText(aiReply, 1000)
	}
	if #memory > (AI_GROQ.MemoryLimit or 4) then
		table.remove(memory, 1)
	end
end

function AI_GROQ.BuildMemoryContext(ply)
	if not IsValid(ply) then return "" end
	local memory = AI_GROQ.GetPlayerMemory(ply)
	if not memory or #memory == 0 then return "" end
	local lines = {"Recent chat memory:"}
	for i = 1, #memory do
		local entry = memory[i]
		if entry and entry.user and entry.user ~= "" then
			lines[#lines + 1] = "- You: " .. string.Trim(entry.user)
		end
		if entry and entry.ai and entry.ai ~= "" then
			lines[#lines + 1] = "  AI: " .. string.Trim(entry.ai)
		end
	end
	return table.concat(lines, "\n")
end

function AI_GROQ.LogError(source, msg)
	AI_GROQ.ErrorLog[#AI_GROQ.ErrorLog + 1] = {
		time = RealTime(),
		source = AI_GROQ.SafeText(source or "unknown", 64),
		message = AI_GROQ.SafeText(msg, 2000),
		trace = debug.traceback("", 2)
	}
	if #AI_GROQ.ErrorLog > 200 then
		table.remove(AI_GROQ.ErrorLog, 1)
	end
end

function AI_GROQ.PrintErrorLog(ply)
	local maxLines = 100
	for i = math.max(1, #AI_GROQ.ErrorLog - maxLines + 1), #AI_GROQ.ErrorLog do
		local entry = AI_GROQ.ErrorLog[i]
		local line = string.format("[%0.2f] %s: %s", entry.time, entry.source, entry.message)
		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, line)
		else
			print(line)
		end
	end
end

function AI_GROQ.ClearErrorLog()
	AI_GROQ.ErrorLog = {}
end

function AI_GROQ.GetSpawnMenuContext()
	local lines = {"Registered spawn-menu content:"}
	local catalogs = {
		{"SpawnableEntities", "entities", "class"},
		{"NPC", "NPCs", "class"},
		{"Vehicles", "vehicles", "class"},
		{"Weapon", "weapons", "class"}
	}
	for _, catalog in ipairs(catalogs) do
		local entries = list.Get(catalog[1]) or {}
		local names = {}
		for key, entry in pairs(entries) do
			local name = type(entry) == "table" and (entry.Class or entry.class or key) or key
			names[#names + 1] = tostring(name)
		end
		table.sort(names)
		local shown = {}
		for index = 1, math.min(100, #names) do
			shown[#shown + 1] = names[index]
		end
		lines[#lines + 1] = string.format("- %s: %d registered; available classnames include: %s", catalog[2], #names, #shown > 0 and table.concat(shown, ", ") or "none")
	end
	lines[#lines + 1] = "- Props: any installed model accepted by util.IsValidProp, including addon-added models."
	lines[#lines + 1] = "- Use the exact classname from the relevant catalog for spawn_entity, spawn_npc, spawn_vehicle, or equip_item."
	return table.concat(lines, "\n")
end

function AI_GROQ.GetServerContext()
	local hostname = GetConVarString("hostname") or "Unknown Server"
	local mapname = game.GetMap() or "unknown"
	local gamemode = engine.ActiveGamemode() or "unknown"
	local maxPlayers = GetConVarString("sv_maxplayers") or "unknown"
	local playerCount = player.GetCount()
	local hasULX = false
	local ulxDescription = ""

	if ulx then
		hasULX = true
		if type(ulx.description) == "string" and ulx.description ~= "" then
			ulxDescription = ulx.description
		elseif type(ulx.version) == "string" and ulx.version ~= "" then
			ulxDescription = "ULX version " .. ulx.version
		end
	elseif ULib then
		hasULX = true
		if type(ULib.plugin) == "table" then
			ulxDescription = "ULX/ULib present"
		end
	end

	local addons = engine.GetAddons() or {}
	local mountedAddons = {}
	for _, addon in ipairs(addons) do
		if addon.mounted then
			mountedAddons[#mountedAddons + 1] = string.format("%s (%s)", addon.title or "unknown", addon.wsid or "local")
		end
	end

	local context = {
		"Server context:",
		"- Hostname: " .. hostname,
		"- Map: " .. mapname,
		"- Gamemode: " .. gamemode,
		"- Players: " .. tostring(playerCount) .. " / " .. tostring(maxPlayers),
		"- ULX installed: " .. tostring(hasULX),
	}

	if ulxDescription ~= "" then
		context[#context + 1] = "- ULX description: " .. ulxDescription
	end

	context[#context + 1] = "- Mounted addons count: " .. tostring(#mountedAddons)

	if #mountedAddons > 0 then
		local maxDisplay = 30
		local displayList = {}
		for i = 1, math.min(maxDisplay, #mountedAddons) do
			displayList[#displayList + 1] = mountedAddons[i]
		end
		context[#context + 1] = "- Mounted addons: " .. table.concat(displayList, ", ")
		if #mountedAddons > maxDisplay then
			context[#context + 1] = "- Plus " .. tostring(#mountedAddons - maxDisplay) .. " more mounted addons not listed."
		end
	end

	context[#context + 1] = "Do not include any player names, Steam IDs, or personal identifiers."
	context[#context + 1] = "Use this server context to answer questions about available server content, mods, and items."
	context[#context + 1] = AI_GROQ.GetSpawnMenuContext()

	return table.concat(context, "\n")
end

function AI_GROQ.BuildSystemPrompt(ply)
	local base = AI_GROQ.Config.SystemPrompt or ""
	local cvar = GetConVar("ai_groq_persona")
	local persona = AI_GROQ.SafeText(cvar and cvar:GetString() or "", 1000)
	local context = AI_GROQ.GetServerContext()
	if IsValid(ply) then
		context = context .. "\n\nRequester context:\n" .. AI_GROQ.GetPlayerRankContext(ply)
		local isAdmin = AI_GROQ.IsULXAdmin(ply)
		context = context .. "\n- Requester is admin: " .. tostring(isAdmin)
		if not isAdmin then
			context = context .. "\n- NOTE: This is a non-admin player. Refuse admin-only registry entries and any active blacklist matches, but otherwise use any registered weapon available in the catalog."
		else
			context = context .. "\n- This player has admin access."
		end
	end
	local prompt = base .. "\n\n" .. context
	if persona == "" then
		return prompt
	end
	return prompt .. "\n\nAdditional persona instructions:\n" .. persona
end

function AI_GROQ.IsAllowedAction(ply, action)
	if not IsValid(ply) then return false end
	if action == "show_window" then return true end
	if action == "spawn_prop" or action == "spawn_entity" or action == "spawn_npc" or action == "spawn_vehicle" or action == "equip_item" then
		return true
	end
	return false
end

function AI_GROQ.GetSpawnRecordsKey(ply)
	local key = ply:SteamID64()
	if not key or key == "" then key = ply:SteamID() end
	return key
end

function AI_GROQ.CanSpawnForPlayer(ply)
	if not IsValid(ply) then return false, "A player is required to spawn content." end
	local now = CurTime()
	local recordsKey = AI_GROQ.GetSpawnRecordsKey(ply)
	local records = AI_GROQ.PlayerSpawnRecords[recordsKey] or {times = {}, entities = {}}
	AI_GROQ.PlayerSpawnRecords[recordsKey] = records

	for index = #records.times, 1, -1 do
		if now - records.times[index] >= 60 then
			table.remove(records.times, index)
		end
	end
	for index = #records.entities, 1, -1 do
		if not IsValid(records.entities[index]) then
			table.remove(records.entities, index)
		end
	end

	if #records.times >= AI_GROQ.MaxSpawnsPerMinute then
		return false, "You have reached the AI spawn rate limit. Please wait a minute."
	end
	if #records.entities >= AI_GROQ.MaxLiveSpawnsPerPlayer then
		return false, "You have reached the AI live-entity limit. Remove an AI-spawned item first."
	end
	return true
end

function AI_GROQ.RecordSpawn(ply, ent)
	local recordsKey = AI_GROQ.GetSpawnRecordsKey(ply)
	local records = AI_GROQ.PlayerSpawnRecords[recordsKey]
	if not records then
		records = {times = {}, entities = {}}
		AI_GROQ.PlayerSpawnRecords[recordsKey] = records
	end
	records.times[#records.times + 1] = CurTime()
	records.entities[#records.entities + 1] = ent
end

timer.Create("AI_GROQ_PruneSpawnRecords", 60, 0, function()
	local now = CurTime()
	for key, records in pairs(AI_GROQ.PlayerSpawnRecords) do
		for index = #records.times, 1, -1 do
			if now - records.times[index] >= 60 then
				table.remove(records.times, index)
			end
		end
		for index = #records.entities, 1, -1 do
			if not IsValid(records.entities[index]) then
				table.remove(records.entities, index)
			end
		end
		if #records.times == 0 and #records.entities == 0 then
			AI_GROQ.PlayerSpawnRecords[key] = nil
		end
	end
end)

function AI_GROQ.FindSpawnEntry(listName, requestedName)
	if not requestedName or requestedName == "" then return nil, nil end
	local wanted = string.lower(string.Trim(tostring(requestedName)))
	local entries = list.Get(listName) or {}
	for key, entry in pairs(entries) do
		local className = type(entry) == "table" and (entry.Class or entry.class or key) or key
		if string.lower(tostring(key)) == wanted or string.lower(tostring(className)) == wanted then
			return entry, tostring(className)
		end
	end
	return nil, nil
end

function AI_GROQ.IsSpawnEntryAllowed(ply, entry)
	if type(entry) ~= "table" then return false end
	if entry.AdminOnly or entry.adminOnly or entry.adminonly or entry.Admin or entry.admin then
		return AI_GROQ.IsULXAdmin(ply)
	end
	return true
end

function AI_GROQ.IsApprovedModel(model)
	if not model or model == "" then return false end
	local normalized = string.lower(string.Trim(model))
	if not string.match(normalized, "^models/.+%.mdl$") then return false end
	if string.find(normalized, "..", 1, true) then return false end
	if not util.IsValidModel(model) or not util.IsValidProp(model) then return false end
	for _, bad in ipairs(AI_GROQ.Config.ModelBlacklist) do
		if string.find(normalized, bad, 1, true) then
			return false
		end
	end
	return true
end

function AI_GROQ.GetBlacklist(kind)
	return kind == "model" and AI_GROQ.Config.ModelBlacklist or AI_GROQ.Config.WeaponBlacklist
end

function AI_GROQ.SetBlacklistCVar(kind)
	local values = AI_GROQ.GetBlacklist(kind)
	local cvar = GetConVar(kind == "model" and "ai_model_blacklist" or "ai_weapon_blacklist")
	if cvar then
		cvar:SetString(table.concat(values, ","))
	end
end

function AI_GROQ.RemoveBlacklistPattern(kind, pattern)
	local values = AI_GROQ.GetBlacklist(kind)
	local wanted = string.lower(string.Trim(pattern or ""))
	if wanted == "" then return false end
	for index = #values, 1, -1 do
		if string.lower(values[index]) == wanted then
			table.remove(values, index)
			AI_GROQ.SetBlacklistCVar(kind)
			return true
		end
	end
	return false
end

function AI_GROQ.AddBlacklistPattern(kind, pattern)
	local value = string.lower(string.Trim(pattern or ""))
	if value == "" then return false end
	local values = AI_GROQ.GetBlacklist(kind)
	for _, existing in ipairs(values) do
		if string.lower(existing) == value then return false end
	end
	values[#values + 1] = value
	AI_GROQ.SetBlacklistCVar(kind)
	return true
end

function AI_GROQ.LoadBlacklists()
	local definitions = {
		{kind = "model", cvar = "ai_model_blacklist", target = AI_GROQ.Config.ModelBlacklist},
		{kind = "weapon", cvar = "ai_weapon_blacklist", target = AI_GROQ.Config.WeaponBlacklist}
	}
	for _, definition in ipairs(definitions) do
		local cvar = GetConVar(definition.cvar)
		local stored = cvar and string.Trim(cvar:GetString()) or ""
		if stored ~= "" then
			definition.target = {}
			for _, value in ipairs(string.Explode(",", stored)) do
				local pattern = string.lower(string.Trim(value))
				if pattern ~= "" then definition.target[#definition.target + 1] = pattern end
			end
			if definition.kind == "model" then
				AI_GROQ.Config.ModelBlacklist = definition.target
			else
				AI_GROQ.Config.WeaponBlacklist = definition.target
			end
		elseif stored == "" then
			if definition.kind == "model" then AI_GROQ.Config.ModelBlacklist = {} end
			if definition.kind == "weapon" then AI_GROQ.Config.WeaponBlacklist = {} end
		end
	end
end

AI_GROQ.LoadBlacklists()

function AI_GROQ.GetWeaponEntry(weaponName)
	return AI_GROQ.FindSpawnEntry("Weapon", weaponName)
end

function AI_GROQ.IsApprovedWeapon(ply, weaponName)
	if not weaponName or weaponName == "" then return false, "No weapon was supplied." end
	local normalized = string.lower(string.Trim(weaponName))
	for _, bad in ipairs(AI_GROQ.Config.WeaponBlacklist) do
		if string.find(normalized, bad, 1, true) then
			if not AI_GROQ.IsULXAdmin(ply) then
				return false, "That weapon is restricted to admins."
			end
			break
		end
	end
	local entry, className = AI_GROQ.GetWeaponEntry(normalized)
	if not entry or not className then
		return false, "That weapon is not registered by the server."
	end
	if not AI_GROQ.IsSpawnEntryAllowed(ply, entry) then
		return false, "That weapon is admin-only."
	end
	return true, nil
end

function AI_GROQ.GetSpawnPosition(ply)
	local trace = ply:GetEyeTrace()
	if not trace or not isvector(trace.HitPos) then return nil end
	local position = trace.HitPos + Vector(0, 0, 20)
	if not util.IsInWorld(position) or position:DistToSqr(ply:GetPos()) > 1000000 then
		return nil
	end
	return position
end

function AI_GROQ.ApplyEntryKeyValues(ent, entry)
	if type(entry) ~= "table" or type(entry.KeyValues) ~= "table" then return end
	for key, value in pairs(entry.KeyValues) do
		ent:SetKeyValue(tostring(key), tostring(value))
	end
end

function AI_GROQ.NormalizeContent(content)
	if type(content) ~= "string" then return "" end
	content = string.Trim(content)

	local jsonBlock = string.match(content, "```json%s*(.-)%s*```")
	if not jsonBlock then
		jsonBlock = string.match(content, "```%s*(.-)%s*```")
	end
	if jsonBlock then
		return string.Trim(jsonBlock)
	end

	content = string.gsub(content, "^```json%s*", "")
	content = string.gsub(content, "^```%s*", "")
	content = string.gsub(content, "%s*```$", "")
	return string.Trim(content)
end

function AI_GROQ.ExecuteActions(ply, actions)
	if not actions then return end
	if type(actions) == "table" then
		if actions.action then
			AI_GROQ.ExecuteAction(ply, string.lower(tostring(actions.action or "error")), actions)
			return
		end

		local count = 0
		for _, act in ipairs(actions) do
			count = count + 1
			if count > AI_GROQ.MaxActionsPerResponse then
				if IsValid(ply) then ply:ChatPrint("The AI response contained too many actions; extras were ignored.") end
				break
			end
			if type(act) == "table" then
				local name = string.lower(tostring(act.action or "error"))
				AI_GROQ.ExecuteAction(ply, name, act)
			end
		end
	else
		AI_GROQ.LogError("AI", "Ignored actions payload with invalid type.")
	end
end

function AI_GROQ.ExecuteAction(ply, action, data)
	if type(data) ~= "table" then
		AI_GROQ.LogError("AI", "Ignored action with invalid payload type.")
		return
	end
	if not AI_GROQ.IsAllowedAction(ply, action) then
		if IsValid(ply) then ply:ChatPrint("That AI action is disabled or not permitted.") end
		return
	end

	if action == "show_window" then
		local title = AI_GROQ.SafeText(data.title or "AI Message", 64)
		local message = AI_GROQ.SafeText(data.message or "The AI requested a window.", 512)
		if IsValid(ply) then
			net.Start("AI_GROQ_OpenWindow")
				net.WriteString(title)
				net.WriteString(message)
			net.Send(ply)
			ply:ChatPrint("Opened a window for you.")
		else
			print("[AI Window] " .. title .. ": " .. message)
		end
		return
	end

	if action == "spawn_prop" then
		local model = AI_GROQ.SafeText(data.model, 160)
		if not AI_GROQ.IsApprovedModel(model) then
			if IsValid(ply) then
				ply:ChatPrint("That prop model is unavailable, invalid, or matches the active model blacklist.")
			else
				print("That prop model is not approved for spawn.")
			end
			return
		end

		if not IsValid(ply) then
			print("Cannot spawn prop without player context.")
			return
		end
		local spawnAllowed, spawnReason = AI_GROQ.CanSpawnForPlayer(ply)
		if not spawnAllowed then ply:ChatPrint(spawnReason) return end

		local ent = ents.Create("prop_physics")
		if not IsValid(ent) then
			ply:ChatPrint("Could not create the prop entity.")
			return
		end

		local pos = AI_GROQ.GetSpawnPosition(ply)
		if not pos then
			ent:Remove()
			ply:ChatPrint("That location is not safe for spawning.")
			return
		end
		ent:SetModel(model)
		ent:SetPos(pos)
		ent:SetAngles(Angle(0, math.random(0, 360), 0))
		ent:Spawn()
		ent:Activate()
		if hook.Run("PlayerSpawnedProp", ply, model, ent) == false then
			ent:Remove()
			ply:ChatPrint("The server blocked that prop.")
			return
		end
		AI_GROQ.RecordSpawn(ply, ent)
		local msg = AI_GROQ.SafeText(data.message or "Spawned a prop for you.", 180)
		ply:ChatPrint(msg)
		return
	end

	if action == "equip_item" then
		local weaponName = AI_GROQ.SafeText(data.weapon, 96)
		local weaponAllowed, weaponReason = AI_GROQ.IsApprovedWeapon(ply, weaponName)
		if not weaponAllowed then
			if IsValid(ply) then ply:ChatPrint(weaponReason or "That weapon is not approved for AI equip.") else print(weaponReason or "That weapon is not approved for AI equip.") end
			return
		end

		if not IsValid(ply) or not ply:Alive() then
			if IsValid(ply) then
				ply:ChatPrint("You need to be alive before equipping something.")
			else
				print("Cannot equip weapon without alive player.")
			end
			return
		end

		if ply:HasWeapon(weaponName) then
			ply:ChatPrint("You already have that weapon.")
			return
		end
		ply:Give(weaponName)
		ply:SelectWeapon(weaponName)
		local msg = AI_GROQ.SafeText(data.message or "Equipped the requested item.", 180)
		ply:ChatPrint(msg)
		return
	end

	if action == "spawn_entity" or action == "spawn_npc" or action == "spawn_vehicle" then
		if not IsValid(ply) then return end
		local registryName = action == "spawn_entity" and "SpawnableEntities" or action == "spawn_npc" and "NPC" or "Vehicles"
		local requestedClass = AI_GROQ.SafeText(data.class or data.entity or data.npc or data.vehicle, 96)
		local entry, className = AI_GROQ.FindSpawnEntry(registryName, requestedClass)
		if not entry or not className or not AI_GROQ.IsSpawnEntryAllowed(ply, entry) then
			ply:ChatPrint("That spawn-menu item is unavailable or admin-only.")
			return
		end
		local spawnAllowed, spawnReason = AI_GROQ.CanSpawnForPlayer(ply)
		if not spawnAllowed then ply:ChatPrint(spawnReason) return end

		local ent = ents.Create(className)
		if not IsValid(ent) then
			ply:ChatPrint("The server could not create that spawn-menu item.")
			return
		end

		local model = AI_GROQ.SafeText(data.model, 160)
		if model ~= "" then
			if not AI_GROQ.IsApprovedModel(model) then
				ent:Remove()
				ply:ChatPrint("That model is unavailable, invalid, or matches the active model blacklist.")
				return
			end
			ent:SetModel(model)
		end
		if action == "spawn_npc" then
			local npcWeapon = AI_GROQ.SafeText(data.weapon, 96)
			if npcWeapon ~= "" then
				local allowed, reason = AI_GROQ.IsApprovedWeapon(ply, npcWeapon)
				if not allowed then
					ent:Remove()
					ply:ChatPrint(reason or "That NPC weapon is not approved.")
					return
				end
				ent:SetKeyValue("additionalequipment", npcWeapon)
			end
		end
		AI_GROQ.ApplyEntryKeyValues(ent, entry)
		local pos = AI_GROQ.GetSpawnPosition(ply)
		if not pos then
			ent:Remove()
			ply:ChatPrint("That location is not safe for spawning.")
			return
		end
		ent:SetPos(pos)
		ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		ent:Spawn()
		ent:Activate()

		local hookName = action == "spawn_npc" and "PlayerSpawnedNPC" or action == "spawn_vehicle" and "PlayerSpawnedVehicle" or "PlayerSpawnedSENT"
		if hook.Run(hookName, ply, ent) == false then
			ent:Remove()
			ply:ChatPrint("The server blocked that spawn.")
			return
		end
		AI_GROQ.RecordSpawn(ply, ent)
		ply:ChatPrint(AI_GROQ.SafeText(data.message or ("Spawned " .. className .. " for you."), 180))
		return
	end

	if action == "error" then
		local msg = AI_GROQ.SafeText(data.message or "The AI could not complete the request.", 512)
		if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
		return
	end

	AI_GROQ.LogError("Action", "Unsupported action: " .. tostring(action))
	if IsValid(ply) then
		ply:ChatPrint("The AI returned an unsupported action.")
	else
		print("The AI returned an unsupported action.")
	end
end

function AI_GROQ.SendRequest(ply, userText, mode, retryCount, queued)
	retryCount = retryCount or 0
	userText = AI_GROQ.SafeText(userText, 1000)
	if userText == "" then
		if IsValid(ply) then ply:ChatPrint("Please provide a non-empty request.") else print("Please provide a non-empty request.") end
		return
	end

	if not AI_GROQ.IsEnabled() then
		if IsValid(ply) then
			ply:ChatPrint("The AI assistant is currently disabled.")
		else
			print("The AI assistant is currently disabled.")
		end
		return
	end

	if retryCount == 0 and IsValid(ply) then
		if not queued then
			local remaining = AI_GROQ.GetPlayerCooldown(ply)
			if remaining > 0 then
				ply:ChatPrint(string.format("Please wait %.1fs before sending another AI request.", remaining))
				return
			end
			AI_GROQ.SetPlayerCooldown(ply)
		end
	end

	local key, provider = AI_GROQ.GetApiKey()
	if not key or key == "" then
		local msg = "Set ai_api_key_" .. provider .. " to your real API key before using the AI assistant."
		if IsValid(ply) then
			ply:ChatPrint(msg)
		else
			print(msg)
		end
		return
	end

	local cvarInterval = GetConVar("ai_request_interval")
	local minInterval = math.max(1.5, math.min(60, cvarInterval and cvarInterval:GetFloat() or 1.5))
	local timeSinceLast = CurTime() - (AI_GROQ.LastRequestTime or 0)
	if timeSinceLast < minInterval then
		local sleepDelay = minInterval - timeSinceLast
		timer.Simple(sleepDelay, function()
			if IsValid(ply) or not ply then
				AI_GROQ.SendRequest(ply, userText, mode, retryCount, true)
			end
		end)
		return
	end
	AI_GROQ.LastRequestTime = CurTime()

	local promptText = userText
	local chatMode = false
	local memoryContext = AI_GROQ.BuildMemoryContext(ply)
	if memoryContext ~= "" then
		promptText = memoryContext .. "\n\nCurrent message: " .. userText
	end
	if mode == "chat" then
		chatMode = true
		promptText = "The user is chatting normally and not asking for a tool or action. Respond conversationally and briefly in plain text only. Do not return JSON.\n\n" .. promptText
	end

	local model = AI_GROQ.GetModel(provider)
	local endpoint = AI_GROQ.GetProviderEndpoint(provider)
	local headers = AI_GROQ.GetProviderHeaders(provider, key)
	local systemPrompt = AI_GROQ.BuildSystemPrompt(ply)
	local requestBody

	if provider == "anthropic" then
		requestBody = util.TableToJSON({
			model = model,
			system = systemPrompt,
			messages = {
				{ role = "user", content = promptText }
			},
			max_tokens = 300,
			temperature = 0.2
		})
	else
		requestBody = util.TableToJSON({
			model = model,
			messages = {
				{ role = "system", content = systemPrompt },
				{ role = "user", content = promptText }
			},
			temperature = 0.2,
			max_tokens = 300
		})
	end

	if not requestBody or requestBody == "" then
		AI_GROQ.LogError("HTTP", "Could not serialize " .. provider .. " request body")
		local message = "AI request could not be serialized. Check the server context size."
		if IsValid(ply) then ply:ChatPrint(message) else print(message) end
		return
	end

	if retryCount == 0 then
		if IsValid(ply) then
			ply:ChatPrint("The AI assistant is thinking...")
		else
			print("The AI assistant is thinking...")
		end
	end

	local request = {
		url = endpoint,
		method = "post",
		headers = headers,
		body = requestBody,
		timeout = AI_GROQ.Config.Timeout or 20,
		success = function(code, body, respHeaders)
			body = type(body) == "string" and body or ""
			if #body > 32768 then
				AI_GROQ.LogError("HTTP", "Rejected oversized response body.")
				if IsValid(ply) then ply:ChatPrint("The AI provider returned an oversized response.") else print("The AI provider returned an oversized response.") end
				return
			end
			if code == 429 then
				local cvarMax = GetConVar("ai_max_retries")
				local maxRetries = math.max(0, math.min(5, cvarMax and cvarMax:GetInt() or 3))
				local cvarDelay = GetConVar("ai_retry_delay")
				local baseDelay = cvarDelay and cvarDelay:GetFloat() or 2
				baseDelay = math.max(1, math.min(30, baseDelay))

				local retryAfter = nil
				if respHeaders then
					for hKey, hVal in pairs(respHeaders) do
						if string.lower(tostring(hKey)) == "retry-after" then
							retryAfter = tonumber(hVal)
							break
						end
					end
				end

				local sleepDelay = retryAfter or (baseDelay * (2 ^ retryCount))
				if sleepDelay < 1 then sleepDelay = 1 end
				if sleepDelay > 30 then sleepDelay = 30 end

				if retryCount < maxRetries then
					local retryMsg = string.format("Rate limit hit (429) for %s. Pausing %.1fs before retrying (attempt %d/%d)...", provider, sleepDelay, retryCount + 1, maxRetries)
					AI_GROQ.LogError("RateLimit", retryMsg .. " Body: " .. tostring(body))
					if IsValid(ply) then
						ply:ChatPrint(retryMsg)
					else
						print(retryMsg)
					end

					timer.Simple(sleepDelay, function()
						if IsValid(ply) or not ply then
							AI_GROQ.SendRequest(ply, userText, mode, retryCount + 1)
						end
					end)
					return
				else
					local failMsg = "AI request (" .. provider .. ") failed: Rate limit (429) exceeded after " .. tostring(maxRetries) .. " retries. Please wait a moment and try again."
					AI_GROQ.LogError("RateLimit", failMsg .. " Body: " .. tostring(body))
					if IsValid(ply) then
						ply:ChatPrint(failMsg)
					else
						print(failMsg)
					end
					return
				end
			end

			if code ~= 200 then
				local errMsg = "Bad response code " .. tostring(code)
				if body and body ~= "" then
					local okJson, errDecoded = pcall(function() return util.JSONToTable(body) end)
					if okJson and type(errDecoded) == "table" then
						if errDecoded.error then
							if type(errDecoded.error) == "table" and errDecoded.error.message then
								errMsg = errMsg .. ": " .. tostring(errDecoded.error.message)
							elseif type(errDecoded.error) == "string" then
								errMsg = errMsg .. ": " .. tostring(errDecoded.error)
							end
						elseif errDecoded.message then
							errMsg = errMsg .. ": " .. tostring(errDecoded.message)
						elseif errDecoded.detail then
							if type(errDecoded.detail) == "table" and errDecoded.detail[1] and errDecoded.detail[1].msg then
								errMsg = errMsg .. ": " .. tostring(errDecoded.detail[1].msg)
							else
								errMsg = errMsg .. ": " .. tostring(errDecoded.detail)
							end
						end
					end
				end
				errMsg = AI_GROQ.SafeText(errMsg, 512)
				AI_GROQ.LogError("HTTP", errMsg .. " body: " .. tostring(body))
				if IsValid(ply) then
					ply:ChatPrint("AI request (" .. provider .. ") failed (" .. tostring(code) .. "): " .. errMsg)
				else
					print("AI request (" .. provider .. ") failed (" .. tostring(code) .. "): " .. errMsg)
				end
				return
			end

			local ok, decoded = pcall(function()
				return util.JSONToTable(body)
			end)

			if not ok or not decoded or type(decoded) ~= "table" then
				AI_GROQ.LogError("AI", "Invalid JSON from response: " .. tostring(body))
				if IsValid(ply) then
					ply:ChatPrint("The AI returned an unexpected response.")
				else
					print("The AI returned an unexpected response.")
				end
				return
			end

			local content = ""
			if provider == "anthropic" then
				if type(decoded.content) == "table" then
					for _, block in ipairs(decoded.content) do
						if type(block) == "table" and type(block.text) == "string" then
							content = content .. block.text
						elseif type(block) == "string" then
							content = content .. block
						end
					end
				elseif type(decoded.completion) == "string" then
					content = decoded.completion
				end
			else
				local choice = type(decoded.choices) == "table" and decoded.choices[1] or nil
				local message = type(choice) == "table" and choice.message or nil
				if type(message) == "table" and type(message.content) == "string" then
					content = message.content
				else
					local candidate = type(decoded.candidates) == "table" and decoded.candidates[1] or nil
					local candidateContent = type(candidate) == "table" and candidate.content or nil
					local parts = type(candidateContent) == "table" and candidateContent.parts or nil
					if type(parts) == "table" then
						for _, part in ipairs(parts) do
							if type(part) == "table" and type(part.text) == "string" then
								content = content .. part.text
							elseif type(part) == "string" then
								content = content .. part
							end
						end
					end
				end
			end

			content = AI_GROQ.NormalizeContent(content)

			if content == "" then
				AI_GROQ.LogError("AI", "Empty content from response: " .. tostring(body))
				if IsValid(ply) then
					ply:ChatPrint("The AI returned an empty response.")
				else
					print("The AI returned an empty response.")
				end
				return
			end
			if #content > 8192 then
				AI_GROQ.LogError("AI", "Rejected oversized response content.")
				if IsValid(ply) then ply:ChatPrint("The AI response was too large to process.") else print("The AI response was too large to process.") end
				return
			end

			AI_GROQ.AddPlayerMemory(ply, userText, content)

			if chatMode then
				if IsValid(ply) then
					ply:ChatPrint("[AI] " .. AI_GROQ.SafeText(content, 1000))
				else
					print("[AI] " .. AI_GROQ.SafeText(content, 1000))
				end
				return
			end

			local parsedOk, parsed = pcall(function()
				return util.JSONToTable(content)
			end)

			if not parsedOk or not parsed or type(parsed) ~= "table" then
				local jsonSub = string.match(content, "({.+})") or string.match(content, "(%[.+%])")
				if jsonSub then
					local subOk, subParsed = pcall(function() return util.JSONToTable(jsonSub) end)
					if subOk and type(subParsed) == "table" then
						parsedOk = true
						parsed = subParsed
					end
				end
			end

			if not parsedOk or not parsed or type(parsed) ~= "table" then
				if IsValid(ply) then
					ply:ChatPrint("[AI] " .. AI_GROQ.SafeText(content, 1000))
				else
					print("[AI] " .. AI_GROQ.SafeText(content, 1000))
				end
				return
			end

			if parsed.actions and type(parsed.actions) == "table" then
				AI_GROQ.ExecuteActions(ply, parsed.actions)
				return
			end

			if #parsed > 0 and type(parsed[1]) == "table" and parsed[1].action then
				AI_GROQ.ExecuteActions(ply, parsed)
				return
			end

			local action = string.lower(tostring(parsed.action or "error"))
			AI_GROQ.ExecuteAction(ply, action, parsed)
		end,
		failed = function(err)
			AI_GROQ.LogError("HTTP", "Request failed: " .. tostring(err))
			if IsValid(ply) then
				ply:ChatPrint("AI request (" .. provider .. ") error: " .. AI_GROQ.SafeText(err, 256))
			else
				print("AI request (" .. provider .. ") error: " .. AI_GROQ.SafeText(err, 256))
			end
		end
	}

	HTTP(request)
end

function AI_GROQ.SendConfigToPlayer(ply)
	if not IsValid(ply) then return end
	local lastRequest = AI_GROQ.ConfigRequestTimes[ply] or 0
	if CurTime() - lastRequest < 2 then return end
	AI_GROQ.ConfigRequestTimes[ply] = CurTime()

	local provider = AI_GROQ.GetApiProvider()
	local model = AI_GROQ.GetModel(provider)

	local keysConfigured = {}
	for prov, _ in pairs(AI_GROQ.Config.SupportedProviders) do
		local cvar = GetConVar("ai_api_key_" .. prov)
		local key = cvar and cvar:GetString() or ""
		if string.Trim(key) ~= "" then
			keysConfigured[prov] = true
		end
	end

	net.Start("AI_GROQ_OpenConfig")
		net.WriteString(provider)
		net.WriteString(model)
		net.WriteString(util.TableToJSON(keysConfigured))
	net.Send(ply)
end

net.Receive("AI_GROQ_RequestConfig", function(len, ply)
	if not IsValid(ply) then return end
	if len ~= 0 then return end
	AI_GROQ.SendConfigToPlayer(ply)
end)

net.Receive("AI_GROQ_UpdateConfig", function(len, ply)
	if not IsValid(ply) then return end
	if len < 32 or len > 8192 then
		ply:ChatPrint("Invalid AI configuration request.")
		return
	end
	if not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to update AI configuration.")
		return
	end

	local provider = string.lower(net.ReadString() or "groq")
	local model = AI_GROQ.SafeText(net.ReadString(), 128)
	local keyProvider = string.lower(net.ReadString() or "")
	local keyValue = AI_GROQ.SanitizeKey(AI_GROQ.SafeText(net.ReadString(), 512))

	if not AI_GROQ.IsValidProvider(provider) then
		provider = "groq"
	end

	local provCvar = GetConVar("ai_provider")
	if provCvar then provCvar:SetString(provider) end

	if model ~= "" then
		local modelCvar = GetConVar("ai_model")
		if modelCvar then modelCvar:SetString(model) end
	end

	if keyValue ~= "" and AI_GROQ.IsValidProvider(keyProvider) then
		local cvar = GetConVar("ai_api_key_" .. keyProvider)
		if cvar then
			cvar:SetString(keyValue)
		end
	end

	local effectiveModel = AI_GROQ.GetModel(provider)
	ply:ChatPrint("AI configuration updated. Provider: " .. provider .. ", model: " .. effectiveModel)
end)

concommand.Add("ai_config", function(ply, cmd, args)
	if IsValid(ply) then
		AI_GROQ.SendConfigToPlayer(ply)
	else
		print("ai_config opens the configuration menu for players.")
	end
end)

concommand.Add("ai_set_api_key", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to run this command.")
		return
	end

	local provider = string.lower(args[1] or "")
	local key = args[2] or ""
	if provider == "" or key == "" then
		local usage = "Usage: ai_set_api_key <groq|openai|openrouter|anthropic|gemini|huggingface|cerebras|deepseek|xai> <key>"
		if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
		return
	end
	if not AI_GROQ.IsValidProvider(provider) then
		local invalid = "Invalid provider. Supported: groq, openai, openrouter, anthropic, gemini, huggingface, cerebras, deepseek, xai"
		if IsValid(ply) then ply:ChatPrint(invalid) else print(invalid) end
		return
	end

	local cvar = GetConVar("ai_api_key_" .. provider)
	if cvar then cvar:SetString(key) end

	local msg = "API key set for provider: " .. provider
	if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("ai_set_provider", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to run this command.")
		return
	end

	local provider = string.lower(args[1] or "")
	if not AI_GROQ.IsValidProvider(provider) then
		local usage = "Usage: ai_set_provider <groq|openai|openrouter|anthropic|gemini|huggingface|cerebras|deepseek|xai>"
		if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
		return
	end

	local cvar = GetConVar("ai_provider")
	if cvar then cvar:SetString(provider) end

	local msg = "AI provider set to " .. provider
	if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("ai_set_model", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to run this command.")
		return
	end

	local model = table.concat(args or {}, " ")
	if model == "" then
		local usage = "Usage: ai_set_model <model>"
		if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
		return
	end

	local cvar = GetConVar("ai_model")
	if cvar then cvar:SetString(model) end

	local msg = "AI model set to " .. model
	if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("ai_blacklist", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to manage AI blacklists.")
		return
	end
	local kind = string.lower(args[1] or "")
	local operation = string.lower(args[2] or "")
	local pattern = args[3] or ""
	local validKind = kind == "model" or kind == "weapon"
	if kind == "all" then validKind = true end
	if not validKind or operation == "" then
		local usage = "Usage: ai_blacklist <model|weapon|all> <clear|reset|add|remove|list> [pattern]"
		if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
		return
	end

	local function report(message)
		if IsValid(ply) then ply:ChatPrint(message) else print(message) end
	end
	local kinds = kind == "all" and {"model", "weapon"} or {kind}
	local changed = false
	for _, selectedKind in ipairs(kinds) do
		local values = AI_GROQ.GetBlacklist(selectedKind)
		if operation == "clear" then
			for index = #values, 1, -1 do table.remove(values, index) end
			AI_GROQ.SetBlacklistCVar(selectedKind)
			changed = true
		elseif operation == "reset" then
			local defaults = selectedKind == "model" and AI_GROQ.Config.DefaultModelBlacklist or AI_GROQ.Config.DefaultWeaponBlacklist
			AI_GROQ.Config[selectedKind == "model" and "ModelBlacklist" or "WeaponBlacklist"] = table.Copy(defaults)
			AI_GROQ.SetBlacklistCVar(selectedKind)
			changed = true
		elseif operation == "add" then
			changed = AI_GROQ.AddBlacklistPattern(selectedKind, pattern) or changed
		elseif operation == "remove" then
			changed = AI_GROQ.RemoveBlacklistPattern(selectedKind, pattern) or changed
		elseif operation == "list" then
			report(selectedKind .. " blacklist: " .. (#values > 0 and table.concat(values, ", ") or "empty"))
		else
			report("Operation must be clear, reset, add, remove, or list.")
			return
		end
	end
	if operation ~= "list" then
		report(changed and "AI blacklist updated." or "No blacklist entry changed.")
	end
end)

concommand.Add("ai_spawn_catalog_dump", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to inspect the AI spawn catalog.")
		return
	end
	local output = AI_GROQ.GetSpawnMenuContext()
	if IsValid(ply) then
		for _, line in ipairs(string.Explode("\n", output)) do
			ply:PrintMessage(HUD_PRINTCONSOLE, line)
		end
	else
		print(output)
	end
end)

concommand.Add("ai_persona", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to run this command.")
		return
	end

	local persona = table.concat(args or {}, " ")
	if not persona or persona == "" then
		local cvar = GetConVar("ai_groq_persona")
		local current = cvar and cvar:GetString() or ""
		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "Current persona: " .. current)
		else
			print("Current persona: " .. current)
		end
		return
	end

	local cvar = GetConVar("ai_groq_persona")
	if cvar then cvar:SetString(persona) end

	if IsValid(ply) then ply:ChatPrint("Persona updated.") else print("Persona updated.") end
end)

concommand.Add("ai_persona_clear", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to run this command.")
		return
	end

	local cvar = GetConVar("ai_groq_persona")
	if cvar then cvar:SetString("") end

	if IsValid(ply) then ply:ChatPrint("Persona cleared.") else print("Persona cleared.") end
end)

concommand.Add("ai_lua_exec_enable", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then return end
	local cvar = GetConVar("ai_groq_lua_exec_enabled")
	if cvar then cvar:SetBool(false) end
	if IsValid(ply) then ply:ChatPrint("AI Lua execution has been removed and cannot be enabled.") else print("AI Lua execution has been removed and cannot be enabled.") end
end)

concommand.Add("ai_lua_exec_disable", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then return end
	local cvar = GetConVar("ai_groq_lua_exec_enabled")
	if cvar then cvar:SetBool(false) end
	if IsValid(ply) then ply:ChatPrint("Lua execution confirmation disabled.") else print("Lua execution confirmation disabled.") end
end)

concommand.Add("ai_chat_enabled", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then return end
	local cvar = GetConVar("ai_groq_chat_enabled")
	if cvar then cvar:SetBool(true) end
	if IsValid(ply) then ply:ChatPrint("AI chat mode enabled. Non-!ai messages will be sent to the AI.") else print("AI chat mode enabled. Non-!ai messages will be sent to the AI.") end
end)

concommand.Add("ai_chat_disabled", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then return end
	local cvar = GetConVar("ai_groq_chat_enabled")
	if cvar then cvar:SetBool(false) end
	if IsValid(ply) then ply:ChatPrint("AI chat mode disabled. Only !ai commands will be processed.") else print("AI chat mode disabled. Only !ai commands will be processed.") end
end)

concommand.Add("ai_chatlog_dump", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to inspect the AI chat log.")
		return
	end
	AI_GROQ.PrintChatLog(ply)
end)

concommand.Add("ai_chatlog_clear", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then return end
	AI_GROQ.ClearChatLog()
	if IsValid(ply) then ply:ChatPrint("AI chat log cleared.") else print("AI chat log cleared.") end
end)

concommand.Add("ai_errorlog_dump", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then
		ply:ChatPrint("You must be an admin to inspect the AI error log.")
		return
	end
	AI_GROQ.PrintErrorLog(ply)
end)

concommand.Add("ai_errorlog_clear", function(ply, cmd, args)
	if IsValid(ply) and not AI_GROQ.IsULXAdmin(ply) then return end
	AI_GROQ.ClearErrorLog()
	if IsValid(ply) then ply:ChatPrint("AI error log cleared.") else print("AI error log cleared.") end
end)

concommand.Add("ai", function(ply, cmd, args)
	local prompt = table.concat(args, " ")
	if prompt == "" then
		if IsValid(ply) then ply:ChatPrint("Usage: ai <request>") else print("Usage: ai <request>") end
		return
	end
	AI_GROQ.SendRequest(ply, prompt, "command")
end)

hook.Add("PlayerDisconnected", "AI_GROQ_PlayerDisconnected", function(ply)
	if AI_GROQ.PlayerCooldowns then
		AI_GROQ.PlayerCooldowns[ply] = nil
	end
	if AI_GROQ.PlayerMemory then
		AI_GROQ.PlayerMemory[ply] = nil
	end
	if AI_GROQ.ConfigRequestTimes then
		AI_GROQ.ConfigRequestTimes[ply] = nil
	end
end)

hook.Add("InitPostEntity", "AI_GROQ_ClearChatLogOnNewGame", function()
	AI_GROQ.ClearChatLog()
end)

hook.Add("PlayerSay", "AI_GROQ_PlayerSay", function(ply, text, teamChat)
	if not IsValid(ply) then return end
	if teamChat then return end
	local trimmed = AI_GROQ.SafeText(text, 1000)
	AI_GROQ.AppendChatLog(ply, trimmed, "say")

	local lowerTrimmed = string.lower(trimmed)
	if lowerTrimmed == "!ai" or string.sub(lowerTrimmed, 1, 4) == "!ai " then
		local request = string.Trim(string.sub(trimmed, 4))
		AI_GROQ.AppendChatLog(ply, request, "command")
		if request == "" then
			ply:ChatPrint("Usage: !ai <request>")
			return ""
		end

		AI_GROQ.SendRequest(ply, request, "command")
		return ""
	end

	if AI_GROQ.IsChatModeEnabled() then
		AI_GROQ.SendRequest(ply, trimmed, "chat")
	end
end)

print("[AI_GROQ] Groq assistant addon loaded")
