-- chemical.lua (Jump Hub build tool)
-- Prometheus name generator: names locals as chemical formulas
-- (NaCl, H2SO4, C6H12O6, ...). Unique per (index, round); every name is a
-- valid Lua identifier (starts with a letter, letters+digits only).

local FORMULAS = {
	"NaCl", "H2O", "CO2", "H2SO4", "C6H12O6", "NH3",
	"CH4", "C2H5OH", "CaCO3", "O2", "N2", "H2O2",
	"NaOH", "HCl", "NaHCO3", "CaO", "Fe2O3", "Al2O3",
	"SiO2", "SO2", "NO2", "CO", "KMnO4", "KCl",
	"Na2CO3", "C3H8", "C4H10", "C6H6", "CH3OH", "C2H4",
	"C2H2", "HNO3", "H3PO4", "Na2SO4", "K2SO4", "MgSO4",
	"CaSO4", "ZnSO4", "CuSO4", "FeSO4", "NaNO3", "KNO3",
	"CaCl2", "MgCl2", "FeCl3", "CuCl2", "AlCl3", "AgCl",
	"BaCl2", "NaF", "KI", "NaBr", "LiOH", "KOH",
	"Na2O", "K2O", "MgO", "CuO", "ZnO", "PbO2",
	"MnO2", "SO3", "P2O5", "N2O", "N2O5", "H2S",
	"PH3", "SiH4", "CCl4", "CHCl3", "CH2Cl2", "C6H5OH",
	"C7H8", "C10H8", "C2H4O", "C3H6O", "C4H8O", "C6H12",
	"C6H14", "C7H16", "C8H18", "CH3COOH", "CH3CHO", "HCOOH",
	"C12H22O11", "Fe3O4", "FeS2", "Cu2O", "Ag2O", "HgO",
	"TiO2", "SnO2", "PbS", "ZnS", "FeS", "Na2S",
	"K2S", "CaC2", "SiC", "BN", "AlN", "C2H5NH2",
	"C5H9NO4", "C9H13NO3", "C10H14N2", "C27H46O", "C8H10", "C4H8O2",
	"C3H6O2", "C2H4O2", "H2Se", "B2H6", "N2H4", "CS2",
	"FeCl2", "NiSO4", "BaSO4", "PbCl2", "CaF2", "BF3",
	"SF6", "CF4", "WO3", "MoS2", "KClO3", "NaClO",
	"SrSO4", "Sb2S3", "As2O3", "NiFe2O4"
};

local N = #FORMULAS;

return function(i, _, _)
	local q = math.floor(i / N);
	local name = FORMULAS[(i % N) + 1];
	if q > 0 then
		name = name .. "_" .. q;
	end
	return name;
end
