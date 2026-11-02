-- Sol'Azeroth : réglages gardés pour le compte (SolAzerothDB), noms des objets, démarrage de l'interface v3.
-- Lot 6c (02/11/2026) : la fenêtre dorée « /sol » (V7) est retirée ; ses réglages sont le carnet Réglages de
-- l'interface (Interface\FrameXML\SolUI_Options.lua), qui reprend aussi la commande « /sol ».

------------------------------------------------------------------------
-- Noms des objets, pour tous les addons Sol'Azeroth. Le jeu ne connaît le nom d'un objet qu'après l'avoir demandé
-- au serveur, un par un et lentement : les fenêtres affichaient « Objet 862 ». Les noms manquants sont demandés
-- par paquets (commande .solnoms) et gardés d'une session à l'autre.
------------------------------------------------------------------------
local nomsDemandes, aDemander = {}, {}

function SolAzerothNomObjet(id)
    id = tonumber(id)
    if not id then return nil end
    local nom = GetItemInfo(id)
    if nom then return nom end
    local memoire = SolAzerothDB and SolAzerothDB.noms
    if memoire and memoire[id] then return memoire[id] end
    if not nomsDemandes[id] then
        nomsDemandes[id] = true
        aDemander[#aDemander + 1] = id
    end
    return nil
end

local demandeNoms = CreateFrame("Frame")
local attenteNoms = 0
demandeNoms:SetScript("OnUpdate", function(self, ecoule)
    attenteNoms = attenteNoms + ecoule
    if attenteNoms < 0.3 or #aDemander == 0 then return end
    attenteNoms = 0
    local paquet = {}
    while #aDemander > 0 and #paquet < 30 do paquet[#paquet + 1] = table.remove(aDemander) end
    SendChatMessage(".solnoms " .. table.concat(paquet, ","), "SAY")
end)
demandeNoms:RegisterEvent("CHAT_MSG_ADDON")
demandeNoms:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe ~= "SolAzerothNoms" or not SolAzerothDB then return end
    SolAzerothDB.noms = SolAzerothDB.noms or {}
    for element in string.gmatch(message, "[^;]+") do
        local id, nom = element:match("^(%d+):(.*)$")
        if id then SolAzerothDB.noms[tonumber(id)] = nom end
    end
end)

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("ADDON_LOADED")
evenements:RegisterEvent("PLAYER_LOGIN")
evenements:RegisterEvent("ADDON_ACTION_BLOCKED")
evenements:RegisterEvent("ADDON_ACTION_FORBIDDEN")
evenements:SetScript("OnEvent", function(self, event, nom, fonction)
    if event == "ADDON_LOADED" then
        if nom ~= "SolAzeroth" then return end
        SolAzerothDB = SolAzerothDB or {}
        -- v3, F4 : disposition de l'écran de combat, reprise puis tenue à jour.
        if SolUI then
            SolUI.Appliquer(SolAzerothDB.interface)
            SolUI.surChangement = function(disposition) SolAzerothDB.interface = disposition end
        end
    elseif event == "PLAYER_LOGIN" then
        -- v3 : quêtes suivies de ce personnage, que le jeu oublie à la déconnexion (SolUI_Quetes.lua).
        if SolUI then
            SolAzerothDB.suivies = SolAzerothDB.suivies or {}
            local cle = UnitName("player") .. "-" .. GetRealmName()
            SolAzerothDB.suivies[cle] = SolAzerothDB.suivies[cle] or {}
            SolUI.QUETES_SUIVIES = SolAzerothDB.suivies[cle]
            SolUI.MajQuetes()
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        -- Mouchard : si l'erreur d'interface revient, le chat dit quel addon et quelle fonction l'ont causée.
        if nom and nom:find("^SolAzeroth") then
            print(string.format("|cffff6060Sol'Azeroth :|r action bloquée par le jeu (%s, %s). Signale-le.", nom, tostring(fonction)))
        end
    end
end)
