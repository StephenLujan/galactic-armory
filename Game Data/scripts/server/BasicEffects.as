string@ strPower = "Power", strOre = "Ore", strDamage = "Damage", strShields = "Shields", strH3 = "H3";
string@ strFuel = "Fuel", strFood = "Food", strMetals = "Metals", strElects = "Electronics", strAdvParts = "AdvParts";
string@ strControl = "Control", strCrew = "Crew", strAmmo = "Ammo", strWorkers = "Workers", strGoods = "Guds", strLuxuries = "Luxs";

const int M = 1000000;

enum TradeMode {
	TM_All,
	TM_Metal,
	TM_Elects,
	TM_Parts,
	TM_Ammo,
	TM_Fuel,
};

float sign(float x) {
	if(x > 0)
		return 1.f;
	else
		return 0.f;
}

float getResourceWeight(State@ state) {
	if(abs(state.max) < 0.01f)
		return 0.f;
	if(abs(state.val) < 0.01f)
		return 0.f;
	float pct = (state.val + state.inCargo) / (state.max + state.inCargo);
	if(pct > 0.f)
		return 1.f * pct;
	else
		return 0;
}

//Returns the chace of an event occuring within time t
//p should be the chance of the event occuring given t=1
float chanceOverTime(float p, float t) {
	return 1.f-pow(1.f-p,t);
}

void DestructOnPowerOff(Event@ evt) {
	State@ pow = evt.target.getState(strPower);
	if(pow.val <= 0 && evt.obj.toHulledObj() !is null)
		evt.obj.toHulledObj().damageSystem(evt.dest, evt.obj, evt.dest.HP * 2.f);
}

//Like shields, charging capacitors goes slower the closer to full they get
void PowerGen(Event@ evt, float Rate, float Cost) {
	State@ fuel = evt.obj.getState(strFuel), pow = evt.target.getState(strPower);
	float pct = pow.val/pow.max;
	Rate *= 2 * (1 - (pct*pct));
	Rate = min(pow.max - pow.val, Rate * evt.time);
	if(Rate > 0) {
		float p = fuel.getAvailable();
		float use = Rate * Cost;
		if(use <= p) {
			pow.val += Rate;
			fuel.consume(use, evt.obj);
		}
		else {
			if(p >= 0.001f) {
				pow.val += p / Cost;
				fuel.consume(p, evt.obj);
			}
		}
	}
	
}

void SolarPower(Event@ evt, float Rate, float SurfaceArea) {
	Object@ obj = evt.obj;
	
	System@ system = obj.getCurrentSystem();
	if(@system == null)
		return;

	State@ power = evt.obj.getState(strPower);
	float canStore = power.getFreeSpace();
	if(canStore <= 0)
		return;
	float add = min(Rate * evt.time * SurfaceArea * 25000.f / min(obj.position.getLength(), 50.f*50.f), canStore);
	power.val += add;
}

void SpeedIfFuel(Event@ evt, float Amount, float Efficiency) {
	State@ fuel = evt.obj.getState(strFuel);

	// Check if we have enough fuel
	if (fuel.getAvailable() <= evt.time * Amount * Efficiency) {
		evt.state = ESC_DISABLE;
		return;
	}

	// Add thrust
	HulledObj@ obj = evt.obj;
	if (obj !is null) {
		obj.thrust = obj.thrust + Amount;
	}
}

void SpeedIfFuel(Event@ evt, float Amount, float Efficiency, float PowCost) {
	State@ power = evt.obj.getState(strPower);
	if (power.getAvailable() <= evt.time * PowCost) {
		evt.state = ESC_DISABLE;
		return;
	}

	SpeedIfFuel(evt, Amount, Efficiency);
}

void FuelThrustCons(Event@ evt, float Amount, float Efficiency) {
	Object@ obj = evt.obj;
	if(obj.velocity.getLengthSQ() > 0.f && obj.inOrbitAround() is null) {
		State@ fuel = obj.getState(strFuel);
		float consume = evt.time * Amount * Efficiency;
		if(fuel.getAvailable() >= consume) {
			fuel.consume(consume,obj);
		}
		else {
			fuel.val = 0;
			evt.state = ESC_DISABLE;
		}
	}
}


void IonThrustCons(Event@ evt, float Amount, float Efficiency, float PowCost) {
	Object@ obj = evt.obj;
	if(obj.velocity.getLengthSQ() > 0.f && obj.inOrbitAround() is null) {
		State@ fuel = obj.getState(strFuel), pow = obj.getState(strPower);
		float consume = evt.time * Amount * Efficiency;
		if(fuel.getAvailable() >= consume) {
			PowCost *= evt.time;
			if(pow.getAvailable() >= PowCost) {
				fuel.consume(consume,obj);
				pow.consume(PowCost,obj);
			}
			else {
				evt.state = ESC_DISABLE;
			}
		}
		else {
			evt.state = ESC_DISABLE;
		}
	}
}

//Delay, in seconds, before the colonizer can colonize again
const float colonizerReloadDelay = 25.f;
//Amount of population given per structure created
const float populationFactor = 1000000.f;

void StandardTakeover(Planet@ plt, Empire@ owner, float makeStructures) {
	plt.Conquer(owner);	
	const subSystemDef@ advpts = getSubSystemDefByName("AdvPartFact"), farm = getSubSystemDefByName("Farm");
	const subSystemDef@ metals = getSubSystemDefByName("MetalMine"), elects = getSubSystemDefByName("ElectronicFact");
	const subSystemDef@ city = getSubSystemDefByName("City"), capital = getSubSystemDefByName("Capital");
	const subSystemDef@ port = getSubSystemDefByName("SpacePort");

	if (owner.hasTraitTag("no_food"))
		if (owner.hasTraitTag("consume_metals"))
			@farm = metals;
		else
			@farm = port;
	if (owner.hasTraitTag("no_bank"))
		@port = farm;
	
	int makeStructs = min(makeStructures, plt.getMaxStructureCount() - plt.getStructureCount());
	if(plt.getStructureCount(capital) == 0) {
		plt.addStructure(capital);
		makeStructs -= 1;
	}
	
	makeStructs = clamp(makeStructs, 0, 13);
	switch(makeStructs) {
		case 13:
			plt.addStructure(metals);
		case 12:
			plt.addStructure(advpts);
		case 11:
			plt.addStructure(elects);
		case 10:
			plt.addStructure(city);
		case 9:
			plt.addStructure(farm);
		case 8:
			plt.addStructure(metals);
		case 7:
			plt.addStructure(farm);
		case 6:
			plt.addStructure(city);
		case 5:
			plt.addStructure(elects);
		case 4:
			plt.addStructure(metals);
		case 3:
			plt.addStructure(advpts);
		case 2:
			plt.addStructure(city);
		case 1:
			plt.addStructure(port);
		case 0:
			break;
	}
	
	//Set the population to the starting pop (correcting any errors in the existing population)
	plt.modPopulation(populationFactor * makeStructures - plt.getPopulation());

	
	int governorType = floor(owner.getSetting("defaultGovernor"));
	if(owner.getSetting("autoGovern") != 0.f) {
		plt.setUseGovernor(true);
		if(governorType < 0)
			chooseGovernor(plt);
		else if(governorType > 0)
			plt.setGovernorType(owner.getBuildList(governorType-1));
		else
			plt.setGovernorType("default");
	}
	else {
		plt.setGovernorType("default");
		plt.setUseGovernor(false);
	}
}

//Chooses a nearly-optimal governor based on conditions and empire resources
void chooseGovernor(Planet@ pl) {
	//Get Empire wide resources
	Empire@ emp = pl.toObject().getOwner();
	State@ ore = pl.toObject().getState(strOre), h3 = pl.toObject().getState(strH3);
	float ammo = emp.getStat(strAmmo), fuel = emp.getStat(strFuel), food = emp.getStat(strFood);
	float goods = emp.getStat(strGoods), luxs = emp.getStat(strLuxuries);
	float metal = emp.getStat(strMetals), elects = emp.getStat(strElects), parts = emp.getStat(strAdvParts);
	float slots = pl.getMaxStructureCount();
	
	//Make Double sure AI uses its own script
	if(emp.isAI())
		return;
	
	//Heavily prefer economic development in the early game
	if(gameTime < 10.0 * 60.0) {
		if(pl.hasCondition("geotherm") || pl.hasCondition("sterile"))
			pl.setGovernorType("economic");
		if(pl.hasCondition("ore_rich") || pl.hasCondition("ore_extreme") && !pl.hasCondition("ore_poor"))
			pl.setGovernorType("metalworld");
		else {
			if(randomf(1.f) < 0.5f)
				pl.setGovernorType("economic");
			else
				pl.setGovernorType("default");
		}
	}
	else {
		if(gameTime < 60.0 * 60.0 && pl.hasCondition("homeworld"))
			return;
		if(ore.val > 0 && (pl.hasCondition("geotherm")  && (pl.hasCondition("ore_rich") || pl.hasCondition("ore_extreme") && !pl.hasCondition("ore_poor"))))
			pl.setGovernorType("economic");
		else if(ore.val > 0 && pl.hasCondition("ore_rich") || pl.hasCondition("ore_extreme") && !pl.hasCondition("ore_poor"))
			pl.setGovernorType("metalworld");
		else if(pl.hasCondition("geotherm") || pl.hasCondition("sterile")) {
			if(parts < elects)
				pl.setGovernorType("advpartworld");
			else
				pl.setGovernorType("elecworld");
		}
		else if(pl.hasCondition("natural_catalysts")) {
			if(slots > 25) {
				if(h3.val > 0.f)
					pl.setGovernorType("h3logworld");
				else
					pl.setGovernorType("logworld");
			}
			else if(fuel < ammo) {
				if(h3.val > 0.f)
					pl.setGovernorType("h3fuelworld"); 
				else
					pl.setGovernorType("fuelworld");
			}
			else
				pl.setGovernorType("ammoworld");
		}
		else if(pl.hasCondition("rare_pheno") || pl.hasCondition("remnant_research") || pl.hasCondition("remant_relic") || pl.hasCondition("neutrino_bombardment") && !pl.hasCondition("unstable") && !pl.hasCondition("high_winds"))
			pl.setGovernorType("resworld");
		else if(pl.hasCondition("dense_flora") && !pl.hasCondition("barren_waste"))
			pl.setGovernorType("agrarian");
		else if(pl.hasCondition("cavernous") || pl.hasCondition("high_plateaus") && !pl.hasCondition("frigid") && !pl.hasCondition("volcanic") && !pl.hasCondition("unstable") && !pl.hasCondition("high_winds"))
			pl.setGovernorType("outpost");
		else if(pl.hasCondition("rich_eco") && !emp.hasTraitTag("forever_indifferent"))
			pl.setGovernorType("luxworld");
		else {
			if(slots > 30)
				pl.setGovernorType("shipworld");
			else if (fuel <= 200.f) {
				if(h3.val > 0.f)
					pl.setGovernorType("h3fuelworld"); 
				else
					pl.setGovernorType("fuelworld");
			}
			else if(ore.val > 0 && metal < elects && metal < parts)
				pl.setGovernorType("metalworld");
			else if(elects < metal * 0.75 || parts < metal * 0.75) {
				if(parts < elects)
					pl.setGovernorType("advpartworld");
				else
					pl.setGovernorType("elecworld");
			}
			else if(randomf(1.f) < 0.5f)
				pl.setGovernorType("economic");
			else
				pl.setGovernorType("default");
		}
	}
}

// Backwards compat function
void CapturePlanet(Event@ evt, float MakeStructures) {
	evt.obj.getState("MakeStructures").max = MakeStructures;
	CapturePlanet(evt);
}

//Caputes a target planet
//The target planet must be unowned
//Places various free structures onto the planet to help it build
void CapturePlanet(Event@ evt) {
	//if(state.val1 <= 0) {
	Object@ targ = evt.target;
	if(targ !is null && evt.obj !is null && @targ.getOwner() != @evt.obj.getOwner() && !targ.getOwner().isValid()) {
		Planet@ plt = targ.toPlanet();
		if(@plt != null) {
			Object@ obj = evt.obj;
			Empire@ owner = obj.getOwner();
			if(owner is null)
				return;

			const State@ structs = obj.getState("MakeStructures");
			float makeStructures = structs is null ? 1.f : floor(structs.max);
			
			StandardTakeover(plt, owner, makeStructures);
			
			//Send over resources in the colony ship
			State@ From, To;
			
			@From = evt.obj.getState("Metals");
			@To = targ.getState("Metals");
			if(@From != null && @To != null)
				To.add(From.getAvailable(), targ);
			
			@From = evt.obj.getState("Electronics");
			@To = targ.getState("Electronics");
			if(@From != null && @To != null)
				To.add(From.getAvailable(), targ);
			
			@From = evt.obj.getState("AdvParts");
			@To = targ.getState("AdvParts");
			if(@From != null && @To != null)
				To.add(From.getAvailable(), targ);

			if(canAchieve && evt.obj.getOwner() is getPlayerEmpire()) {
				progressAchievement(AID_PLANETS_SMALL, 1);
				progressAchievement(AID_PLANETS_MEDIUM, 1);
				progressAchievement(AID_PLANETS_LARGE, 1);
			}
			
			//state.val1 = colonizerReloadDelay;
			evt.obj.destroy(true); //Uncomment for non-reusable colony ships
		}
	}
	//}
}

void TimeModifier(Event@ evt, float Factor) {
	evt.time *= Factor;
}

float hasPower(const Object@ src, const Object@ trg, const Effector@ eff) {
	const State@ pow = trg.getState(strPower);
	if(pow is null || pow.val <= 0)
		return 0;
	return 1;
}

float hasCrew(const Object@ src, const Object@ trg, const Effector@ eff) {
	const State@ crew = trg.getState(strCrew);
	if(crew is null || crew.val <= 0)
		return 0;
	return 1;
}



void MineOre(Event@ evt, float Rate, float PowCost) {
	Object@ targ = evt.target, obj = evt.obj;
	if(targ !is null && obj !is null) {
		State@ oreTo = obj.getState(strOre), oreFrom = targ.getState(strOre);
		float duration = evt.time;

		State@ powFrom = null;
		if (PowCost > 0) {
			@powFrom = obj.getState(strPower);
			duration = min(evt.time, powFrom.getAvailable() / PowCost);
		}

		if(duration > 0) {
			float takeAmt = min(Rate * duration, min(oreTo.getTotalFreeSpace(obj), oreFrom.val));
			oreTo.add(takeAmt,obj);
			oreFrom.val -= takeAmt;
			
			if (PowCost > 0 && powFrom !is null)
				powFrom.consume(duration * PowCost,obj);

			if (oreFrom.val <= 0.01f && targ.toPlanet() is null)
				targ.damage(obj, pow(10, 12));
			else
				targ.damage(obj, takeAmt);
		}
	}
}

void DrainResource(Event@ evt, float Rate) {
	Object@ targ = evt.target, obj = evt.obj;
	if (evt.obj is null || !evt.obj.isValid()) {
		evt.state = ESC_DISABLE;
		return;
	}

	if(@targ != null) {
		if(evt.time > 0) {
			float used, total;
			obj.getCargoVals(used, total);

			float takeAmt = min(Rate * evt.time, total - used);
			float amt = 0.f;

			if (takeAmt <= 0.1f) {
				evt.state = ESC_DISABLE;
				return;
			}

			// Steal Adv
			State@ advTo = obj.getState(strAdvParts), advFrom = targ.getState(strAdvParts);
			amt = min(takeAmt / 3, advFrom.val + advFrom.inCargo);
			advFrom.consume(amt, targ);
			advTo.add(amt, obj);
			takeAmt -= amt;

			// Steal Elc
			State@ elcTo = obj.getState(strElects), elcFrom = targ.getState(strElects);
			amt = min(takeAmt / 2, elcFrom.val + elcFrom.inCargo);
			elcFrom.consume(amt, targ);
			elcTo.add(amt, obj);
			takeAmt -= amt;

			// Steal Mtl
			State@ mtlTo = obj.getState(strMetals), mtlFrom = targ.getState(strMetals);
			amt = min(takeAmt, mtlFrom.val + mtlFrom.inCargo);
			mtlFrom.consume(amt, targ);
			mtlTo.add(amt, obj);
		}
	}
}

void MakeAdvParts(Event@ evt, float Rate, float MetalCostPer, float ElectCostPer) {
	Object@ targ = evt.target;
	if(@targ != null) {
		Rate *= evt.time;
		State@ APTo = targ.getState(strAdvParts);
		State@ elFrom = targ.getState(strElects), metalFrom = targ.getState(strMetals);
		float canMake = min(min(elFrom.getAvailable() / ElectCostPer, metalFrom.getAvailable() / MetalCostPer), Rate);
		canMake = min(canMake, APTo.getTotalFreeSpace(targ));
		if(canMake > 0) {
			metalFrom.consume(canMake * MetalCostPer, targ);
			elFrom.consume(canMake * ElectCostPer, targ);
			APTo.add(canMake, targ);
		}
	};
}

void RecycleMetals(Event@ evt, float PerPerson, float MaxRate) {
	Object@ targ = evt.target, obj = evt.obj;
	if(@targ != null) {
		float people = 1;
		Planet@ pl = targ.toPlanet();
		if(@pl != null)
			people = pl.getPopulation();
		State@ metals = obj.getState(strMetals);
		float recyc = min(min(people * PerPerson * evt.time, MaxRate * evt.time), metals.getTotalFreeSpace(obj));
		metals.add(recyc, obj);
	}
}

void Trade(Event@ evt, float Rate) {
	Rate *= evt.time;
	if(Rate <= 0)
		return;
	
	Object@ obj = evt.obj;
	Empire@ owner = obj.getOwner();
	
	SysRef@ ref = evt.dest;
	uint resIndex = uint(ref.val1 + 1) % 4;
	ref.val1 = resIndex;
	
	const string@ resName = null;
	switch(resIndex) {
		case 0:
			@resName = @strAdvParts; break;
		case 1:
			@resName = @strElects; break;
		case 2:
			@resName = @strMetals; break;
		case 3: default:
			@resName = @strFood; break;
	}
	
	State@ resource = obj.getState(resName);
	if(resource.max > 0) {
		float resLevel = resource.val / resource.max;
		if(resLevel > 0.5f) {
			float give = min(resource.max * (resLevel - 0.5f), Rate);
			owner.addStat(resName, give);
			resource.val -= give;
		}
		else {
			float take = min(resource.max * (0.5f - resLevel), Rate);
			take = owner.consumeStat(resName, take);
			resource.val += take;
		}
	}
}

float ShouldRep(const Object@ src, const Object@ trg, const Effector@ eff) {
	const State@ dmg = trg.getState(strDamage);
	return dmg is null ? 0 : dmg.val / dmg.max;
}

float CanMine(const Object@ src, const Object@ trg, const Effector@ eff) {
	const Empire@ emp = trg.getOwner();
	if(emp is null || emp.isValid() == false)
		return 1.f;
	return 0.f;
}

void Salvage(Event@ evt, float rate, float factor) {
	Object@ targ = @evt.target;
	
	State@ dmg = targ.getState(strDamage);
	float hp = dmg.max - dmg.val;
	if(hp > 0) {
		Object@ src = @evt.obj;
		State@ metals = src.getState(strMetals);
		float canCollect = min(metals.getTotalFreeSpace(src), min(rate * evt.time * factor, hp * factor));
		if(canCollect > 0) {
			targ.damage(src, canCollect / factor);
			metals.add(canCollect, src);
		}
		else {
			evt.state = ESC_DISABLE;
		}
	}
	else {
		evt.state = ESC_DISABLE;
	}
}

//Extra logic for the analyzer
float UnknownHull(const Object@ from, const Object@ to, const Effector@ eff) {
	const HulledObj@ ship = @to;
	
	const Empire@ us = from.getOwner();
	if(us is null || us.isValid() == false)
		return 0.f;
	
	if(us.hasForeignHull(ship.getHull()))
		return 0.f;
	else
		return 1.f;
}

void Analyze(Event@ evt, float scanQuality, float PowCost) {
	//Consume power
	float tickCost = PowCost * evt.time;
	State@ power = evt.obj.getState(strPower);
	if(power.val < tickCost) {
		evt.state = ESC_DISABLE;
		return;
	}
	else {
		power.val -= tickCost;
	}
	
	//Roll the dice to see if we succeed
	//Large ships double their scanning speed on small ships, but small ships lose nearly all of their time
	if(randomf(1.f) < chanceOverTime(scanQuality,evt.time * clamp(evt.obj.radius/evt.target.radius, 0.01f, 2.f)))
		return;
	
	Empire@ us = evt.obj.getOwner();
	if(us is null || us.isValid() == false)
		return;
	
	HulledObj@ ship = @evt.target;
	us.acquireForeignHull(ship.getHull());
	evt.state = ESC_DISABLE;
}

void KillSystem(Event@ evt) {
	if (!evt.obj.isValid())
		return;
	if (evt.obj.toHulledObj() !is null)
		evt.obj.toHulledObj().damageSystem(evt.dest, evt.obj, evt.dest.HP * 2.f);
}

void SelfDestruct(Event@ evt) {
	if (!evt.obj.isValid())
		return;
	evt.dest.system.trigger("Detonation", evt.obj, null, 0, 0);
	evt.obj.destroy();
}

void CreateRingworld(Event@ evt) {
	System@ sys = evt.obj.getParent().toSystem();
	if(@sys != null && @sys.toObject() != @getGalaxy().toObject()) {
		// Check if there is already a ringworld here
		SysObjList objs;
		objs.prepare(sys);
		for (uint i = 0; i < objs.childCount; ++i) {
			Planet@ pl = objs.getChild(i);

			if (pl !is null && pl.getPhysicalType() == "ringworld") {
				// We found a ringworld, don't do anything
				evt.obj.destroy(true);
				return;
			}
		}
		objs.prepare(null);

		// Build a new ringworld
		Orbit_Desc orbDesc;
		Planet_Desc plDesc;
		plDesc.setPlanetType( getPlanetTypeID("ringworld") );
		plDesc.RandomConditions = false;
		plDesc.PlanetRadius = sys.toObject().radius * 0.25f;

		orbDesc.IsStatic = true;
		orbDesc.Offset = vector(0,0,0);
		plDesc.setOrbit(orbDesc);
		
		Planet@ pl = sys.makePlanet(plDesc);
		
		pl.addCondition("ringworld_special");
		
		pl.setStructureSpace(100.f);
		
		Object@ planet = pl.toObject();
		
		State@ ore = planet.getState("Ore");
		ore.max = 50000.f;
		ore.val = ore.max;
		
		Effect starEffect("SelfHealing");
		starEffect.set("Rate", 5000000.f);	
		planet.addTimedEffect(starEffect, pow(10, 35), 0.f, pl.toObject(), null, null, TEF_None);	

		Effect planetEffect("PlanetRegen");
		planet.addTimedEffect(planetEffect, pow(10, 35), 0.f, pl.toObject(), null, null, TEF_None);			
		State@ terSlots = planet.getState("Terraform");
		terSlots.max = 0;
		terSlots.val = 0;		
		
		planet.getState("Damage").max = 100000000000.f;
		
		StandardTakeover(planet, evt.obj.getOwner(), 25.f);

		if(canAchieve && evt.obj.getOwner() is getPlayerEmpire())
			achieve(AID_BUILD_RINGWORLD);
	}
	evt.obj.destroy(true);
}

void BankExport(Event@ evt, float Amount, float Mode) {
	Object@ obj = evt.obj;

	// Check for blockades
	System@ parent = evt.obj.getParent();
	Empire@ emp = evt.obj.getOwner();
	if (parent !is null && parent.isBlockadedFor(emp))
		return;

	//Trade things
	float tickTrade = Amount * evt.time;
	
	State@ shipmetal = obj.getState(strMetals);
	State@ shipelect = obj.getState(strElects);
	State@ shipparts = obj.getState(strAdvParts);
	State@ shipfuel = obj.getState(strFuel);
	State@ shipammo = obj.getState(strAmmo);
	
	TradeMode mode = TradeMode(int(Mode));
	float mtlWeight = 0.f, elecWeight = 0.f, partsWeight = 0.f, ammoWeight = 0.f, fuelWeight = 0.f;
	
	if(mode == TM_All)
	{
		mtlWeight = getResourceWeight(shipmetal);
		elecWeight = getResourceWeight(shipelect);
		partsWeight = getResourceWeight(shipparts);
		ammoWeight = getResourceWeight(shipammo);
		fuelWeight = getResourceWeight(shipfuel);		
		
		if(shipfuel.val <= shipfuel.max * 0.25)
			fuelWeight = 0.f;			
	}
	else if(mode == TM_Metal)
	{
		mtlWeight = getResourceWeight(shipmetal);	
	}
	else if(mode == TM_Elects)
	{
		elecWeight = getResourceWeight(shipelect);	
	}
	else if(mode == TM_Parts)
	{
		partsWeight = getResourceWeight(shipparts);	
	}
	else if(mode == TM_Ammo)
	{
		ammoWeight = getResourceWeight(shipammo);	
	}
	else if(mode == TM_Fuel)
	{
		fuelWeight = getResourceWeight(shipfuel);	

		if(shipfuel.val <= shipfuel.max * 0.25)
			fuelWeight = 0.f;			
	}	
	
	float totalWeight = abs(mtlWeight) + abs(elecWeight) + abs(partsWeight) + abs(ammoWeight) + abs(fuelWeight);
	
	float take;
	
	if(totalWeight > 0) {
		take = max(0.f ,min(shipmetal.val + shipmetal.inCargo,tickTrade * mtlWeight/totalWeight));
		emp.addStat(strMetals, take);
		shipmetal.consume(take,obj);
		tickTrade -= take;

		take = max(0.f ,min(shipelect.val + shipelect.inCargo,tickTrade * elecWeight/totalWeight));	
		emp.addStat(strElects, take);
		shipelect.consume(take,obj);
		tickTrade -= take;

		take = max(0.f ,min(shipparts.val + shipparts.inCargo,tickTrade * partsWeight/totalWeight));	
		emp.addStat(strAdvParts, take);
		shipparts.consume(take,obj);
		tickTrade -= take;

		take = max(0.f ,min(shipfuel.val + shipfuel.inCargo,tickTrade * fuelWeight/totalWeight));
		if(shipfuel.val - take < shipfuel.max * 0.25)
			take -= shipfuel.max * 0.25;
		emp.addStat(strFuel, take);
		shipfuel.consume(take,obj);
		tickTrade -= take;

		take = max(0.f ,min(shipammo.val + shipammo.inCargo,tickTrade * ammoWeight/totalWeight));
		emp.addStat(strAmmo, take);
		shipammo.consume(take,obj);
		tickTrade -= take;
	}
	
	if(tickTrade > 0 && totalWeight > 0) {
		take = max(0.f ,min(shipmetal.val + shipmetal.inCargo,tickTrade * sign(mtlWeight)));
		emp.addStat(strMetals, take);
		shipmetal.consume(take, obj);
		tickTrade -= take;

		if(tickTrade > 0) {
			take = max(0.f ,min(shipelect.val + shipelect.inCargo,tickTrade * sign(elecWeight)));	
			emp.addStat(strElects, take);
			shipelect.consume(take, obj);
			tickTrade -= take;
				
			if(tickTrade > 0) {
				take = max(0.f ,min(shipparts.val + shipparts.inCargo,tickTrade * sign(partsWeight)));	
				emp.addStat(strAdvParts, take);
				shipparts.consume(take, obj);
				tickTrade -= take;	
				
				if(tickTrade > 0) {
					take = max(0.f ,min(shipfuel.val + shipfuel.inCargo,tickTrade * sign(fuelWeight)));
					if(shipfuel.val - take < shipfuel.max * 0.25)
						take -= shipfuel.max * 0.25;
					emp.addStat(strFuel, take);
					shipfuel.consume(take, obj);
					tickTrade -= take;		
					
					if(tickTrade > 0) {	
						take = max(0.f ,min(shipammo.val + shipammo.inCargo,tickTrade * sign(ammoWeight)));
						emp.addStat(strAmmo, take);
						shipammo.consume(take, obj);
						tickTrade -= take;
					}
				}
			}
		}
	}	
}

void MatterGen(Event@ evt, float Rate, float PowCost) {
	float tickPow = evt.time * PowCost;
	float tickRate = evt.time * Rate;

	// Check available power
	State@ pow = evt.obj.getState(strPower);
	if (pow.val <= tickPow) {
		if (pow.val <= tickPow * 0.01f)
			return;

		tickRate *= (pow.val / 2.f) / tickPow;
		tickPow = (pow.val / 2.f);
	}

	float usePerc = 0.f;
	float genFuel = 0.f;
	float genAmmo = 0.f;

	// Generate fuel
	State@ fuel = evt.obj.getState(strFuel);
	if (fuel.max > 0.f) {
		genFuel = min(fuel.max - fuel.val, tickRate);

		if (genFuel >= 0.f) {
			usePerc += genFuel / tickRate;
			fuel.val += genFuel;
		}
	}

	// Generate ammo
	State@ ammo = evt.obj.getState(strAmmo);
	if (ammo.max > 0.f) {
		genAmmo = min(ammo.max - ammo.val, tickRate - genFuel);

		if (genAmmo >= 0.f) {
			usePerc += genAmmo / tickRate;
			ammo.val += genAmmo;
		}
	}

	// Power cost
	if (usePerc >= 0.f) {
		State@ pow = evt.obj.getState(strPower);
		pow.val -= tickPow * usePerc;
	}
}

void FabricateAdv(Event@ evt, float Rate, float MtlCostPer, float ElcCostPer) {
	// Available materials
	State@ mtl = evt.obj.getState(strMetals);
	float hasMtl = mtl.getAvailable();
	float cargoMtl = mtl.inCargo;

	State@ elc = evt.obj.getState(strElects);
	float hasElc = elc.getAvailable();
	float cargoElc = elc.inCargo;

	// Figure out how much we can make
	float produce = Rate * evt.time;
	produce = min(produce, hasMtl / MtlCostPer);
	produce = min(produce, hasElc / ElcCostPer);

	State@ adv = evt.obj.getState(strAdvParts);
	float space = adv.getTotalFreeSpace(evt.obj);
	space += min(produce * MtlCostPer, cargoMtl);
	space += min(produce * ElcCostPer, cargoElc);

	produce = min(space, produce);

	// Make it
	if (produce > 0) {
		evt.obj.getState(strMetals).consume(produce * MtlCostPer, evt.obj);
		evt.obj.getState(strElects).consume(produce * ElcCostPer, evt.obj);
		evt.obj.getState(strAdvParts).add(produce, evt.obj);
	}
}

void AddWorkersRequired(Event@ evt, float amount) {
	evt.obj.getState(strWorkers).required += amount;
}

void SubWorkersRequired(Event@ evt, float amount) {
	evt.obj.getState(strWorkers).required -= amount;
}
