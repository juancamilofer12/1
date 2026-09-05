--!strict
--[[
	PartyUI.lua

	Interfaz básica y funcional para probar el PartyService del
	servidor (Fase 2) y, desde la Fase 3, el inicio de partida +
	countdown de MatchService. Explícitamente NO es la UI final: no
	hay estética, solo lo mínimo para poder crear/unirse/abandonar/
	expulsar/transferir liderazgo, iniciar partida y ver el estado
	(countdown, preparación, comienzo) actualizarse en vivo.

	Construye todo con Instance.new en runtime (no depende de UI
	prediseñada en Studio), y usa exclusivamente NetClient para
	hablar con el servidor: nunca navega ReplicatedStorage.Net a mano
	ni asume nombres de remotes fuera de RemotesConfig.

	El servidor sigue siendo la autoridad: esta UI solo refleja el
	último Types.PartyState recibido vía el remote "Party_Updated" y
	el resultado de cada acción; nunca decide localmente si un
	jugador "es" líder o "puede" expulsar a alguien, solo oculta
	botones que el servidor de todas formas volvería a rechazar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local Types = require(ReplicatedStorage.Shared.Types)

local localPlayer = Players.LocalPlayer

local PartyUI = {}

-- Evita que un click doble/spam del usuario dispare dos invokes
-- simultáneos desde el cliente mientras el primero todavía no
-- respondió. Es solo una comodidad de UI: la protección real contra
-- spam vive en el servidor (PartyConfig.ActionCooldownSeconds).
local actionInFlight = false

local function withDebounce(callback: () -> ())
	if actionInFlight then
		return
	end
	actionInFlight = true
	local ok, err = pcall(callback)
	actionInFlight = false
	if not ok then
		warn("[PartyUI] Error ejecutando acción:", err)
	end
end

function PartyUI.Init()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local currentParty: Types.PartyState? = nil
	-- Fase 3: snapshot de la Match asociada a la Party actual (nil
	-- si no hay ninguna en curso).
	local currentMatch: Types.MatchState? = nil

	-- ============================================================
	-- Construcción de la UI
	-- ============================================================

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PartyUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 260, 0, 340)
	panel.Position = UDim2.new(0, 16, 0, 16)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BorderSizePixel = 1
	panel.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Text = "Party (Fase 2 - prueba)"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.LayoutOrder = 2
	statusLabel.Size = UDim2.new(1, 0, 0, 32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Sin party."
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statusLabel.Font = Enum.Font.SourceSans
	statusLabel.TextSize = 14
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.Parent = panel

	local createButton = Instance.new("TextButton")
	createButton.Name = "CreateButton"
	createButton.LayoutOrder = 3
	createButton.Size = UDim2.new(1, 0, 0, 30)
	createButton.Text = "Crear Party"
	createButton.Font = Enum.Font.SourceSansBold
	createButton.TextSize = 16
	createButton.Parent = panel

	local joinRow = Instance.new("Frame")
	joinRow.Name = "JoinRow"
	joinRow.LayoutOrder = 4
	joinRow.Size = UDim2.new(1, 0, 0, 30)
	joinRow.BackgroundTransparency = 1
	joinRow.Parent = panel

	local joinIdBox = Instance.new("TextBox")
	joinIdBox.Name = "JoinIdBox"
	joinIdBox.Size = UDim2.new(0.65, -4, 1, 0)
	joinIdBox.Position = UDim2.new(0, 0, 0, 0)
	joinIdBox.PlaceholderText = "Party ID"
	joinIdBox.Text = ""
	joinIdBox.ClearTextOnFocus = false
	joinIdBox.Parent = joinRow

	local joinButton = Instance.new("TextButton")
	joinButton.Name = "JoinButton"
	joinButton.Size = UDim2.new(0.35, 0, 1, 0)
	joinButton.Position = UDim2.new(0.65, 4, 0, 0)
	joinButton.Text = "Unirse"
	joinButton.Font = Enum.Font.SourceSansBold
	joinButton.TextSize = 16
	joinButton.Parent = joinRow

	local membersList = Instance.new("ScrollingFrame")
	membersList.Name = "MembersList"
	membersList.LayoutOrder = 5
	membersList.Size = UDim2.new(1, 0, 0, 140)
	membersList.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	membersList.BorderSizePixel = 0
	membersList.ScrollBarThickness = 6
	membersList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	membersList.CanvasSize = UDim2.new(0, 0, 0, 0)
	membersList.Parent = panel

	local membersLayout = Instance.new("UIListLayout")
	membersLayout.SortOrder = Enum.SortOrder.LayoutOrder
	membersLayout.Padding = UDim.new(0, 2)
	membersLayout.Parent = membersList

	local leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.LayoutOrder = 6
	leaveButton.Size = UDim2.new(1, 0, 0, 30)
	leaveButton.Text = "Abandonar Party"
	leaveButton.Font = Enum.Font.SourceSansBold
	leaveButton.TextSize = 16
	leaveButton.Parent = panel

	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.LayoutOrder = 7
	startButton.Size = UDim2.new(1, 0, 0, 30)
	startButton.Text = "Iniciar Partida"
	startButton.Font = Enum.Font.SourceSansBold
	startButton.TextSize = 16
	startButton.Parent = panel

	-- Fase 3: estado/countdown de la Match asociada a la Party
	-- actual (si la hay). Ver Types.MatchState / MatchCountdownUpdate.
	local matchLabel = Instance.new("TextLabel")
	matchLabel.Name = "MatchLabel"
	matchLabel.LayoutOrder = 8
	matchLabel.Size = UDim2.new(1, 0, 0, 40)
	matchLabel.BackgroundTransparency = 1
	matchLabel.Text = ""
	matchLabel.Visible = false
	matchLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	matchLabel.Font = Enum.Font.SourceSansBold
	matchLabel.TextSize = 14
	matchLabel.TextWrapped = true
	matchLabel.TextXAlignment = Enum.TextXAlignment.Left
	matchLabel.TextYAlignment = Enum.TextYAlignment.Top
	matchLabel.Parent = panel

	screenGui.Parent = playerGui

	-- ============================================================
	-- Render: reconstruye la parte visual que depende del estado
	-- ============================================================

	local function setStatus(text: string)
		statusLabel.Text = text
	end

	local function clearMemberRows()
		for _, child in ipairs(membersList:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function isLocalPlayerLeader(): boolean
		return currentParty ~= nil and currentParty.Leader == localPlayer.UserId
	end

	-- Fase 3: texto legible para cada fase de Types.MatchPhase.
	local PHASE_LABELS: { [string]: string } = {
		Lobby = "Preparando inicio...",
		Countdown = "Arrancando en",
		Preparation = "Preparación",
		InProgress = "¡Partida en curso!",
		Ending = "Finalizando partida...",
		GameOver = "Partida terminada.",
	}

	local function renderMatch()
		if not currentMatch then
			matchLabel.Visible = false
			matchLabel.Text = ""
			return
		end

		matchLabel.Visible = true
		local phaseLabel = PHASE_LABELS[currentMatch.Phase] or currentMatch.Phase
		if currentMatch.Phase == "Countdown" then
			matchLabel.Text = string.format("%s %d...", phaseLabel, math.ceil(currentMatch.TimeRemaining))
		else
			matchLabel.Text = phaseLabel
		end
	end

	local function render()
		local inParty = currentParty ~= nil
		local matchActive = currentMatch ~= nil

		createButton.Visible = not inParty
		joinRow.Visible = not inParty
		membersList.Visible = inParty
		leaveButton.Visible = inParty
		startButton.Visible = inParty and isLocalPlayerLeader()
		startButton.Text = matchActive and "Partida en curso" or "Iniciar Partida"
		startButton.AutoButtonColor = not matchActive
		startButton.BackgroundColor3 = matchActive and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(255, 255, 255)

		renderMatch()
		clearMemberRows()

		if not currentParty then
			setStatus("Sin party. Creá una o unite con un Party ID.")
			return
		end

		local amLeader = isLocalPlayerLeader()
		setStatus(
			string.format(
				"Party: %s\nMiembros: %d/%d",
				currentParty.PartyId,
				#currentParty.Members,
				currentParty.MaximumMembers
			)
		)

		for order, member in ipairs(currentParty.Members) do
			local row = Instance.new("Frame")
			row.Name = "Member_" .. tostring(member.UserId)
			row.LayoutOrder = order
			row.Size = UDim2.new(1, 0, 0, 26)
			row.BackgroundTransparency = 1
			row.Parent = membersList

			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rowLayout.Padding = UDim.new(0, 4)
			rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			rowLayout.Parent = row

			local isLeaderRow = member.UserId == currentParty.Leader
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "NameLabel"
			nameLabel.LayoutOrder = 1
			nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = member.Name .. (isLeaderRow and " (Líder)" or "")
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLabel.Font = isLeaderRow and Enum.Font.SourceSansBold or Enum.Font.SourceSans
			nameLabel.TextSize = 14
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = row

			-- Un jugador nunca se expulsa ni se transfiere el
			-- liderazgo a sí mismo, y estos botones solo tienen
			-- sentido para el líder mirando a OTROS miembros.
			local showLeaderActions = amLeader and member.UserId ~= localPlayer.UserId

			if showLeaderActions then
				local kickButton = Instance.new("TextButton")
				kickButton.Name = "KickButton"
				kickButton.LayoutOrder = 2
				kickButton.Size = UDim2.new(0.25, 0, 1, 0)
				kickButton.Text = "Expulsar"
				kickButton.TextSize = 12
				kickButton.Parent = row

				kickButton.MouseButton1Click:Connect(function()
					withDebounce(function()
						local ok, result = pcall(NetClient.InvokeServer, "Party_Kick", member.UserId)
						if ok and (result :: Types.PartyActionResult).Ok then
							setStatus("Expulsaste a " .. member.Name .. ".")
						elseif ok then
							setStatus("No se pudo expulsar: " .. tostring((result :: Types.PartyActionResult).Error))
						else
							setStatus("Error de red al expulsar.")
						end
					end)
				end)

				local transferButton = Instance.new("TextButton")
				transferButton.Name = "TransferButton"
				transferButton.LayoutOrder = 3
				transferButton.Size = UDim2.new(0.25, 0, 1, 0)
				transferButton.Text = "Hacer líder"
				transferButton.TextSize = 12
				transferButton.Parent = row

				transferButton.MouseButton1Click:Connect(function()
					withDebounce(function()
						local ok, result =
							pcall(NetClient.InvokeServer, "Party_TransferLeadership", member.UserId)
						if ok and (result :: Types.PartyActionResult).Ok then
							setStatus("Ahora " .. member.Name .. " es el líder.")
						elseif ok then
							setStatus("No se pudo transferir: " .. tostring((result :: Types.PartyActionResult).Error))
						else
							setStatus("Error de red al transferir liderazgo.")
						end
					end)
				end)
			end
		end
	end

	-- ============================================================
	-- Acciones (botones -> NetClient -> servidor)
	-- ============================================================

	createButton.MouseButton1Click:Connect(function()
		withDebounce(function()
			local ok, result = pcall(NetClient.InvokeServer, "Party_Create")
			if not ok then
				setStatus("Error de red al crear la party.")
				return
			end
			local actionResult = result :: Types.PartyActionResult
			if not actionResult.Ok then
				setStatus("No se pudo crear la party: " .. tostring(actionResult.Error))
			end
			-- Si tuvo éxito, el propio servidor ya nos va a mandar el
			-- Party_Updated con el estado nuevo; no hace falta
			-- pintarlo acá para evitar manejar dos fuentes de verdad.
		end)
	end)

	joinButton.MouseButton1Click:Connect(function()
		withDebounce(function()
			local partyId = joinIdBox.Text
			if partyId == "" then
				setStatus("Escribí un Party ID para unirte.")
				return
			end
			local ok, result = pcall(NetClient.InvokeServer, "Party_Join", partyId)
			if not ok then
				setStatus("Error de red al unirse.")
				return
			end
			local actionResult = result :: Types.PartyActionResult
			if not actionResult.Ok then
				setStatus("No se pudo unir: " .. tostring(actionResult.Error))
			end
		end)
	end)

	leaveButton.MouseButton1Click:Connect(function()
		withDebounce(function()
			local ok, result = pcall(NetClient.InvokeServer, "Party_Leave")
			if not ok then
				setStatus("Error de red al abandonar.")
				return
			end
			local actionResult = result :: Types.PartyActionResult
			if not actionResult.Ok then
				setStatus("No se pudo abandonar: " .. tostring(actionResult.Error))
			end
		end)
	end)

	startButton.MouseButton1Click:Connect(function()
		withDebounce(function()
			if currentMatch then
				-- Ya hay una Match para esta Party: el servidor de
				-- todas formas la rechazaría (MatchAlreadyExists), pero
				-- ni siquiera vale la pena invocar el remote.
				return
			end
			local ok, result = pcall(NetClient.InvokeServer, "Match_Start")
			if not ok then
				setStatus("Error de red al iniciar la partida.")
				return
			end
			local actionResult = result :: Types.MatchActionResult
			if not actionResult.Ok then
				setStatus("No se pudo iniciar la partida: " .. tostring(actionResult.Error))
			end
			-- Si tuvo éxito, "Match_StateUpdated" ya nos va a empujar
			-- el snapshot nuevo; no hace falta pintarlo acá.
		end)
	end)

	-- ============================================================
	-- Recepción de actualizaciones del servidor
	-- ============================================================

	NetClient.OnClientEvent("Party_Updated", function(state: Types.PartyState?)
		currentParty = state
		render()
	end)

	-- Fase 3: snapshot completo en cada cambio de fase de la Match
	-- (o nil cuando la Match se cancela/termina).
	NetClient.OnClientEvent("Match_StateUpdated", function(state: Types.MatchState?)
		currentMatch = state
		render()
	end)

	-- Fase 3: tick liviano de countdown. Solo actualiza el número; el
	-- snapshot completo sigue llegando por Match_StateUpdated.
	NetClient.OnClientEvent("Match_CountdownUpdate", function(update: Types.MatchCountdownUpdate)
		if currentMatch and currentMatch.PartyId == update.PartyId then
			currentMatch = TableUtils.DeepCopy(currentMatch) :: Types.MatchState
			currentMatch.TimeRemaining = update.TimeRemaining
			renderMatch()
		end
	end)

	render()
end

return PartyUI
