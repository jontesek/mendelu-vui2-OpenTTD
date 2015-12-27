// nacteni knihovny, musí byt mimo tridu
import("graph.aystar", "AyStar", 6);

class Katureel extends AIController
{
	aystar = null;
	stateCnt = 0;
  
	// constructor AI Modulu (zapisuje se dovnitr tridy)
	constructor()
	{
		/*
		instance
		cost callback
		estimate callback
		neighbours callback
		check_direction_callback
		*/
  		this.aystar = AyStar(this, this._cost, this._estimate, this._neighbours, this._directions);
	}
	
}

// Metody AI modulu (zapisuji se mimo tridu!)

// g() funkce A* algoritmu
function Katureel::_cost(/* Katureel */ self, /* Aystar.Path */ oldPath, /* TileIndex */ newTile, /* int */ newDirection)
{
	self.stateCnt++;
	if (oldPath != null) {
		local result = oldPath.GetLength();
		self.UpdateSign(newTile, "g() = " + result);
		return result;
	} else {
		return 1;
	}
}

// h() funkce A* algoritmu
function Katureel::_estimate(/* Katureel */ self, /* tileindex */ tile, /* int */ direction, /* array[tileindex, direction] */ goalNodes)
{
	//local result = AIMap.DistanceMax(tile, goalNodes[0][0]);
	local result = AIMap.DistanceManhattan(tile, goalNodes[0][0]);
	//local result = AIMap.DistanceSquare(tile, goalNodes[0][0]);
	
	// policko, kterym algoritmus prosel oznacime cedulkou,
	// aby bylo videt, co algoritmus dela
	self.UpdateSign(tile, "h() = " + result);
	return result;
}

// funkce pro generovani stavu
function Katureel::_neighbours(/* Katureel */ self, /* Aystar.Path */ currentPath, /* tileindex */ node)
{
	// posuny ve směru X, Y
	local offsets = [1, // posun na ose X doleva
		-1, // posun na ose X doprava
        AIMap.GetMapSizeX(), // posun na ose Y dolů
		-AIMap.GetMapSizeX() // posun na ose Y nahoru
		];
	local newTile;
	local result = [];

	// kazdy posun pricteme k aktualnimu TileIndexu
	// a dostaneme tak sousedy</span>
	foreach (offset in offsets) {
	    newTile = node + offset;
		// políčko není na svahu a je na něm možné stavět
	    if ((AITile.GetSlope(newTile) == AITile.SLOPE_FLAT) && AITile.IsBuildable(newTile)) {
		    result.push([newTile, 1]);
	    }
	}
	return result;
}

function Katureel::_directions(self, tile, existingDirection, newDirection)
{
	return false;
}

// Hlavni funkce AI
function Katureel::Start()
{
	if (AIGameSettings.GetValue("pf.forbid_90_deg") == 1) {
		AILog.Warning("Toto AI nemusi fungovat spravne, pokud je v nastaveni zakazano zataceni vlaku v uhlu 90°");
		AILog.Warning("Advanced Settings -> Vehicles -> Routing -> Forbid trains and ships from making 90° turns");
		return;
	}

	// budeme vozit uhli
	local coalCargo = this.GetCargoID("COAL");
	local powerPlant, coalMine, ppTile, cmTile;

	AILog.Info("Coal ID: " + coalCargo);
	try {
		/* Budeme vozit uhli mezi prvni elektrarnou a prvnim dolem, na ktere narazime.
    		Bohuzel volaní metody Begin() na prazdnem seznamu bohuzel vraci 0,
			coz muze byt platne ID tovarny. Musime tedy nejdriv zkontrolovat, ze
			jsou seznamy neprazdne, jinak bychom mohli dostat ID jine tovarny
		*/
		if (AIIndustryList_CargoAccepting(coalCargo).Count() > 0 &&
			AIIndustryList_CargoProducing(coalCargo).Count()) {
			powerPlant = AIIndustryList_CargoAccepting(coalCargo).Begin();
  			coalMine = AIIndustryList_CargoProducing(coalCargo).Begin();

			AILog.Info("PowerPlant ID: " + powerPlant);
			AILog.Info("CoalMine ID: " + coalMine);

			// zjistime polohu na mape
  			ppTile = AIIndustry.GetLocation(powerPlant);
			cmTile = AIIndustry.GetLocation(coalMine);

			AILog.Info("PowerPlant TileIndex: " + ppTile);
			AILog.Info("CoalMine TileIndex: " + cmTile);
		} else {
			throw "Nebyla nalezena elektrarna nebo dul";
		}
	} catch (e) {
		AILog.Warning("Nebylo nalezeno uhli, nebo dul, nebo elektrarna: " + e);
		return;
	}

	local start = this.GetStationCorner(ppTile, coalCargo, true);
	local goal = this.GetStationCorner(cmTile, coalCargo, false);

	if ((start == null) || (goal == null)) {
		AILog.Info("Start: " + start + " Goal: " + goal);
		AILog.Warning("Nelze postavit zastavky.");
		this.ClearSigns();
		return;
	}

	// protoze delka zastavky je 4, +4 se dostaneme na policko tesne pred zastavkou
	local sources = [[start + 4, 1]]; // smer neresime -> 1
	local goals = [[goal + 4, goal + 3]];

	AISign.BuildSign(sources[0][0], "|Start|");
	AISign.BuildSign(goals[0][1], "|Finish|");

  	this.aystar.InitializePath(sources, goals, []);
  	local path = false;
   	AILog.Info("Hledam cestu");
	local step = 0;
  	while (path == false) {
    	path = this.aystar.FindPath(100);
		step++;
	   	AILog.Info("Porad jeste hledam cestu");
		if (step == 100) {
			AILog.Warning("Prestalo me to bavit");
			this.ClearSigns();
			return;
		}
  	}
  	if (path != null) {
		AILog.Info("Cesta nalezena, delka: " + path.GetLength());
		AILog.Info("Prosel jsem " + this.stateCnt + " stavu.");

		// odstranime cedulky umistene pri prohledavani A*
		foreach (idx, dSign in AISignList()) {
			AISign.RemoveSign(idx);
		}

		// muzeme stavet - musime si vybrat typ zeleznice, jinak nelze stavet
		AIRail.SetCurrentRailType(AIRailTypeList().Begin());

 		//postavime zastavky
  		AIRail.BuildRailStation(start, AIRail.RAILTRACK_NE_SW, 1, 4, AIStation.STATION_NEW);
  		AIRail.BuildRailStation(goal, AIRail.RAILTRACK_NE_SW, 1, 4, AIStation.STATION_NEW);

		// projdeme spojovy seznam cesty - prochazeni zacina od konce cesty
	  	local current = path.GetParent().GetParent();
		local prev = path.GetParent().GetTile();
		local prevprev = path.GetTile();

		/* napojeni na zastavku u dolu - vime, ze zastavka je postavena
			vodorovne - potrebujeme dve policka cesty a jedno policko zastavky
			+ 3 protoze potrebujeme dolni levy roh zastavky a vime, ze zastavka
			je postavena vodorovne.
		*/
		local ret = AIRail.BuildRail(prev, prevprev, goal + 3);

		/* pomoci promenne ret testujeme jestli celkove doslo k nejakym chybam
			To neni prilis sofistikovane, protoze se alg. nesnazi chyby nejak opravit
			Jedna se spis o demostraci toho, kde vsude se mohou chyby objevit a jak je
			testovat. Jak se v pripade chyby zachovat, to je vec jina.
		*/

		while (current != null) {
			/*
			//Tedy precondition pro ladeni, pokud nefunguje staveni trate
			AILog.Info(AIRail.IsRailTypeAvailable(AIRail.GetCurrentRailType()));

			local from = prevprev;
			local tile = prev;
			local to = current.GetTile();
			if (from != to) {
				AILog.Info("t1 ok");
			} else {
				AILog.Info("t1 fail");
			}

			if (AIMap.DistanceManhattan(from, tile) == 1) {
				AILog.Info("t2 ok");
			} else {
				AILog.Info("t2 fail");
			}


 			if (AIMap.DistanceManhattan(to, tile) >= 1) {
				AILog.Info("t3 ok");
			} else {
				AILog.Info("t3 fail");
			}

			if ((abs(abs(AIMap.GetTileX(to) - AIMap.GetTileX(tile)) - abs(AIMap.GetTileY(to) - AIMap.GetTileY(tile))) <= 1) || (AIMap.GetTileX(from) == AIMap.GetTileX(tile) && AIMap.GetTileX(tile) == AIMap.GetTileX(to)) || (AIMap.GetTileY(from) == AIMap.GetTileY(tile) && AIMap.GetTileY(tile) == AIMap.GetTileY(to))) {
				AILog.Info("t4 ok");
			} else {
				AILog.Info("t4 fail");
			}
			*/

		    // BuildRail ma parametr From, Tile, To, funkce stavi na
			//  tileindexu zadanem v Tile
		    ret = AIRail.BuildRail(prevprev, prev, current.GetTile()) && ret;
			if (!ret) {
				AILog.Info(AIError.GetLastErrorString());
			}
			prevprev = prev;
			prev = current.GetTile();
			current = current.GetParent();
		}

		/* napojeni na zastavku u elektrarny, stejne jako u dolu
			v promennych prev a prevprev je tentokrat zacatek cesty */
		ret = AIRail.BuildRail(prevprev, prev, start + 3) && ret;

		// toto by se melo kontrolovat prubehu staveni a nejak opravit?
		if (ret) {
			AILog.Info("Cesta postavena bez chyb");
		} else {
			AILog.Warning("Nepovedlo se postavit cast cesty");
			this.ClearSigns();
			return;
		}

		local depot = this.BuildDepot(path);
		if (depot == null) {
			AILog.Warning("Nepodarilo se postavit depo");
			this.ClearSigns();
			return;
		}
		/* Tridy, ktere jsou odvozene od tridy AIList
			(http://noai.openttd.org/api/trunk/classAIList.html)
			reprezentuji vzdy nejake seznamy. Vyhledavat a vybirat
			ze seznamu se da pomoci metod Valuate() a
			KeepValue(), KeepTop() a podobne
			Prvnim parametrem metody Valuate() je callback funkce, ktera
				prijima jako prvni parametr polozku seznamu,
				dalsi parametry callbacku se predavaji funkci Valuate()
			Konkretne: AIEngineList (engList) je seznam vsech dostupnych
				(zeleznicnich) vozidel ve hre
			Seznam obsahuje IDcka vozidel (engineID)
			Funkce AIEngine.CanRefitCargo prijima jako prvni parametr engineID,
				lze ji tedy pouzit jako callback pro Valuate(),
				jako druhy parametr prijima cargoId. Tento druhy
				parametr tedy musime predat funkci Valuate, ktera ho
				preda funkci CanRefitCargo, kdyz ji bude volat pro
				kazdou polozku seznamu.
			Vysledek callbacku pro funkci Valuate musi byt integer (nebo boolean).
			vice zde http://noai.openttd.org/api/trunk/classAIList.html#e44c3d03c6a8a95e06d5220795b09b80
			Funkce Valuate priradi jednotlivym prvkum seznamu hodnoceni
			se kterym se da pracovat pomoci dalsich funkci KeepTop(), KeepValue(), ...
			Vyhoda valuatoru oproti prochazeni v cyklu je v tom, ze nespotrebovava
				Squirell instrukce a je celkove rychlejsi.
		*/

		// seznam vsech kolejovych vozidel (vagony i lokomotivy)
		local engList = AIEngineList(AIVehicle.VT_RAIL);

		// vsem polozkam se priradi true, pokud jsou to vagony; false pokud to vagony nejsou
	    engList.Valuate(AIEngine.IsWagon);
		// ponechame v seznamu pouze polozky, ktere maji true (jsou vagony)
	    engList.KeepValue(1);

	    engList.Valuate(AIEngine.IsBuildable);
		// ponechame v seznamu jen vagony, ktere lze postavit
    	engList.KeepValue(1);

		// vsem polozkam seznamu se priradi true, pokud je mozne je pouzit pro prepravu uhli
        engList.Valuate(AIEngine.CanRefitCargo, coalCargo);
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
		// seradime podle ceny od nejdrazsiho
		engList.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
		engList.KeepTop(2);
	    engList.RemoveTop(1);
		// nechame dve nejdrazsi a odstranime prvni - zustane nam druha nejlevnejsi
		local engineType = engList.Begin();

		// postavime lokomotivu
		local train = AIVehicle.BuildVehicle(depot, engineType);

		ret = AIVehicle.IsValidVehicle(train);
		// postavime 5 vagonu
		for (local i = 0; i < 8; i++) {
		    local wagon = AIVehicle.BuildVehicle(depot, wagonType);
			ret = AIVehicle.IsValidVehicle(wagon) && ret;
			// pripoji vagony k vlaku
			ret = AIVehicle.MoveWagon(wagon, 0, train, 0) && ret;

		}

		// nastaveni jizdniho radu
		ret = AIOrder.AppendOrder(train, goal, AIOrder.AIOF_FULL_LOAD_ANY) && ret;
		ret = AIOrder.AppendOrder(train, start, AIOrder.AIOF_NONE) && ret;

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
	
	this.ClearSigns();
	
	while (true) {
	}

}

// funkce volana pri ukladani hry
function Katureel::Save() {
	return {};
}

/* Funkce zjisti ID zadaneho zbozi, standardni hodnoty pro label jsou:
 	VALU (valuables), STEL (steel), IORE (iron ore), WOOD (wood), GRAI (grain),
	GOOD (goods), LVST (livestock), OIL_ (oil), MAIL (mail), COAL (coal)
	PASS (passenger), hodnoty se vsak muzou menit v zavislosti na
	instalovanych rozsirenich */
function Katureel::GetCargoID(label) {
	local result = null;
	foreach (cidx, dummy in AICargoList()) {
		if (AICargo.GetCargoLabel(cidx) == label) {
      		result = cidx;
      		break;
    	}
	}
	return result;
}


/* Vrati policko na kterem bude mozne postavit zastavku
	Vrati pravy horni (NE) roh zastavky
baseTile je TileIndex policka na kterem se ma zacit hledat,
cargoID je Id zbozi, ktere ma byt na zastavce prijimano nebo produkovano.
accepts je true pokud ma byt zbozi prijmano, false, pokud ma byt zbozi
	produkovano.

Funkce vrati TileIndex praveho horniho rohu zastavky.
*/
function Katureel::GetStationCorner(baseTile, cargoId, accept) {
	// zastavka bude postavena vodorovne, bude mit delku 4 a vysku 1
	/* data, ktera predame spiralnimu vyhledavci predame ve forme asociativniho
		pole (coz se chova v podstate jako objekt), ve squirellu se tomu
		rika table a je to velmi podobne, jako "objekty" v JavsScriptu.
		Operator <- vytvori novy index toho "pole". Ve squirellu se tomu rika,
		ze vytvori novy slot, pokud bychom napsali pouze =, tak by to skonilo
		s chybou, ze index 'width' neni definovan */
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

/* Funkce pro prochazeni plochy ve spiralach.
baseTile je TileIndex pocatku prohledavani
terminateCallback je funkce, ktera vraci true/false, pokud
	vrati true bude prohledavani ukonceno jako uspesne
abortCallback je funkce, ktera pokud true/false, pokud
	vraci true bude prohledavani ukonceno jako neuspesne
data jsou libovolna data, ktera budou predana callbackum

Funkce vrati TileIndex policka  na kterem terminateCallback vrati true
*/
function Katureel::SpiralWalker(baseTile, terminateCallback, abortCallback, data) {
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
function Katureel::_spiralTerminate(tile, data) {
	AISign.BuildSign(tile, "?");
	// +1 na policko pro vyjezd ze zastavky
	return AITile.IsBuildableRectangle(tile, data.width + 1, data.height);
}

/* Testuje, jestli je na danem poli jeste prijimano/produkovano zbozi.
*/
function Katureel::_spiralAbort(tile, data) {
	// pokud uz neprijima nebo neprodukuje zbozi vrati false
	return ((data.accept && ((AITile.GetCargoAcceptance(tile, data.cargoId, data.width, data.height, data.radius)) < 8)) ||
		(!data.accept && (AITile.GetCargoProduction(tile, data.cargoId, data.width, data.height, data.radius)) < 1));
}


/* Postavi depo na zadane ceste. Na trati musi byt alespon
jedna svisla nebo vodorovna kolejnice.
Vrati tileIndex policka na kterem je depo postaveno nebo
	null, pokud se depo nepodarilo postavit.
*/
function Katureel::BuildDepot(/* AyStar.Path */ path) {
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
function Katureel::ClearSigns() {
	foreach (idx, dSign in AISignList()) {
		AISign.RemoveSign(idx);
	}
}

/*
	prevod tileindexu na x,y
*/
function Katureel::TileToXY(/*AITIle*/ tile) {
	local y = floor(tile / AIMap.GetMapSizeX());
	local x = tile - y * AIMap.GetMapSizeX();
	return [x, y];
}

/*
	zjistit, zda ma policko popisek
*/
function Katureel::FindSign(/*AITile*/ tile) {
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
function Katureel::UpdateSign(/*AITile*/ tile, /*String*/ text) {
	local sign = this.FindSign(tile);
	if(!sign) {
		sign = AISign.BuildSign(tile, text);
	} else {
		AISign.SetName(sign, AISign.GetName(sign) + " " + text);
	}
}

