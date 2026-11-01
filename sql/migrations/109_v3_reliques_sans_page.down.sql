-- Rend aux reliques la page héritée de leur objet d'origine.
USE acore_world;
UPDATE item_template i JOIN solazeroth_v3_reliques_pages p ON p.entry = i.entry SET i.PageText = p.PageText,
i.PageMaterial = p.PageMaterial;
DROP TABLE solazeroth_v3_reliques_pages;
