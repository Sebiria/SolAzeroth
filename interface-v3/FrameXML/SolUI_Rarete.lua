-- Sol'Azeroth v3 (03/11/2026, demande de l'utilisateur) : toute icône d'objet est encadrée à la couleur de sa rareté.
-- Nos fenêtres posent leur cadre elles-mêmes (S.ContourRarete et S.Rarete, SolUI_Base.lua) ; ici, les fenêtres du jeu
-- encore utilisées : marchand, butin, banque et sacs du jeu, échange, courrier.

local S = SolUI

local contours = {}
local function Teinter(bouton, qualite)
    if not bouton then return end
    local c = contours[bouton]
    if not c then
        c = S.ContourRarete(bouton, _G[bouton:GetName() .. "IconTexture"] or bouton)
        contours[bouton] = c
    end
    S.Rarete(c, qualite)
end

local function QualiteLien(lien)
    return lien and select(3, GetItemInfo(lien)) or nil
end

-- Marchand
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
        Teinter(_G["MerchantItem" .. i .. "ItemButton"], index <= GetMerchantNumItems()
            and QualiteLien(GetMerchantItemLink(index)) or nil)
    end
end)
hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
    for i = 1, BUYBACK_ITEMS_PER_PAGE do
        Teinter(_G["MerchantItem" .. i .. "ItemButton"], QualiteLien(GetBuybackItemLink(i)))
    end
end)

-- Butin
hooksecurefunc("LootFrame_Update", function()
    for i = 1, LOOTFRAME_NUMBUTTONS do
        local bouton = _G["LootButton" .. i]
        local qualite = bouton:IsShown() and bouton.slot and select(4, GetLootSlotInfo(bouton.slot))
        Teinter(bouton, qualite or nil)
    end
end)

-- Banque et sacs du jeu (sacs de la banque)
hooksecurefunc("BankFrameItemButton_Update", function(bouton)
    if bouton.isBag then return end
    Teinter(bouton, select(4, GetContainerItemInfo(BANK_CONTAINER, bouton:GetID())))
end)
hooksecurefunc("ContainerFrame_Update", function(cadre)
    local sac = cadre:GetID()
    for i = 1, cadre.size do
        local bouton = _G[cadre:GetName() .. "Item" .. i]
        Teinter(bouton, select(4, GetContainerItemInfo(sac, bouton:GetID())))
    end
end)

-- Échange
hooksecurefunc("TradeFrame_UpdatePlayerItem", function(id)
    Teinter(_G["TradePlayerItem" .. id .. "ItemButton"], select(4, GetTradePlayerItemInfo(id)))
end)
hooksecurefunc("TradeFrame_UpdateTargetItem", function(id)
    Teinter(_G["TradeRecipientItem" .. id .. "ItemButton"], select(4, GetTradeTargetItemInfo(id)))
end)

-- Courrier : pièces jointes reçues et envoyées
hooksecurefunc("OpenMail_Update", function()
    if not InboxFrame.openMailID then return end
    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        Teinter(_G["OpenMailAttachmentButton" .. i], QualiteLien(GetInboxItemLink(InboxFrame.openMailID, i)))
    end
end)
hooksecurefunc("SendMailFrame_Update", function()
    for i = 1, ATTACHMENTS_MAX_SEND do
        Teinter(_G["SendMailAttachment" .. i], QualiteLien(GetSendMailItemLink(i)))
    end
end)
