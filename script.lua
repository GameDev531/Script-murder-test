--[[
    ██████  SONION'S MM2 ULTRA HUB  ██████
    - ESP com cores profissionais
    - Aimbot (Murder -> Sheriff | Sheriff -> Murder)
    - God Mode (imune a facadas)
    - Menu com abas (Insert para abrir/fechar)
    - Código otimizado, sem erros e com verificações de segurança
]]

-- ============================
-- CONFIGURAÇÕES RÁPIDAS (ediTE AQUI)
-- ============================
local CONFIG = {
    MenuKey = Enum.KeyCode.Insert,  -- Tecla para abrir/fechar o menu
    AimSmoothness = 0.3,            -- 0 = instantâneo, 0.1~0.5 = suave (recomendo 0.3)
    DefaultFOV = 120,               -- Ângulo de campo para o aimbot
    ESPEnabled = true,              -- Liga ESP ao iniciar
    AimbotEnabled = true,           -- Liga Aimbot ao iniciar
    GodModeEnabled = false,         -- Liga God Mode ao iniciar (deixe false para testar)
}

-- ============================
-- SERVIÇOS E VARIÁVEIS GLOBAIS
-- ============================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

-- Cores
local COR_MURDER = Color3.fromRGB(255, 0, 0)
local COR_SHERIFF = Color3.fromRGB(0, 100, 255)
local COR_INOCENTE = Color3.fromRGB(0, 255, 0)
local COR_BRANCO = Color3.fromRGB(255, 255, 255)

-- Desenhos do ESP
local desenhos = {}

-- Estado das funções
local estado = {
    ESP = CONFIG.ESPEnabled,
    Aimbot = CONFIG.AimbotEnabled,
    GodMode = CONFIG.GodModeEnabled,
    FOV = CONFIG.DefaultFOV,
    Suave = CONFIG.AimSmoothness > 0,
    MostrarNomes = true,  -- Adicionado para o toggle de nomes
}

-- ============================
-- FUNÇÕES AUXILIARES
-- ============================
local function temFerramenta(player, nomeAlvo)
    nomeAlvo = nomeAlvo:lower()
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower() == nomeAlvo then
                return true
            end
        end
    end
    local char = player.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower() == nomeAlvo then
                return true
            end
        end
    end
    return false
end

local function getRole(player)
    if temFerramenta(player, "Knife") then return "Murder" end
    if temFerramenta(player, "Gun") then return "Sheriff" end
    return "Inocente"
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

-- Obtém o alvo correto para o aimbot baseado no seu papel
local function getAimbotTarget()
    local myRole = getRole(LocalPlayer)
    if myRole == "Inocente" then return nil end

    local targetRole = (myRole == "Murder") and "Sheriff" or "Murder"
    local bestTarget = nil
    local bestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) and getRole(player) == targetRole then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        -- Calcula distância do centro da tela (crosshair)
                        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        -- Verifica FOV
                        if dist <= estado.FOV then
                            -- Verifica visibilidade (raycast)
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                            rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
                            local origin = Camera.CFrame.Position
                            local direction = (root.Position - origin).Unit * 999
                            local result = workspace:Raycast(origin, direction, rayParams)
                            if not result or result.Instance:IsDescendantOf(char) then
                                if dist < bestDist then
                                    bestDist = dist
                                    bestTarget = player
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- ============================
-- AIMBOT (RODANDO EM HEARTBEAT)
-- ============================
RunService.Heartbeat:Connect(function()
    if not estado.Aimbot then return end

    local target = getAimbotTarget()
    if not target then return end

    local char = target.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local targetPos = head.Position
    local currentCF = Camera.CFrame
    local newCF = CFrame.lookAt(currentCF.Position, targetPos)

    if estado.Suave then
        -- Mira suave (lerp)
        local lerpCF = currentCF:Lerp(newCF, CONFIG.AimSmoothness)
        Camera.CFrame = lerpCF
    else
        -- Mira instantânea
        Camera.CFrame = newCF
    end
end)

-- ============================
-- GOD MODE (IMUNE A FACADA)
-- ============================
local function connectGodMode(humanoid)
    humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if estado.GodMode and humanoid.Health < 100 then
            humanoid.Health = 100
        end
    end)
end

connectGodMode(Humanoid)

-- Reconecta o God Mode se o personagem renascer
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    connectGodMode(Humanoid)
end)

-- ============================
-- ESP (RENDERSTEP) - MELHORADO
-- ============================
RunService.RenderStepped:Connect(function()
    if not estado.ESP then
        -- Limpa todos os desenhos se o ESP estiver desligado
        for player, d in pairs(desenhos) do
            pcall(function()
                d.box:Remove()
                d.label:Remove()
            end)
            desenhos[player] = nil
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") and isAlive(player) then
            local root = char.HumanoidRootPart
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)

            if not desenhos[player] then
                desenhos[player] = {
                    box = Drawing.new("Square"),
                    label = Drawing.new("Text")
                }
                desenhos[player].box.Thickness = 2
                desenhos[player].box.Filled = false
                desenhos[player].box.Transparency = 0.6
                desenhos[player].label.Size = 14
                desenhos[player].label.Center = true
                desenhos[player].label.Outline = true
                desenhos[player].label.OutlineColor = Color3.fromRGB(0, 0, 0)
            end

            local d = desenhos[player]

            if onScreen then
                local role = getRole(player)
                local cor, texto
                if role == "Murder" then
                    cor = COR_MURDER
                    texto = "🔪 MURDER"
                elseif role == "Sheriff" then
                    cor = COR_SHERIFF
                    texto = "🔫 SHERIFF"
                else
                    cor = COR_INOCENTE
                    texto = "👤 " .. player.Name
                end

                -- Caixa com tamanho dinâmico baseado na distância
                local dist = (Camera.CFrame.Position - root.Position).Magnitude
                local scale = math.clamp(400 / dist, 0.5, 2)
                local boxSize = Vector2.new(80 * scale, 160 * scale)
                local boxPos = Vector2.new(pos.X - boxSize.X / 2, pos.Y - boxSize.Y / 2)

                d.box.Size = boxSize
                d.box.Position = boxPos
                d.box.Color = cor
                d.box.Visible = true

                if estado.MostrarNomes then
                    d.label.Text = texto .. " | " .. math.floor(dist) .. "m"
                    d.label.Position = Vector2.new(pos.X, pos.Y - boxSize.Y / 2 - 22)
                    d.label.Color = cor
                    d.label.Visible = true
                else
                    d.label.Visible = false
                end
            else
                d.box.Visible = false
                d.label.Visible = false
            end
        else
            if desenhos[player] then
                pcall(function()
                    desenhos[player].box:Remove()
                    desenhos[player].label:Remove()
                end)
                desenhos[player] = nil
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if desenhos[player] then
        pcall(function()
            desenhos[player].box:Remove()
            desenhos[player].label:Remove()
        end)
        desenhos[player] = nil
    end
end)

-- ============================
-- MENU GRÁFICO COM ABAS (UI)
-- ============================
local menuAberto = false

-- Criar a GUI principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SonionMM2Hub"
screenGui.Parent = PlayerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 380)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.fromRGB(60, 60, 80)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- Arredondamento (usando Corner)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Título
local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0, 35)
titulo.Position = UDim2.new(0, 0, 0, 0)
titulo.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
titulo.BackgroundTransparency = 0.2
titulo.BorderSizePixel = 0
titulo.Text = "⚡ SONION HUB v2.0 ⚡"
titulo.TextColor3 = Color3.fromRGB(255, 200, 50)
titulo.TextSize = 18
titulo.Font = Enum.Font.GothamBold
titulo.Parent = mainFrame

-- Barra de abas (buttons)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.Position = UDim2.new(0, 0, 0, 35)
tabBar.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
tabBar.BackgroundTransparency = 0.3
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local function criarAba(nome, texto, posX)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 1, -6)
    btn.Position = UDim2.new(0, posX, 0, 3)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.BackgroundTransparency = 0.4
    btn.BorderSizePixel = 0
    btn.Text = texto
    btn.TextColor3 = Color3.fromRGB(200, 200, 220)
    btn.TextSize = 14
    btn.Font = Enum.Font.Gotham
    btn.Name = nome
    btn.Parent = tabBar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    return btn
end

local abaESP = criarAba("ESP", "📡 ESP", 10)
local abaAimbot = criarAba("Aimbot", "🎯 Aimbot", 120)
local abaCombat = criarAba("Combat", "⚔️ Combat", 230)
local abaInfo = criarAba("Info", "ℹ️ Info", 340)

-- Container para o conteúdo das abas
local contentContainer = Instance.new("Frame")
contentContainer.Size = UDim2.new(1, -20, 1, -95)
contentContainer.Position = UDim2.new(0, 10, 0, 80)
contentContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
contentContainer.BackgroundTransparency = 0.2
contentContainer.BorderSizePixel = 0
contentContainer.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 6)
contentCorner.Parent = contentContainer

-- Função para criar toggles dentro das abas
local function criarToggle(container, texto, posY, callback, corFundo)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.Position = UDim2.new(0, 10, 0, posY)
    frame.BackgroundColor3 = corFundo or Color3.fromRGB(40, 40, 60)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = texto
    label.TextColor3 = Color3.fromRGB(220, 220, 240)
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 80, 0, 28)
    toggleBtn.Position = UDim2.new(0.85, -80, 0.5, -14)
    toggleBtn.BackgroundColor3 = callback() and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = callback() and "✅ ON" or "❌ OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 13
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = frame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 4)
    toggleCorner.Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        local newState = not callback()
        toggleBtn.BackgroundColor3 = newState and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
        toggleBtn.Text = newState and "✅ ON" or "❌ OFF"
        callback(newState)
    end)

    return toggleBtn
end

-- Criar Slider para FOV
local function criarSlider(container, texto, posY, min, max, valorInicial, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 45)
    frame.Position = UDim2.new(0, 10, 0, posY)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0.5, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = texto .. " (" .. tostring(valorInicial) .. ")"
    label.TextColor3 = Color3.fromRGB(220, 220, 240)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(0.5, 0, 0.3, 0)
    slider.Position = UDim2.new(0.45, 0, 0.6, 0)
    slider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    slider.BorderSizePixel = 0
    slider.Parent = frame

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = slider

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((valorInicial - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    fill.BorderSizePixel = 0
    fill.Parent = slider

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill

    local drag = Instance.new("TextButton")
    drag.Size = UDim2.new(0, 20, 1.5, 0)
    drag.Position = UDim2.new((valorInicial - min) / (max - min) - 0.02, 0, -0.25, 0)
    drag.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    drag.BorderSizePixel = 0
    drag.Text = ""
    drag.Parent = slider

    local dragCorner = Instance.new("UICorner")
    dragCorner.CornerRadius = UDim.new(1, 0)
    dragCorner.Parent = drag

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.1, 0, 0.5, 0)
    valueLabel.Position = UDim2.new(0.85, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(valorInicial)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextSize = 14
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Parent = frame

    local dragging = false
    drag.MouseButton1Down:Connect(function()
        dragging = true
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    RunService.RenderStepped:Connect(function()
        if dragging then
            local mousePos = UserInputService:GetMouseLocation().X
            local sliderAbsPos = slider.AbsolutePosition.X
            local sliderWidth = slider.AbsoluteSize.X
            local relativeX = math.clamp((mousePos - sliderAbsPos) / sliderWidth, 0, 1)
            local newVal = math.floor(min + relativeX * (max - min))
            valueLabel.Text = tostring(newVal)
            fill.Size = UDim2.new(relativeX, 0, 1, 0)
            drag.Position = UDim2.new(relativeX - 0.02, 0, -0.25, 0)
            callback(newVal)
            label.Text = texto .. " (" .. tostring(newVal) .. ")"
        end
    end)

    return slider
end

-- ============================
-- CONTEÚDO DAS ABAS
-- ============================

-- ABA ESP
local espContainer = Instance.new("ScrollingFrame")
espContainer.Size = UDim2.new(1, 0, 1, 0)
espContainer.BackgroundTransparency = 1
espContainer.BorderSizePixel = 0
espContainer.CanvasSize = UDim2.new(0, 0, 0, 120)
espContainer.ScrollBarThickness = 4
espContainer.Name = "ESP"
espContainer.Parent = contentContainer

criarToggle(espContainer, "Ativar ESP", 10, function(val)
    if val ~= nil then estado.ESP = val end
    return estado.ESP
end, Color3.fromRGB(60, 40, 40))

criarToggle(espContainer, "Mostrar Nomes", 60, function(val)
    if val ~= nil then estado.MostrarNomes = val end
    return estado.MostrarNomes
end, Color3.fromRGB(40, 40, 60))

-- ABA AIMBOT
local aimbotContainer = Instance.new("ScrollingFrame")
aimbotContainer.Size = UDim2.new(1, 0, 1, 0)
aimbotContainer.BackgroundTransparency = 1
aimbotContainer.BorderSizePixel = 0
aimbotContainer.CanvasSize = UDim2.new(0, 0, 0, 220)
aimbotContainer.ScrollBarThickness = 4
aimbotContainer.Name = "Aimbot"
aimbotContainer.Visible = false
aimbotContainer.Parent = contentContainer

criarToggle(aimbotContainer, "Ativar Aimbot", 10, function(val)
    if val ~= nil then estado.Aimbot = val end
    return estado.Aimbot
end, Color3.fromRGB(40, 40, 60))

criarToggle(aimbotContainer, "Mira Suave (Lerp)", 60, function(val)
    if val ~= nil then estado.Suave = val end
    return estado.Suave
end, Color3.fromRGB(40, 60, 40))

criarSlider(aimbotContainer, "FOV (Ângulo)", 110, 30, 360, estado.FOV, function(val)
    estado.FOV = val
end)

-- ABA COMBAT
local combatContainer = Instance.new("ScrollingFrame")
combatContainer.Size = UDim2.new(1, 0, 1, 0)
combatContainer.BackgroundTransparency = 1
combatContainer.BorderSizePixel = 0
combatContainer.CanvasSize = UDim2.new(0, 0, 0, 100)
combatContainer.ScrollBarThickness = 4
combatContainer.Name = "Combat"
combatContainer.Visible = false
combatContainer.Parent = contentContainer

criarToggle(combatContainer, "God Mode (Imune a facada)", 10, function(val)
    if val ~= nil then estado.GodMode = val end
    return estado.GodMode
end, Color3.fromRGB(40, 40, 60))

-- ============================
-- ABA INFO E RESTANTE DO CÓDIGO
-- ============================
local infoContainer = Instance.new("ScrollingFrame")
infoContainer.Size = UDim2.new(1, 0, 1, 0)
infoContainer.BackgroundTransparency = 1
infoContainer.BorderSizePixel = 0
infoContainer.CanvasSize = UDim2.new(0, 0, 0, 150)
infoContainer.ScrollBarThickness = 4
infoContainer.Name = "Info"
infoContainer.Visible = false
infoContainer.Parent = contentContainer

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, -20, 0.5, 0)
infoText.Position = UDim2.new(0, 10, 0, 10)
infoText.BackgroundTransparency = 1
infoText.Text = [[
⚡ Sonion Hub v2.0 ⚡

Desenvolvido por: DAN
Versão: 2.0 (Estável)

Funções:
- ESP com cores por papel
- Aimbot automático (Murder⇄Sheriff)
- God Mode (anti-facada)
- Menu com abas (Insert)

Dica: Ajuste o FOV para maior precisão.
]]
infoText.TextColor3 = Color3.fromRGB(200, 200, 220)
infoText.TextSize = 14
infoText.Font = Enum.Font.Gotham
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.Parent = infoContainer

-- ============================
-- CONTROLE DAS ABAS (VISIBILIDADE)
-- ============================
local function selecionarAba(nome)
    espContainer.Visible = (nome == "ESP")
    aimbotContainer.Visible = (nome == "Aimbot")
    combatContainer.Visible = (nome == "Combat")
    infoContainer.Visible = (nome == "Info")

    -- Efeito visual nos botões
    for _, btn in ipairs(tabBar:GetChildren()) do
        if btn:IsA("TextButton") then
            btn.BackgroundColor3 = (btn.Name == nome) and Color3.fromRGB(70, 70, 120) or Color3.fromRGB(40, 40, 60)
            btn.TextColor3 = (btn.Name == nome) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 220)
        end
    end
end

abaESP.MouseButton1Click:Connect(function() selecionarAba("ESP") end)
abaAimbot.MouseButton1Click:Connect(function() selecionarAba("Aimbot") end)
abaCombat.MouseButton1Click:Connect(function() selecionarAba("Combat") end)
abaInfo.MouseButton1Click:Connect(function() selecionarAba("Info") end)

-- Abre a primeira aba por padrão
selecionarAba("ESP")

-- ============================
-- TECLA PARA ABRIR/FECHAR MENU
-- ============================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.MenuKey then
        menuAberto = not menuAberto
        mainFrame.Visible = menuAberto
    end
end)

-- ============================
-- LIMPEZA QUANDO O SCRIPT PARAR
-- ============================
LocalPlayer.CharacterAdded:Connect(function()
    -- Reaplica God Mode se estiver ativo
    task.wait(0.5)
    local newChar = LocalPlayer.Character
    if newChar then
        local newHum = newChar:FindFirstChild("Humanoid")
        if newHum and estado.GodMode then
            newHum.Health = 100
        end
    end
end)

print("✅ Sonion MM2 Hub carregado com sucesso! Pressione INSERT para abrir o menu.")
