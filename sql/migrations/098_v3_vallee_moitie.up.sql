-- v3 (01/11/2026, demande de l'utilisateur) : moitié moins de récolte dans la Vallée des Épreuves. Restent 5 filons
-- de cuivre (9100028 à 31 et 9100033) et 5 plantes (Pacifiques 9100036 et 41, Feuillargents 9100037 et 39,
-- Terrestrine 9100040), répartis dans la vallée.
USE acore_world;
DELETE FROM gameobject WHERE guid IN (9100032, 9100038, 9100042, 9100043, 9100044, 9100045, 9100046, 9100047, 9100048, 9100049);
