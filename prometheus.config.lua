-- Prometheus obfuscation config — Jump Hub build
-- Pipeline: Minify (rename + minify only, Steps = {}), no VM / no bytecode steps.
-- NameGenerator "Chemical": locals are renamed to chemical formulas
-- (NaCl, H2SO4, C6H12O6, ...; later ones get a _<n> suffix for uniqueness).
-- LuaVersion is overridden to Luau by the --LuaU CLI flag.
return {
	LuaVersion = "Lua51",
	VarNamePrefix = "",
	NameGenerator = "Chemical",
	PrettyPrint = false,
	Seed = 0,
	Steps = {},
}
