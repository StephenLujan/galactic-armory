//3angel
//============
//a tiers meeting at the middle
//No Dust

#include "/include/map_lib.as"

void makeMap(Galaxy@ Glx) {
	prepMap();
	
	uint sysCount = getGameSetting("SYSTEM_COUNT",150);
	float rad, theta;
	float maxRad = sqrt(sysCount) * getGameSetting("MAP_SYSTEM_SPACING", 3000.f) * orbitRadiusFactor / 70.f; //Magic number = old base setting
	float maxHgt = maxRad / 4.f;
	if(getGameSetting("MAP_FLATTEN", 0) == 1)
		maxHgt = 0;
	setMakeOddities(getGameSetting("MAP_ODDITIES", 1.f) != 0.f);

	float minRad = 250.f;

	uint sysIndex = 0;
	float xxx, yyy, zzz, side;
	for(; sysIndex < sysCount; ++sysIndex) {
		theta = randomf(twoPi);
		rad = range(minRad, maxRad, pow(randomf(1.f),0.85f));
		
		//MAIN KEY.  Determines location of a base star.
		if(sysIndex < (sysCount / 2))
			xxx = rad * sin(getGameSetting("MAP_SYSTEM_SPACING", 3000.f));
		else if(sysIndex > (sysCount * (3 / 4)))
			xxx = rad * tan(getGameSetting("MAP_SYSTEM_SPACING", 3000.f)) / cos(rad);
		else
			xxx = rad * sin(getGameSetting("MAP_SYSTEM_SPACING", 3000.f)  / rad) - sin(rad);
	

		if(sysIndex < (sysCount / 2))
			yyy = rad * cos(getGameSetting("MAP_SYSTEM_SPACING", 3000.f));
		else
			yyy = -rad * sin(getGameSetting("MAP_SYSTEM_SPACING", 3000.f));
		if(sysIndex < (sysCount / 2))
			zzz = rad * sin(getGameSetting("MAP_SYSTEM_SPACING", 3000.f) * rad);
		else
			zzz = rad * cos(getGameSetting("MAP_SYSTEM_SPACING", 3000.f) * rad);						

		vector position(xxx, yyy, zzz);
		
		System@ sys = makeRandomSystem(Glx, position, sysIndex, sysCount);

		updateProgress(sysIndex, sysCount);
	}
	
	if(jumpBridges && sysCount >= 20)
	{
		float density = getGameSetting("MAP_BRIDGE_DENSITY", 0.1f);
		float availableGates = float(sysCount) * density;
		float gateIndex = 0;
		
		while(gateIndex < availableGates)
		{
			if(makeGateSystem(Glx))
				gateIndex++;
			updateBridgeProgress(gateIndex,availableGates);
		}
	}
}

Planet@ setupHomeworld(System@ sys, Empire@ owner) {
	return setupStandardHomeworld(sys, owner);
}
