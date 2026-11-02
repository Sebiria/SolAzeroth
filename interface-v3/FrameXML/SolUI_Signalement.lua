-- Sol'Azeroth v3 (01/11/2026, demande de l'utilisateur) : signaler un bug en jeu, pour les traiter tous ensemble.
-- La touche « ! » (réglable dans Techniques et raccourcis, ou /bug) fait noter au serveur la position du personnage et
-- sa cible à cet instant (.signaler debut, v3_signalement.cpp), puis ouvre une fenêtre pour décrire le problème.
-- Envoyer (ou Entrée) transmet le texte par morceaux (une ligne de discussion fait 255 caractères au plus).
-- Version publique (02/11/2026) : « Exporter » fait écrire au lanceur un fichier .txt des signalements en attente,
-- à envoyer au développeur (fenêtre Windows « Enregistrer sous ») ; /bug liste les montre. Nombre : message SOLSIGNAL.

local S = SolUI

local MORCEAU = 200

local f = S.Fenetre("SolUISignalement", 620, 340, "Signaler un bug")

local ou = S.Texte(f, "Regular", 13, "gris")
ou:SetPoint("TOPLEFT", 24, -62)
ou:SetPoint("RIGHT", -24, 0)
ou:SetJustifyH("LEFT")

local cadre = CreateFrame("Frame", nil, f)
cadre:SetPoint("TOPLEFT", 24, -90)
cadre:SetPoint("BOTTOMRIGHT", -24, 76)
cadre:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
cadre:SetBackdropColor(S.Couleur("creux"))
cadre:SetBackdropBorderColor(S.Couleur("bord"))
cadre:EnableMouse(true)

local champ = CreateFrame("EditBox", "SolUISignalementTexte", cadre)
champ:SetPoint("TOPLEFT", 12, -10)
champ:SetPoint("TOPRIGHT", -12, -10)
champ:SetHeight(150)
champ:SetMultiLine(true)
champ:SetMaxLetters(2000)
champ:SetAutoFocus(false)
S.Police(champ, "Regular", 14)
champ:SetTextColor(S.Couleur("clair"))
cadre:SetScript("OnMouseDown", function() champ:SetFocus() end)

local indice = S.Texte(cadre, "Regular", 14, "gris")
indice:SetPoint("TOPLEFT", 12, -10)
indice:SetText("Ce qui ne va pas, ce que tu faisais…")

local aide = S.Texte(f, "Regular", 12, "gris")
aide:SetPoint("BOTTOMLEFT", 24, 60)
aide:SetText("Entrée : envoyer.  Échap : annuler.")

local envoyer = S.BoutonPlat(f, "Envoyer", 140, 36)
envoyer:SetPoint("BOTTOMRIGHT", -24, 22)
local annuler = S.BoutonPlat(f, "Annuler", 120, 36)
annuler:SetPoint("RIGHT", envoyer, "LEFT", -10, 0)
local exporter = S.BoutonPlat(f, "Exporter", 170, 36)
exporter:SetPoint("BOTTOMLEFT", 24, 22)

local enAttente = 0
local function MajAttente()
    exporter.texte:SetText(enAttente > 0 and ("Exporter (" .. enAttente .. ")") or "Exporter")
    S.Montrer(exporter, enAttente > 0)
end
MajAttente()
S.Message("SOLSIGNAL", function(champs)
    if champs[1] == "N" then
        enAttente = tonumber(champs[2]) or 0
        MajAttente()
    end
end)

local function Envoyer()
    local texte = (champ:GetText() or ""):gsub("|", "/"):gsub("[\r\n]+", " / "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if texte == "" then return end
    local morceau = ""
    for mot in texte:gmatch("%S+") do
        if #morceau + #mot + 1 > MORCEAU and morceau ~= "" then
            SendChatMessage(".signaler texte " .. morceau, "SAY")
            morceau = ""
        end
        morceau = morceau == "" and mot:sub(1, MORCEAU) or (morceau .. " " .. mot)
    end
    if morceau ~= "" then SendChatMessage(".signaler texte " .. morceau, "SAY") end
    SendChatMessage(".signaler fin", "SAY")
    champ:SetText("")
    f:Hide()
end

champ:SetScript("OnEnterPressed", Envoyer)
champ:SetScript("OnEscapePressed", function() f:Hide() end)
champ:SetScript("OnTextChanged", function(self) S.Montrer(indice, (self:GetText() or "") == "") end)
envoyer:SetScript("OnClick", Envoyer)
annuler:SetScript("OnClick", function() f:Hide() end)
exporter:SetScript("OnClick", function()
    SendChatMessage(".signaler exporter", "SAY")
    f:Hide()
end)
f:HookScript("OnHide", function() champ:ClearFocus() end)

-- La touche qui ouvre la fenêtre arrive aussi comme caractère dans le champ : effacé à l'image suivante.
local nettoyage = CreateFrame("Frame", nil, f)
nettoyage:Hide()
nettoyage:SetScript("OnUpdate", function(self)
    self:Hide()
    local t = champ:GetText() or ""
    if #t <= 1 and t:match("^%p?$") then champ:SetText("") end
end)

function S.Signaler()
    if f:IsShown() then f:Hide(); return end
    SendChatMessage(".signaler debut", "SAY")
    SetMapToCurrentZone()
    local x, y = GetPlayerMapPosition("player")
    local lieu = GetRealZoneText() or ""
    local sous = GetSubZoneText() or ""
    if sous ~= "" and sous ~= lieu then lieu = lieu .. " — " .. sous end
    if x and (x > 0 or y > 0) then lieu = string.format("%s (%.1f ; %.1f)", lieu, x * 100, y * 100) end
    local cible = UnitName("target")
    ou:SetText("Position notée : " .. lieu .. (cible and ("  ·  cible : " .. cible) or ""))
    champ:SetText("")
    f:Show()
    champ:SetFocus()
    nettoyage:Show()
end

-- Bouton invisible pour la touche (« CLICK SolUISignaler:LeftButton »).
local bouton = CreateFrame("Button", "SolUISignaler", UIParent)
bouton:SetSize(1, 1)
bouton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
bouton:SetAlpha(0)
bouton:EnableMouse(false)
bouton:SetScript("OnClick", function() S.Signaler() end)

SLASH_SOLUISIGNALER1 = "/bug"
SlashCmdList.SOLUISIGNALER = function(argument)
    argument = (argument or ""):lower():match("^%s*(.-)%s*$")
    if argument == "liste" then
        SendChatMessage(".signaler liste", "SAY")
    elseif argument == "exporter" then
        SendChatMessage(".signaler exporter", "SAY")
    else
        S.Signaler()
    end
end

-- Première connexion : « ! » signale un bug, si la touche est libre.
local fait = false
S.Ecouter("PLAYER_ENTERING_WORLD", function()
    if fait then return end
    fait = true
    if not GetBindingKey("CLICK SolUISignaler:LeftButton") and (GetBindingAction("!") or "") == "" then
        SetBindingClick("!", "SolUISignaler")
        SaveBindings(GetCurrentBindingSet())
    end
end)
