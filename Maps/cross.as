//cross
//=====
//Creates two discs intersecting at each other's centers

#include "/include/map_lib.as"
#include "/include/cross_gas.as"

void makeMap(Galaxy@ Glx) {
	prepMap();
	
	uint sysCount = getGameSetting("SYSTEM_COUNT",150);
	float rad, theta;
	float maxRad = sqrt(sysCount) * getGameSetting("MAP_SYSTEM_SPACING", 3000.f) * orbitRadiusFactor / 70.f; //Magic number = old base setting
	setMakeOddities(getGameSetting("MAP_ODDITIES", 1.f) != 0.f);
	bool hollow = getGameSetting("MAP_HOLLOW", 0) > 0.5f;

	float minRad = 250.f;
	
	uint sysIndex = 0;
	if(sysCount >= 50) {
		minRad = makeQuasar(Glx, vector(0,0,0), sqrt(float(sysCount) / 50.f)) + (12.f * orbitRadiusFactor);
		++sysIndex;
	}

	if(hollow)
		minRad = maxRad = maxRad;
	
	for(; sysIndex < sysCount; ++sysIndex) {
		theta = randomf(twoPi);
		rad = range(minRad, maxRad, pow(randomf(1.f),0.85f));
		
		vector position;
		if(sysIndex < sysCount/2)
			position = vector(rad * cos(theta), 0.f, rad * sin(theta));
		else
			position = vector(0.f, rad * cos(theta), rad * sin(theta));
		
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
