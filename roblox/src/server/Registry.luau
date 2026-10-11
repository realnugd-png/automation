--!strict
-- Shared table the bootstrap fills with every service, so services can call
-- each other at runtime without circular requires.
local Registry: { [string]: any } = {}
return Registry
