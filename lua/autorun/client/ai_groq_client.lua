if not CLIENT then return end

net.Receive("AI_GROQ_OpenWindow", function()
	local title = net.ReadString()
	local message = net.ReadString()

	local frame = vgui.Create("DFrame")
	frame:SetTitle(title)
	frame:SetSize(480, 220)
	frame:Center()
	frame:MakePopup()

	local label = vgui.Create("DLabel", frame)
	label:SetPos(16, 36)
	label:SetSize(448, 120)
	label:SetText(message)
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)

	local button = vgui.Create("DButton", frame)
	button:SetText("Close")
	button:SetSize(120, 30)
	button:SetPos(16, 168)
	button.DoClick = function()
		frame:Close()
	end
end)

net.Receive("AI_GROQ_OpenConfig", function()
	local provider = net.ReadString()
	local model = net.ReadString()
	local keysJson = net.ReadString()
	local hasKeys = util.JSONToTable(keysJson) or {}

	local providerDefaults = {
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

	local frame = vgui.Create("DFrame")
	frame:SetTitle("AI Assistant Config")
	frame:SetSize(560, 400)
	frame:Center()
	frame:MakePopup()

	local y = 32
	local label = vgui.Create("DLabel", frame)
	label:SetPos(16, y)
	label:SetSize(120, 20)
	label:SetText("Provider:")

	local providerCombo = vgui.Create("DComboBox", frame)
	providerCombo:SetPos(120, y)
	providerCombo:SetSize(220, 20)
	providerCombo:AddChoice("groq", "groq", provider == "groq")
	providerCombo:AddChoice("openai", "openai", provider == "openai")
	providerCombo:AddChoice("openrouter", "openrouter", provider == "openrouter")
	providerCombo:AddChoice("anthropic", "anthropic", provider == "anthropic")
	providerCombo:AddChoice("gemini", "gemini", provider == "gemini")
	providerCombo:AddChoice("huggingface", "huggingface", provider == "huggingface")
	providerCombo:AddChoice("cerebras", "cerebras", provider == "cerebras")
	providerCombo:AddChoice("deepseek", "deepseek", provider == "deepseek")
	providerCombo:AddChoice("xai", "xai", provider == "xai")
	providerCombo:AddChoice("ollama (configure with local_ai_config)", "ollama", provider == "ollama")

	y = y + 32
	local modelLabel = vgui.Create("DLabel", frame)
	modelLabel:SetPos(16, y)
	modelLabel:SetSize(120, 20)
	modelLabel:SetText("Model:")

	local modelEntry = vgui.Create("DTextEntry", frame)
	modelEntry:SetPos(120, y)
	modelEntry:SetSize(410, 20)
	modelEntry:SetText(model)

	providerCombo.OnSelect = function(self, index, value, data)
		local currentModel = string.Trim(modelEntry:GetValue())
		local isDefault = (currentModel == "")
		for _, def in pairs(providerDefaults) do
			if currentModel == def then
				isDefault = true
				break
			end
		end
		if isDefault and providerDefaults[value] then
			modelEntry:SetText(providerDefaults[value])
		end
	end

	y = y + 32
	local keyLabel = vgui.Create("DLabel", frame)
	keyLabel:SetPos(16, y)
	keyLabel:SetSize(120, 20)
	keyLabel:SetText("API Key:")

	local keyEntry = vgui.Create("DTextEntry", frame)
	keyEntry:SetPos(120, y)
	keyEntry:SetSize(410, 20)
	keyEntry:SetText("")
	keyEntry:SetPlaceholderText("Enter new API key (or leave empty to keep saved key)")
	keyEntry:SetUpdateOnType(true)

	y = y + 44
	local statusLabel = vgui.Create("DLabel", frame)
	statusLabel:SetPos(16, y)
	statusLabel:SetSize(528, 70)
	statusLabel:SetText("Current API Keys Saved:\n" ..
		"• Groq: " .. (hasKeys.groq and "Configured" or "Not set") .. "  |  " ..
		"• OpenAI: " .. (hasKeys.openai and "Configured" or "Not set") .. "  |  " ..
		"• OpenRouter: " .. (hasKeys.openrouter and "Configured" or "Not set") .. "\n" ..
		"• Anthropic: " .. (hasKeys.anthropic and "Configured" or "Not set") .. "  |  " ..
		"• Gemini: " .. (hasKeys.gemini and "Configured" or "Not set") .. "  |  " ..
		"• Hugging Face: " .. (hasKeys.huggingface and "Configured" or "Not set") .. "  |  " ..
		"• Cerebras: " .. (hasKeys.cerebras and "Configured" or "Not set") .. "\n" ..
		"• DeepSeek: " .. (hasKeys.deepseek and "Configured" or "Not set") .. "  |  " ..
		"• xAI: " .. (hasKeys.xai and "Configured" or "Not set")
	)
	statusLabel:SetWrap(true)
	statusLabel:SetAutoStretchVertical(true)

	y = y + 80
	local saveButton = vgui.Create("DButton", frame)
	saveButton:SetText("Save")
	saveButton:SetPos(140, y)
	saveButton:SetSize(120, 30)
	saveButton.DoClick = function()
		local selectedProvider = providerCombo:GetSelected() or providerCombo:GetValue() or "groq"
		if selectedProvider == "" then selectedProvider = "groq" end
		if selectedProvider == "ollama" then
			chat.AddText(Color(255, 190, 90), "[Local AI] ", color_white, "Use local_ai_config to detect Ollama and select an installed model.")
			return
		end
		local selectedModel = string.Trim(modelEntry:GetValue())
		local keyValue = string.Trim(keyEntry:GetValue())
		net.Start("AI_GROQ_UpdateConfig")
			net.WriteString(selectedProvider)
			net.WriteString(selectedModel)
			net.WriteString(selectedProvider)
			net.WriteString(keyValue)
		net.SendToServer()
		frame:Close()
	end

	local closeButton = vgui.Create("DButton", frame)
	closeButton:SetText("Close")
	closeButton:SetPos(280, y)
	closeButton:SetSize(120, 30)
	closeButton.DoClick = function()
		frame:Close()
	end
end)

local localAIFrame

net.Receive("AI_GROQ_LocalModelsResult", function()
	local success = net.ReadBool()
	local message = net.ReadString()
	local count = math.min(net.ReadUInt(7), 100)
	local models = {}
	for index = 1, count do
		models[index] = net.ReadString()
	end

	if not success or #models == 0 then
		chat.AddText(Color(255, 190, 90), "[Local AI] ", color_white, message)
		return
	end

	if IsValid(localAIFrame) then
		localAIFrame:Close()
	end

	localAIFrame = vgui.Create("DFrame")
	localAIFrame:SetTitle("Local AI - Ollama Models")
	localAIFrame:SetSize(460, 420)
	localAIFrame:Center()
	localAIFrame:MakePopup()

	local status = vgui.Create("DLabel", localAIFrame)
	status:SetPos(16, 34)
	status:SetSize(428, 36)
	status:SetText(message)
	status:SetWrap(true)

	local modelList = vgui.Create("DListView", localAIFrame)
	modelList:SetPos(16, 76)
	modelList:SetSize(428, 270)
	modelList:AddColumn("Installed models")
	for _, model in ipairs(models) do
		modelList:AddLine(model)
	end
	modelList:SelectFirstItem()

	local selectButton = vgui.Create("DButton", localAIFrame)
	selectButton:SetText("Use selected model")
	selectButton:SetPos(16, 364)
	selectButton:SetSize(200, 32)
	selectButton.DoClick = function()
		local selectedLine = modelList:GetSelectedLine()
		local selected = selectedLine and modelList:GetLine(selectedLine)
		if not selected then
			status:SetText("Select a model first.")
			return
		end
		net.Start("AI_GROQ_SelectLocalModel")
			net.WriteString(selected:GetValue(1))
		net.SendToServer()
	end

	local closeButton = vgui.Create("DButton", localAIFrame)
	closeButton:SetText("Close")
	closeButton:SetPos(232, 364)
	closeButton:SetSize(100, 32)
	closeButton.DoClick = function()
		localAIFrame:Close()
	end
end)

net.Receive("AI_GROQ_LocalModelSelected", function()
	local model = net.ReadString()
	chat.AddText(Color(120, 220, 140), "[Local AI] ", color_white, "Now using Ollama model: " .. model)
	if IsValid(localAIFrame) then
		localAIFrame:Close()
	end
end)

concommand.Add("ai_config_menu", function()
	net.Start("AI_GROQ_RequestConfig")
	net.SendToServer()
end)

concommand.Add("ai_config", function()
	net.Start("AI_GROQ_RequestConfig")
	net.SendToServer()
end)

concommand.Add("local_ai_config", function()
	net.Start("AI_GROQ_LocalModelsRequest")
	net.SendToServer()
end)
