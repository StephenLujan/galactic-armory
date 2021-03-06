// Is called when a ship is first created
void onCreate(HulledObj@ ship, Object@ createdAt) {
	if(canAchieve && ship.toObject().getOwner() is getPlayerEmpire()) {
		float scale = sqr(ship.toObject().radius);
		if(scale >= 1000.f)
			achieve(AID_SCALE_SMALL);
		if(scale >= 10000.f)
			achieve(AID_SCALE_MEDIUM);
		if(scale >= 100000.f)
			achieve(AID_SCALE_LARGE);
	}
}

// Is called every tick for a ship
//void tick(HulledObj@ ship, float time) {
//}

// Is called when a ship changes owner, return
// true to prevent the owner change
//bool onOwnerChange(HulledObj@ ship, Empire@ from, Empire@ to) {
//	return false;
//}

// Is called when a ship is completely destroyed,
// return true to prevent the destruction
//bool onDestroy(HulledObj@ ship, bool silent) {
//	return false;
//}

// Is called when a ship enters a new system.
//  Note: oldParent is null when undocking or right after the object gets created,
//        newParent is null when docking or right before the object is destroyed
//void onReparent(HulledObj@ ship, Object@ oldParent, Object@ newParent) {
//}