-- Rend aux trois primes leurs réglages d'origine.
USE acore_world;
UPDATE creature_template t JOIN solazeroth_v3_primes_origine o ON o.entry = t.entry SET t.minlevel = o.minlevel, t.maxlevel = o.maxlevel, t.HealthModifier = o.HealthModifier, t.DamageModifier = o.DamageModifier;
DROP TABLE solazeroth_v3_primes_origine;
