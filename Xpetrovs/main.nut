// Libraries load
import("pathfinder.rail", "RailPathFinder", 1);
//import("graph.aystar", "AyStar", 6);

// Definition of class for AI module

class Xpetrovs extends AIController {
	
	// Class attributes definition
	mapCargos = null;
	pathFinder = null;
	
	// AI class constructor
	constructor() {
		// Set a rail type.
		local types = AIRailTypeList();
		AIRail.SetCurrentRailType(types.Begin());
		// Create a PathFinder object.
		this.pathFinder = RailPathFinder();
	}
}


// Definition of methods for AI module

// Main function for AI
function Xpetrovs::Start()
{
	// Check settings
	if (AIGameSettings.GetValue("pf.forbid_90_deg") == 1) {
		AILog.Warning("Toto AI nemusi fungovat spravne, pokud je v nastaveni zakazano zataceni vlaku v uhlu 90�.");
		AILog.Warning("Advanced Settings -> Vehicles -> Routing -> check off Forbid trains and ships from making 90� turns");
		return;
	}
	// Remove all signs
	this.ClearSigns();
	
	// Set company name
	this.NameCompany("JontesRailCorp","J.P.");
	
	// Save all available cargos
	this.mapCargos = this.GetAvailableCargos();
	
	// Choose the best cargo to start with: COAL, IORE, OIL_
	local ok = this.CreateTrackForCargo("COAL");

	// Run forever
	while (true) {
		//AILog.Info("Ahoj vsichni! Provedl jsem " + "instrukci: " + this.GetTick());
		//this.Sleep(100);
	}
}

function Xpetrovs::CreateTrackForCargo(cargoName)
{
	// Get ID of the given cargo type.
	local cargoId = this.mapCargos[cargoName]; 
	// Get cargo sources and targets.
	local cargoPlaces = this.GetCargoPlaces(cargoName);
	// Choose suitable places.
	local sourceTile = AIIndustry.GetLocation(cargoPlaces[0].Begin());
	local consumerTile = AIIndustry.GetLocation(cargoPlaces[1].Begin());
	//this.UpdateSign(sourceTile, "START");
	//this.UpdateSign(consumerTile, "GOAL");
	// Find places for train stations.	
	local startTile = this.GetStationCorner(consumerTile, cargoId, true);
	local goalTile = this.GetStationCorner(sourceTile, cargoId, false);
	// Check if any places were found. If not, re-run the method.
	if ((startTile == null) || (goalTile == null)) {
		AILog.Info("Start: " + startTile + " Goal: " + goalTile);
		AILog.Warning("Cannot build a train station.");
		this.ClearSigns();
		return false;
	}
	// 
	local sources = [[startTile + 4, startTile + 3]];
	local goals = [[goalTile + 4, goalTile + 3]];
	// Add signs
	AISign.BuildSign(sources[0][0], "|Start|");
	AISign.BuildSign(goals[0][1], "|Finish|");
	// Find a path
	this.pathFinder.InitializePath(sources, goals);
	local path = this.pathFinder.FindPath(-1);
	if (path == null) {
		AILog.Warning("A path could not be found.");
		return;
	}
	else {
		AILog.Info("A path was found.");	
	}
	// Build train stations
  	AIRail.BuildRailStation(startTile, AIRail.RAILTRACK_NE_SW, 1, 4, AIStation.STATION_NEW);
  	AIRail.BuildRailStation(goalTile, AIRail.RAILTRACK_NE_SW, 1, 4, AIStation.STATION_NEW);
	// Link to the source station
	local prev = path.GetParent().GetTile();
	local prevprev = path.GetTile();
	local ret = AIRail.BuildRail(prev, prevprev, goalTile + 3);
	/* Going through link list of the path - we start from the path end.
	   Meanwhile building rails, bridges or tunnels :).
	*/
	local prev = null;
	local prevprev = null;
	local fullPath = path;
	while (path != null) {
	  if (prevprev != null) {
	    if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
	      if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
	        AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev);
	      } else {
	        local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
	        bridge_list.Valuate(AIBridge.GetMaxSpeed);
	        bridge_list.Sort(AIList.SORT_BY_VALUE, false);
	        AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_list.Begin(), prev, path.GetTile());
	      }
	      prevprev = prev;
	      prev = path.GetTile();
	      path = path.GetParent();
	    } else {
	      AIRail.BuildRail(prevprev, prev, path.GetTile());
	    }
	  }
	  if (path != null) {
	    prevprev = prev;
	    prev = path.GetTile();
	    path = path.GetParent();
	  }
	}
	// Link to the consumer station
	ret = AIRail.BuildRail(prevprev, prev, startTile + 3) && ret;
	this.ClearSigns();
  	// Build a depo
  	local depot = this.BuildDepot(fullPath.GetParent());
	if (depot == null) {
		AILog.Warning("A depot could not be built.");
		this.ClearSigns();
		return;
	}
	else {
		AILog.Info("A depot was built.");	
	}
	// Create train (engine, wagons) and start the train.
	local train = this.CreateTrain(depot, cargoId, startTile, goalTile);
	  	
}

function Xpetrovs::CreateTrain(depot, cargoId, startTile, goalTile)
{
	// seznam vsech kolejovych vozidel (vagony i lokomotivy)
	local engList = AIEngineList(AIVehicle.VT_RAIL);
	
	// vsem polozkam se priradi true, pokud jsou to vagony; false pokud to vagony nejsou
    engList.Valuate(AIEngine.IsWagon);
	// ponechame v seznamu pouze polozky, ktere maji true (jsou vagony)
    engList.KeepValue(1);
    
    engList.Valuate(AIEngine.IsBuildable);
	// ponechame v seznamu jen vagony, ktere lze postavit
   	engList.KeepValue(1);

	// vsem polozkam seznamu se priradi true, pokud je mozne je pouzit pro prepravu daneho Carga
    engList.Valuate(AIEngine.CanRefitCargo, cargoId);
	engList.KeepValue(1);

	// vsem polozkam se priradi jako hodnoceni kapacita vagonu
	engList.Valuate(AIEngine.GetCapacity);
	// seradime od nejvetsiho
	engList.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
	// vybereme polozku, ktera ma nejvetsi kapacitu
    engList.KeepTop(1);
	// tento typ wagonu budeme pouzivat
	local wagonType = engList.Begin();
	

	// seznam vsech kolejovych vozidel
	engList = AIEngineList(AIVehicle.VT_RAIL);
	engList.Valuate(AIEngine.IsWagon);
	// ponechame polozky, ktere nejsou vagony
	engList.KeepValue(0);

	engList.Valuate(AIEngine.GetPrice);
	// seradime podle ceny od nejlevnejsi
	engList.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
	// nechame dve nejlevnejsi a odstranime prvni - zustane nam druha nejlevnejsi
	engList.KeepTop(2);
    engList.RemoveTop(1);
	local engineType = engList.Begin();

	// postavime lokomotivu
	local train = AIVehicle.BuildVehicle(depot, engineType);

	local ret = AIVehicle.IsValidVehicle(train);
	
	// postavime 5 vagonu
	for (local i = 0; i < 6; i++) {
	    local wagon = AIVehicle.BuildVehicle(depot, wagonType);
		ret = AIVehicle.IsValidVehicle(wagon) && ret;
		// pripoji vagony k vlaku
		ret = AIVehicle.MoveWagon(wagon, 0, train, 0) && ret;
	}
	
	// nastaveni jizdniho radu
	ret = AIOrder.AppendOrder(train, goalTile, AIOrder.AIOF_FULL_LOAD_ANY) && ret;
	ret = AIOrder.AppendOrder(train, startTile, AIOrder.AIOF_NONE) && ret;

	// pusteni vlaku
	ret = AIVehicle.StartStopVehicle(train) && ret;

	if (ret) {
		AILog.Info("Vlak byl postaven a spusten bez chyb.");
	} else {
		AILog.Warning("Pri staveni vlaku doslo k chybe.");
		this.ClearSigns();
		return;
	}
	
}


// Get all available (on the current map) cargo types.
function Xpetrovs::GetAvailableCargos()
{
	// Associative array = table, key/value pair = slot
	local tableCargos = {}
	foreach(idx, dummy in AICargoList()) {
		tableCargos[AICargo.GetCargoLabel(idx)] <- idx;
		//AILog.Info(idx + ": " + AICargo.GetCargoLabel(idx));	
	}
	return tableCargos;
}

// Get sources and targets for given cargo type.
function Xpetrovs::GetCargoPlaces(/*String*/ cargoName)
{
	// Get ID of the given cargo label.
	local cargoId = this.mapCargos[cargoName]
	
	// Get sources - i.e. coal mine
	local listSources = AIIndustryList_CargoProducing(cargoId);
	
	// Get targets - i.e. powerplant
	local listTargets = AIIndustryList_CargoAccepting(cargoId);
	
	// Add labels to sources
	foreach(idx, dummy in listSources) {
		local ppTile = AIIndustry.GetLocation(idx);
		//this.UpdateSign(ppTile, cargoName + " source");
	}
	
	// Add labels to targets
	foreach(idx, dummy in listTargets) {
		local ppTile = AIIndustry.GetLocation(idx);
		//this.UpdateSign(ppTile, cargoName + " target");
	}
	
	// return lists
	local a = [listSources, listTargets];
	return a;
}

function Xpetrovs::NameCompany(strName, strPresident)
{
	if (!AICompany.SetName(strName)) {
	    local i = 2;
	    while (!AICompany.SetName(strName + " #" + i)) {
	    	i = i + 1;
	    	if(i > 255) break;
	    }
  	}	
  	AICompany.SetPresidentName(strPresident);
}

// FUNCTIONS FROM MR. POPELKA

// funkce volana pri ukladani hry
function Xpetrovs::Save() {
	return {};
}

function Xpetrovs::GetStationCorner(baseTile, cargoId, accept) {
	// zastavka bude postavena vodorovne, bude mit delku 4 a vysku 1
	local data = {};
	data.width <- 4;
	data.height <- 1;
	data.accept <- accept;
	data.cargoId <- cargoId;
	AISign.BuildSign(baseTile, "Hledam v okoli");
	AIController.Sleep(50);
	// dosah zastavky
	data.radius <- AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	local tile = this.SpiralWalker(baseTile, this._spiralTerminate, this._spiralAbort, data);

	// odstranime cedulky umistene pri spiralovem prohledavani
	foreach (idx, dSign in AISignList()) {
		AISign.RemoveSign(idx);
	}

	if (tile != null) {
		AISign.BuildSign(tile, "Zde bude zastavka");
	}
	return tile;
}

function Xpetrovs::SpiralWalker(baseTile, terminateCallback, abortCallback, data) {
	local tile = baseTile;
	local offsets = [1, // posun na ose X doleva
        AIMap.GetMapSizeX(), // posun na ose Y dolů
		-1, // posun na ose X doprava
		-AIMap.GetMapSizeX() // posun na ose Y nahoru
		];
	local offsetIndex = 0;
	local multiplier = 1;
  	local dcounter = 1;
	local step = 0;
	while (!terminateCallback(tile, data)) {
		tile = tile + offsets[offsetIndex];
		dcounter--;
		if (dcounter == 0) {
			step++;
			offsetIndex++;
			if (offsetIndex > 3) {
				offsetIndex = 0;
			}
			if (step % 2 == 0) {
				multiplier++;
			}
			dcounter = multiplier;
		}
		if (abortCallback(tile, data)) {
			return null;
		}
	}
	return tile;
}

/* Testuje, jestli je mozne na danem poli postavit zastavku.
*/
function Xpetrovs::_spiralTerminate(tile, data) {
	AISign.BuildSign(tile, "?");
	// +1 na policko pro vyjezd ze zastavky
	return AITile.IsBuildableRectangle(tile, data.width + 1, data.height);
}

/* Testuje, jestli je na danem poli jeste prijimano/produkovano zbozi.
*/
function Xpetrovs::_spiralAbort(tile, data) {
	// pokud uz neprijima nebo neprodukuje zbozi vrati false
	return ((data.accept && ((AITile.GetCargoAcceptance(tile, data.cargoId, data.width, data.height, data.radius)) < 8)) ||
		(!data.accept && (AITile.GetCargoProduction(tile, data.cargoId, data.width, data.height, data.radius)) < 1));
}


/* Postavi depo na zadane ceste. Na trati musi byt alespon
jedna svisla nebo vodorovna kolejnice.
Vrati tileIndex policka na kterem je depo postaveno nebo
	null, pokud se depo nepodarilo postavit.
*/
function Xpetrovs::BuildDepot(/* AyStar.Path */ path) {
	local current = path;
	local depot = null;
	while (current != null) {
		local cti = current.GetTile();
	    local rt = AIRail.GetRailTracks(cti);
		if ((rt & AIRail.RAILTRACK_NE_SW) > 0) {
	        //nahoru od vodorovne
		    if (AIRail.BuildRailDepot(cti - AIMap.GetMapSizeX(), cti)) {
				AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_NW_NE);
				AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_NW_SW);
				depot = cti - AIMap.GetMapSizeX();
				break;
			} else {
			    //dolu od vodorovne
				if (AIRail.BuildRailDepot(cti + AIMap.GetMapSizeX(), cti)) {
					AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_NE_SE);
					AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_SW_SE);
					depot = cti + AIMap.GetMapSizeX();
					break;
				}
			}
		} else {
		    if ((rt & AIRail.RAILTRACK_NW_SE) > 0) {
		        //vpravo od svisle
		        if (AIRail.BuildRailDepot(cti - 1, cti)) {
					AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_NW_NE);
					AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_NE_SE);
					depot = cti - 1;
					break;
				} else {
				    //vlevo od svisle
			        if (AIRail.BuildRailDepot(cti + 1, cti)) {
						AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_NW_SW);
						AIRail.BuildRailTrack(cti, AIRail.RAILTRACK_SW_SE);
						depot = cti + 1;
						break;
					}
				}
			}
		}
	    current = current.GetParent();
	} //while - postaveni depa
	return depot;
}

/*
	odstraneni vsech popisek
*/
function Xpetrovs::ClearSigns() {
	foreach (idx, dSign in AISignList()) {
		AISign.RemoveSign(idx);
	}
}

/*
	prevod tileindexu na x,y
*/
function Xpetrovs::TileToXY(/*AITIle*/ tile) {
	local y = floor(tile / AIMap.GetMapSizeX());
	local x = tile - y * AIMap.GetMapSizeX();
	return [x, y];
}

/*
	zjistit, zda ma policko popisek
*/
function Xpetrovs::FindSign(/*AITile*/ tile) {
	foreach (idx, dSign in AISignList()) {
		if(tile == AISign.GetLocation(idx)) {
			return idx;
		}
	}
	return false;
}

/*
	rozsireni textu popisku
*/
function Xpetrovs::UpdateSign(/*AITile*/ tile, /*String*/ text) {
	local sign = this.FindSign(tile);
	if(!sign) {
		sign = AISign.BuildSign(tile, text);
	} else {
		AISign.SetName(sign, AISign.GetName(sign) + " " + text);
	}
}
