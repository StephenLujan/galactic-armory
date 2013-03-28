//Globals
ObjectFlag objImprovement = objUser03, setImpPause = objSetting00;
bool initialized;

//Constants
const string@ strWorkers = "Workers", strTrade = "Trade", strGovTrade = "GovTrade";
const string@ strFuel = "Fuel", strAmmo = "Ammo", strFood = "Food";
const string@ strMtl = "Metals", strElc = "Electronics", strAdv = "AdvParts";

const float mil = 1000000.0f;
const subSystemDef@ city = null;
const subSystemDef@ port = null;
const subSystemDef@ capitol = null;
const subSystemDef@ GC = null;
const subSystemDef@ yard = null;

void init() {
	@city = getSubSystemDefByName("City");
	@port = getSubSystemDefByName("SpacePort");
	@capitol = getSubSystemDefByName("Capital");
	@GC = getSubSystemDefByName("GalacticCapital");	
	@yard = getSubSystemDefByName("ShipYard");
	
	initialized = true;
	
	print("Governors Initialized");
}

/*
 * This function checks that a planet isnt building improvements
 * before it will allow the build queue to continue
 */
bool setGov(Planet@ pl)
{
	Object@ obj = pl;
	
	//Init the subsystems.
	if(!initialized)
		init();
	
	//Don't allow gov to run when planets are building improvements
	if(obj.getFlag(objImprovement) && !obj.getFlag(setImpPause))
		return true;

	return false;
}

/*
 * Builds 1 of the input structure, tearing down old buildings if necessary for space
 */
bool buildRequired(Planet@ pl, const subSystemDef@ build)
{
	PlanetStructureList list;
	list.prepare(pl);
	uint slots = pl.getMaxStructureCount(), structs = list.getCount();
	
	// if we aren't full just build it and return
	if(structs < slots) 
	{
		pl.buildStructure(build);
		return true;
	}

	// If we're full find the first thing we can replace and replace it.
	for(uint i = 0; i < list.getCount(); i++)
	{	
		const subSystemDef@ def = list.getStructure(i).type;

		if(def is port || def is yard || def is city || def is capitol || def is GC || list.getCount(def) <= 1)
			continue;
		pl.removeStructure(i);
		pl.buildStructure(build);
		return true;
	}
	// All slots were filled with unreplaceables
	return false;
}

/*
 * This function checks the worker levels of a planet
 * and adjusts the number of cities as needed
 */
bool checkWorkers(Planet@ pl)
{
	Object@ obj = pl;
	State@ workers = obj.getState(strWorkers);
	float wmax = pl.getMaxPopulation();

	// leave now if a city is not needed
	if(wmax - workers.required >= 12.f * mil)
		return false;
		
	// Otherwise try to get a city
	return buildRequired(pl, city);
}

/*
 * This function checks the trade amount of a planet
 * and adjusts the number of ports as needed
 */
bool checkTrade(Planet@ pl)
{
	Object@ obj = pl;
	Empire@ emp = obj.getOwner();
	State@ trade = obj.getState(strTrade);	
	State@ govTrade = obj.getState(strGovTrade);

	bool maxed = false;
	if(gameTime - govTrade.val > 5.f || gameTime <= 30) {
		//Work off an average of the last update and this one
		float req = (trade.inCargo + govTrade.max) / 2;

		//Error checking incase it hits halfway through a planet update
		if(req > trade.max * 10)
			return false;
			
		if(req >= trade.max)
			maxed = true;
			
		govTrade.val = gameTime;
		govTrade.max = req;
	}

	// Only continues if the planet is using its maximum trade capability for the last 10 seconds.
	// This will not be completely accurate as if a planet is importing the rate will be maxed
	// Need to find a way around this.
	if(!maxed)
		return false;

	//try to get a port
	return buildRequired(pl, port);
}