-- v3 (01/11/2026) : calibrage des primes A13, A16 et A17. Généré par outils\primes_v3.py : ne pas modifier
-- à la main.
USE acore_world;
CREATE TABLE IF NOT EXISTS solazeroth_v3_primes_origine SELECT entry, minlevel, maxlevel, HealthModifier, DamageModifier FROM creature_template WHERE entry IN (910021, 5822, 5824);
UPDATE creature_template SET minlevel = 11, maxlevel = 11, HealthModifier = 1.10, DamageModifier = 1.10 WHERE entry = 910021;
UPDATE creature_template SET minlevel = 11, maxlevel = 11, HealthModifier = 1.16, DamageModifier = 1.16 WHERE entry = 5822;
UPDATE creature_template SET minlevel = 11, maxlevel = 11, HealthModifier = 0.95, DamageModifier = 0.95 WHERE entry = 5824;
