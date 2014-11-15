#include "~/Game Data/gui/include/gui_skin.as"
#include "/include/empire_image.as"
#include "~/Game Data/gui/include/dialog.as"
#include "~/Game Data/gui/include/notification_icon.as"

import void showTreaty(const Treaty@ treaty) from "trade_win";
import void proposeNewTreaty(const Empire@ other) from "trade_win";

import void showCivilActsWin() from "civil_acts_win";
import void showFlWin(bool bringToFront) from "fleet_win";
import void showObjectList() from "object_list";
import void toggleAdvisorWindow() from "advisor_win";

import void showEventIndicator(GuiElement@ ele) from "gui";
import void hideEventIndicator(GuiElement@ ele) from "gui";

import recti makeScreenCenteredRect(const dim2di &in rectSize) from "gui_lib";

const string@ strTerraform = "Terraform";
ObjectFlag setAutoTerra = objSetting01;

/* {{{ Window Handle */
class EmpireWindowHandle {
	EmpireWindow@ script;
	GuiScripted@ ele;

	EmpireWindowHandle(recti Position) {
		@script = EmpireWindow(true);
		@ele = GuiScripted(Position, script, null);

		script.init(ele);
		script.syncPosition(Position.getSize());
	}

	void addTab(EmpireTab@ tab) {
		GuiPanel@ panel = GuiPanel(recti(0, 0, 1024, 1024), false, SBM_Auto, SBM_Auto, ele);
		tab.init(panel);

		script.addTab(tab, panel);
		script.syncPosition(ele.getSize());
	}

	void switchTab(int to) {
		script.switchTab(to);
	}

	void bringToFront() {
		ele.bringToFront();
		setGuiFocus(ele);
		bindEscapeEvent(ele);
	}

	void setVisible(bool vis) {
		ele.setVisible(vis);
		if (vis)
			script.statUpdateTimer = 10.f;

		if (vis)
			bindEscapeEvent(ele);
		else
			clearEscapeEvent(ele);
	}

	bool isVisible() {
		return ele.isVisible();
	}

	void update(float time) {
		script.update(time);
	}

	void remove() {
		clearEscapeEvent(ele);
		ele.remove();
		script.remove();
	}
};
/* }}} */
/* {{{ Main window */
int MIN_WIDTH = 400;
int MIN_HEIGHT = 201;

const string[] statNames = {"RankMilitary", "RankColonization", "RankEconomy", "RankResearch", "Ship", "Planet", "Population"};
const string[] statTitles = {"#ST_Military", "#ST_Colonization", "#ST_Economy", "#ST_Research", "#ST_Ships", "#ST_Planets", "#ST_Population"};
const bool[] statRank = {true, true, true, true, false, false, false};
const string@ strVictory = "Victory";

interface EmpireTab {
	void init(GuiPanel@ ele);
	void syncPosition(dim2di newSize);
	void draw(recti area);

	void remove();
	void update(bool active, float time);
	void onEmpireChange(Empire@ emp);

	EventReturn onMouseEvent(GuiElement@ ele, const MouseEvent& evt);
	EventReturn onGUIEvent(GuiElement@ ele, const GUIEvent& evt);
	EventReturn onKeyEvent(GuiElement@ ele, const KeyEvent& evt);
};

class EmpireWindow : ScriptedGuiHandler {
	DragResizeInfo drag;
	bool removed;
	bool fullMode;

	Empire@ lastEmp;
	GuiButton@ close;

	GuiPanel@ topPanel;
	GuiStaticText@[] statText;
	GuiStaticText@[] statValue;
	GuiStaticText@ empName;
	EmpireImage@ empImg;

	GuiStaticText@ governorCaption;
	GuiCheckBox@ autoParkCheck;
    GuiCheckBox@ autoTerraCheck;
	GuiCheckBox@ autoGovCheck;
	GuiComboBox@ governorTypes;

	GuiButton@ civilActsButton;
	GuiButton@ fleetsButton;
	GuiButton@ objListButton;
	GuiButton@ advisorButton;

	EmpireTab@[] tabs;
	GuiPanel@[] tabPanels;

	int tabIndex;
	EmpireTab@ activeTab;
	GuiPanel@ activePanel;

	float statUpdateTimer;

	EmpireWindow(bool FullMode) {
		removed = false;
		statUpdateTimer = 2.f;
		fullMode = FullMode;
		tabIndex = -1;
	}

	void remove() {
		removed = true;
		for (uint i = 0; i < tabs.length(); ++i)
			tabs[i].remove();
	}
	void addTab(EmpireTab@ tab, GuiPanel@ panel) {
		uint n = tabs.length();
		tabs.resize(n+1);
		tabPanels.resize(n+1);

		@tabPanels[n] = panel;
		@tabs[n] = tab;

		panel.setVisible(false);
		topPanel.bringToFront();
	}

	void switchTab(int to) {
		if (to == tabIndex)
			return;

		// Hide current tab
		if (activePanel !is null)
			activePanel.setVisible(false);

		// Select new tab
		if (uint(to) < tabs.length()) {
			tabIndex = to;
			@activeTab = tabs[to];
			@activePanel = tabPanels[to];
			activePanel.setVisible(true);
		}
		else {
			tabIndex = -1;
			@activeTab = null;
			@activePanel = null;
		}
	}

	void init(GuiElement@ ele) {
		// Close button
		@close = CloseButton(recti(), ele);

		/* Create top panel */
		if (fullMode) {
			@topPanel = GuiPanel(recti(), false, SBM_Invisible, SBM_Invisible, ele);

			// Empire details
			@empImg = EmpireImage(null, recti(pos2di(4, 4), dim2di(108, 96)), topPanel);
			empImg.setCallback(showProfileMsg);

			@empName = GuiStaticText(recti(120, 8, 414, 32), null, false, false, false, topPanel);
			empName.setFont("title");

			// Empire settings
			@autoParkCheck = GuiCheckBox(false, recti(pos2di(350, 34), dim2di(220, 20)), localize("#EM_ParkText"), topPanel);
			@autoTerraCheck = GuiCheckBox(false, recti(pos2di(120, 34), dim2di(220, 20)), localize("#EM_TerraText"), topPanel);
			@autoGovCheck = GuiCheckBox(false, recti(pos2di(120, 56), dim2di(220, 20)), localize("#EM_GovText"), topPanel);
			@governorCaption = GuiStaticText(recti(pos2di(120, 78), dim2di(120, 20)), localize("#EM_DefaultGov"), false, false, false, topPanel);
			@governorTypes = GuiComboBox(recti(pos2di(250, 78), dim2di(140, 20)), topPanel);

			@civilActsButton = Button(recti(pos2di(4, 110), dim2di(160, 18)), localize("#EM_CivilActs"), topPanel);
			@fleetsButton = Button(recti(pos2di(168, 110), dim2di(160, 18)), localize("#EM_Fleets"), topPanel);
			@objListButton = Button(recti(pos2di(332, 110), dim2di(160, 18)), localize("#EM_ObjectList"), topPanel);
			@advisorButton = Button(recti(pos2di(496, 110), dim2di(160, 18)), localize("#EM_AdvisorWindow"), topPanel);

			// Create stat text
			uint statCnt = statNames.length();
			statText.resize(statCnt);
			statValue.resize(statCnt);

			for (uint i = statStart; i < statCnt; ++i) {
				@statText[i] = GuiStaticText(recti(0, 0, 75, 20), localize(statTitles[i]),
						false, false, false, topPanel);

				@statValue[i] = GuiStaticText(recti(0, 0, 50, 20), null,
						false, false, false, topPanel);
				statValue[i].setTextAlignment(EA_Right, EA_Top);
			}

			@lastEmp = getActiveEmpire();
			onEmpireChange(lastEmp);
			updateStats(lastEmp);
		}
	}

	void updateGovernorTypes(const Empire@ emp) {
		governorTypes.clear();
		uint cnt = emp.getBuildListCount();
		int governorType = round(emp.getSetting("defaultGovernor"));
		
		governorTypes.addItem(localize("#PG_AutoChoose"));
		if(governorType == -1)
			governorTypes.setSelected(0);

		for(uint i = 0; i < cnt; ++i) {
			governorTypes.addItem(localize("#PG_"+emp.getBuildList(i)));
			
			if(governorType == int(i+1) || (governorType == 0 && emp.getBuildList(i) == "default"))
				governorTypes.setSelected(i+1);
		}

		if(governorType > 0)
			governorTypes.setSelected(governorType);
	}

	void onEmpireChange(Empire@ emp) {
		// Update top bar information
		empImg.setEmpire(emp);
		empName.setText(emp.getName());
		empName.setColor(emp.color);

		autoParkCheck.setChecked(emp.getSetting("autoPark") >= 0.5f);
		autoTerraCheck.setChecked(emp.getSetting("autoTerra") >= 0.5f);
		autoGovCheck.setChecked(emp.getSetting("autoGovern") >= 0.5f);
		updateGovernorTypes(emp);

		civilActsButton.setEnabled(!emp.hasTraitTag("disable_civil_acts"));

		// Update all tabs
		for (uint i = 0; i < tabs.length(); ++i)
			tabs[i].onEmpireChange(emp);
	}

	void syncPosition(dim2di size) {
		pos2di mPos = pos2di(7, 20);
		dim2di mSize = size - dim2di(14, 27);

		// Close button
		close.setPosition(pos2di(size.width-30, 0));
		close.setSize(dim2di(30, 12));

		if (fullMode) {
			if (size.height >= 350) {
				topPanel.setVisible(true);
				topPanel.setPosition(pos2di(7, 20));
				topPanel.setSize(dim2di(size.width - 14, 130));

				bool showEmpSettings = size.width >= 740;
				bool showEmpData = size.width >= 640;
				bool showEmpFlag = size.width >= 460;
				bool showEmpGovSetting = size.width >= 890;
				empImg.setVisible(showEmpFlag);
				empName.setVisible(showEmpData);
				autoParkCheck.setVisible(showEmpSettings);
				autoTerraCheck.setVisible(showEmpSettings);
				autoGovCheck.setVisible(showEmpSettings);
				governorCaption.setVisible(showEmpSettings);
				governorTypes.setVisible(showEmpSettings);
				
				int tabSize = (size.width - 10 - 2*4) / 4;
				civilActsButton.setPosition(pos2di(0, 110));
				fleetsButton.setPosition(pos2di(4 + tabSize, 110));
				objListButton.setPosition(pos2di(8 + tabSize*2, 110));
				advisorButton.setPosition(pos2di(12 + tabSize*3, 110));
				
				civilActsButton.setSize(dim2di(tabSize, 18));
				fleetsButton.setSize(dim2di(tabSize, 18));
				objListButton.setSize(dim2di(tabSize, 18));
				advisorButton.setSize(dim2di(tabSize, 18));						

				// Position stat text
				uint statCnt = statText.length();
				for (uint i = statStart; i < statCnt; ++i) {
					int num = i - statStart;
					int baseX = size.width - (160 * ((num / 4) + 1)) + 6;
					int baseY = 8 + 24 * (num % 4);

					statText[i].setPosition(pos2di(baseX, baseY));
					statValue[i].setPosition(pos2di(baseX+80, baseY));
				}

				mPos.y += 132;
				mSize.height -= 132;
			}
			else {
				topPanel.setVisible(false);
			}
		}

		// Sync all tabs
		for (uint i = 0; i < tabs.length(); ++i) {
			tabPanels[i].setPosition(mPos);
			tabPanels[i].setSize(mSize);
			tabs[i].syncPosition(mSize);
		}
	}

	void draw(GuiElement@ ele) {
		ele.toGuiScripted().setAbsoluteClip();
		const recti absPos = ele.getAbsolutePosition();
		pos2di topLeft = absPos.UpperLeftCorner;
		pos2di botRight = absPos.LowerRightCorner;
		dim2di size = absPos.getSize();

		drawWindowFrame(absPos);
		drawResizeHandle(recti(botRight - pos2di(19, 19), botRight));

		if (fullMode && size.height >= 350) {
			// Draw the top area
			drawDarkArea(recti(pos2di(topLeft.x+7, topLeft.y+20), pos2di(botRight.x-7, topLeft.y+125)));
			drawTabBar(recti(pos2di(topLeft.x+6, topLeft.y+124), pos2di(botRight.x-6, topLeft.y+152)));

			drawVSepSmall(recti(pos2di(botRight.x - 163, topLeft.y + 19), dim2di(6, 106)));
			if (statStart == 0)
				drawVSepSmall(recti(pos2di(botRight.x - 323, topLeft.y + 19), dim2di(6, 106)));

			topLeft.y += 132;
			size.height -= 132;
		}

		if (activeTab !is null)
			activeTab.draw(recti(pos2di(topLeft.x+7, topLeft.y+20), pos2di(botRight.x-7, botRight.y-7)));
		else
			drawLightArea(recti(pos2di(topLeft.x+7, topLeft.y+20), pos2di(botRight.x-7, botRight.y-7)));

		clearDrawClip();
	}

	void updateStats(Empire@ emp) {
		uint statCnt = statValue.length();
		for (uint i = statStart; i < statCnt; ++i) {
			float value = emp.getStat(statNames[i]);

			if (statRank[i]) {
				if (value == 0) {
					statValue[i].setText("-");
				}
				else {
					Color col(0xffff0000);
					statValue[i].setColor(col.interpolate(Color(0xff00ff00), (value-1) / realEmpCnt));
					statValue[i].setText("#"+f_to_s(value, 0));
				}
			}
			else {
				if (value < 1000)
					statValue[i].setText(f_to_s(value, 0));
				else
					statValue[i].setText(standardize(value));
			}
		}
	}

	void update(float time) {
		Empire@ emp = getActiveEmpire();

		// Update stats periodically
		if (statUpdateTimer >= 2.f) {
			statUpdateTimer = 0.f;
			updateStats(emp);
		}
		else
			statUpdateTimer += time;

		// Detect when the active empire changes
		if (lastEmp !is emp) {
			@lastEmp = emp;
			onEmpireChange(emp);
		}

		// Update the tab
		for (uint i = 0; i < tabs.length(); ++i)
			tabs[i].update(tabs[i] is activeTab, time);
	}

	EventReturn onMouseEvent(GuiElement@ ele, const MouseEvent& evt) {
		DragResizeEvent re = handleDragResize(ele, evt, drag, MIN_WIDTH, MIN_HEIGHT);
		if (re != RE_None) {
			if (re == RE_Resized)
				syncPosition(ele.getSize());
			return ER_Absorb;
		}

		if (activeTab is null)
			return ER_Pass;
		return activeTab.onMouseEvent(ele, evt);
	}

	EventReturn onGUIEvent(GuiElement@ ele, const GUIEvent& evt) {
		if (evt.EventType == GEVT_Focus_Gained && evt.Caller.isAncestor(ele)) {
			ele.bringToFront();
			bindEscapeEvent(ele);
		}
		else if (evt.EventType == GEVT_Closed) {
			closeEmpireWindow(this);
			return ER_Absorb;
		}

		Empire@ emp = getActiveEmpire();
		switch (evt.EventType) {
			case GEVT_Clicked:
				if (evt.Caller is close) {
					closeEmpireWindow(this);
					return ER_Pass;
				}
				if (evt.Caller is civilActsButton) {
					showCivilActsWin();
					return ER_Pass;
				}
				else if (evt.Caller is fleetsButton) {
					showFlWin(true);
					return ER_Pass;
				}
				else if (evt.Caller is objListButton) {
					showObjectList();
					return ER_Pass;
				}
				else if (evt.Caller is advisorButton) {
					toggleAdvisorWindow();
					return ER_Pass;
				}
			break;
			case GEVT_Checkbox_Toggled:
				if (evt.Caller is autoGovCheck) {
					emp.setSetting("autoGovern", autoGovCheck.isChecked() ? 1.f : 0.f);
					return ER_Pass;
				}
				else if (evt.Caller is autoParkCheck) {
					emp.setSetting("autoPark", autoParkCheck.isChecked() ? 1.f : 0.f);
					return ER_Pass;
				}
 				else if (evt.Caller is autoTerraCheck) {
 					emp.setSetting("autoTerra", autoTerraCheck.isChecked() ? 1.f : 0.f);
 					EmpireObjects objects;
 					objects.prepare(emp);
 					do
 					{
 						Object@ obj = objects.getObject();
 						if( obj.hasState(strTerraform) )
 							obj.setFlag(setAutoTerra, autoTerraCheck.isChecked());
 					} while(objects.nextObject());
 					return ER_Pass;
 				}
			break;
			case GEVT_ComboBox_Changed:
				if (evt.Caller is governorTypes) {
					int selected = governorTypes.getSelected();
					if(selected > 0)
						emp.setSetting("defaultGovernor", float(selected));
					else
						emp.setSetting("defaultGovernor", -1.f);
					return ER_Pass;
				}
			break;
		}

		if (activeTab is null)
			return ER_Pass;
		return activeTab.onGUIEvent(ele, evt);
	}

	EventReturn onKeyEvent(GuiElement@ ele, const KeyEvent& evt) {
		if (activeTab is null)
			return ER_Pass;
		return activeTab.onKeyEvent(ele, evt);
	}
};
/* }}} */
/* {{{ Diplomacy tab */
int PANEL_WIDTH = 342;
int PANEL_HEIGHT = 70;
int PANEL_PADDING = 6;

class DiplomacyTab : EmpireTab {
	DiplomacyPanel@[] panels;
	GuiPanel@ panel;
	GuiStaticText@ aloneText;

	dim2di lastSize;
	uint panelUpdate;
	uint metMask;

	DiplomacyTab() {
		metMask = 0;
		panelUpdate = 0;
	}

	void init(GuiPanel@ ele) {
		@panel = ele;
		@aloneText = GuiStaticText(recti(20, 20, 40, 40), localize("#EM_AllAlone"), false, false, false, panel);
		aloneText.setTextAlignment(EA_Center, EA_Center);
	}

	void remove() {
		uint cnt = panels.length();
		for (uint i = 0; i < cnt; ++i)
			panels[i].remove();
	}
	
	void syncPosition(dim2di newSize) {
		lastSize = newSize;
		aloneText.setSize(newSize - dim2di(40, 40));

		updatePanelPositions(newSize);
		panel.fitChildren();
		panel.fitChildren();
	}

	void updatePanelPositions(dim2di size) {
		int x = 8, y = 8;
		uint cnt = panels.length();

		int perRow = floor((size.width - 30) / (PANEL_WIDTH + PANEL_PADDING));
		int width = (size.width - 30) / perRow - PANEL_PADDING;
		dim2di pSize = makeEven(dim2di(width, PANEL_HEIGHT), true, true);

		for (uint i = 0; i < cnt; ++i) {
			panels[i].setPosition(pos2di(x, y));
			panels[i].setSize(pSize);

			x += width + PANEL_PADDING;
			if (x + width + PANEL_PADDING > size.width) {
				x = 8;
				y += PANEL_HEIGHT + PANEL_PADDING;
			}
		}
	}

	void draw(recti area) {
		pos2di topLeft = area.UpperLeftCorner;
		pos2di botRight = area.LowerRightCorner;
		dim2di size = area.getSize();

		drawLightArea(area);
	}

	bool updateEmpires(Empire@ forEmp) {
		uint curMetMask = forEmp.getMetMask();
		if (curMetMask == metMask)
			return false;

		uint empCnt = getEmpireCount();
		for (uint i = 0; i < empCnt; ++i) {
			const Empire@ emp = getEmpire(i);

			// Skip over invalid empires and us
			if (!emp.isValid() || emp.ID < 0 || emp is forEmp)
				continue;

			// Skip over empires we've met before
			if (emp.getMask() & metMask != 0)
				continue;

			// Skip over empires we haven't met yet
			if (emp.getMask() & curMetMask == 0)
				continue;

			uint n = panels.length();
			panels.resize(n+1);
			@panels[n] = DiplomacyPanel(emp, panel);
		}

		aloneText.setVisible(panels.length() == 0);
		metMask = curMetMask;
		return true;
	}

	void update(bool active, float time) {
		if (!active)
			return;

		// Check if we've met any more empires
		if (updateEmpires(getActiveEmpire())) {
			updatePanelPositions(lastSize);
			panel.fitChildren();
		}

		// Update one panel at a time
		uint panelCnt = panels.length();
		if (panelUpdate < panelCnt) {
			panels[panelUpdate].update();
			panelUpdate = (panelUpdate + 1) % panelCnt;
		}
		else {
			panelUpdate = 0;
		}
	}

	void onEmpireChange(Empire@ emp) {
	}

	EventReturn onMouseEvent(GuiElement@ ele, const MouseEvent& evt) {
		return ER_Pass;
	}

	EventReturn onGUIEvent(GuiElement@ ele, const GUIEvent& evt) {
		return ER_Pass;
	}

	EventReturn onKeyEvent(GuiElement@ ele, const KeyEvent& evt) {
		return ER_Pass;
	}
};

class DiplomacyPanel : GuiCallback {
	GuiSkinnable@ panel;
	EmpireImage@ img;
	const Empire@ emp;
	int guiID;
	bool alliance;

	GuiStaticText@ empName;
	GuiStaticText@ playerName;
	GuiStaticText@ desc;
	GuiButton@ statusIcon;

	TreatyIcon@[] treaties;
	uint usedTreaties;

	DiplomacyPanel(const Empire@ Emp, GuiElement@ parent) {
		@emp = Emp;
		alliance = false;

		@panel = GuiSkinnable(getSkinnable("EmpirePanel"), recti(0, 0, PANEL_WIDTH, PANEL_HEIGHT), parent);
		@img = EmpireImage(emp, recti(4, 20, 66, 66), panel);

		img.setCallback(showProfileMsg);

		@empName = GuiStaticText(recti(4, 2, 184, 20), emp.getName(), false, false, false, panel);
		empName.setFont("title");
		empName.setColor(emp.color);

		@playerName = GuiStaticText(recti(184, 2, 300, 20), emp.getPlayerName(), false, false, false, panel);
		playerName.setTextAlignment(EA_Right, EA_Top);
		playerName.setFont("title");

		@desc = GuiStaticText(recti(74, 52, 73, 55), null, false, false, false, panel);

		@statusIcon = GuiButton(recti(0, 0, 16, 16), null, panel);
		statusIcon.setVisible(false);

		usedTreaties = 0;
		guiID = reserveGuiID();
		empName.setID(guiID);
		bindGuiCallback(guiID, this);
	}

	void resetTreaties() {
		usedTreaties = 0;
	}

	void clearTreaties() {
		for(uint i = usedTreaties; i < treaties.length(); ++i)
			treaties[i].icon.remove();
		treaties.resize(usedTreaties);
	}

	TreatyIcon@ addTreaty(const Treaty@ treaty, bool active) {
		uint prevCount = treaties.length();

		if (usedTreaties < prevCount) {
			TreatyIcon@ icon = treaties[usedTreaties];
			icon.setTreaty(treaty, active);
			++usedTreaties;
			return icon;
		}
		else {
			treaties.resize(prevCount + 1);
			@treaties[prevCount] = TreatyIcon(treaty, active, panel);
			treaties[prevCount].setID(guiID);
			++usedTreaties;
			return treaties[prevCount];
		}
	}

	bool OnEvent(const GUIEvent& evt) {
		switch (evt.EventType) {
			case GEVT_Clicked: {
				uint treatyCnt = treaties.length();
				for (uint i = 0; i < treatyCnt; ++i) {
					if (evt.Caller is treaties[i].icon)
						return treaties[i].OnClick(emp);
				}
			} break;
			case GEVT_Mouse_Over: {
				uint treatyCnt = treaties.length();
				for (uint i = 0; i < treatyCnt; ++i) {
					if (evt.Caller is treaties[i].icon || evt.Caller is treaties[i].timeText) {
						desc.setText(treaties[i].getDescription());
						return true;
					}
				}
			} break;
			case GEVT_Mouse_Left: {
				uint treatyCnt = treaties.length();
				for (uint i = 0; i < treatyCnt; ++i) {
					if (evt.Caller is treaties[i].icon || evt.Caller is treaties[i].timeText) {
						desc.setText(null);
						return true;
					}
				}
			} break;
		}
		return false;
	}

	void update() {
		// Update player name
		playerName.setText(emp.getPlayerName());
		playerName.setTextAlignment(EA_Right, EA_Top);	
		// Update extinct
		if (emp.getFlag(empLost)) {
			statusIcon.setVisible(false);
			empName.setText(combine(emp.getName()," (", localize("#EM_Dead"),")"));

			resetTreaties();
			clearTreaties();
			panel.setColor(Color(0xffffcf99));
		}
		else {
			// Update treaties
			{
				TreatyList treaties;
				treaties.prepare(getActiveEmpire());

				int x = panel.getSize().width - 36 - 26;
				int y = 22;

				resetTreaties();
				Treaty@ proposed = treaties.getProposedTreaty(emp);
				if(@proposed != null)
					addTreaty(proposed, false).setPosition(pos2di(98, y));
				
				for(uint i = 0; i < treaties.getTreatyCount(); ++i) {
					Treaty@ treaty = treaties.getTreaty(i);
					if(treaty.getToEmpire() is emp || treaty.getFromEmpire() is emp) {
						addTreaty(treaty, true).setPosition(pos2di(x, y));
						x -= 26;
					}
				}
				
				addTreaty(null, false).setPosition(pos2di(72, y));
				clearTreaties();
			}

			alliance = getActiveEmpire().isAllied(emp);

			// Update status
			if (getActiveEmpire().isEnemy(emp)) {
				statusIcon.setImages("diplo_state_war", "diplo_state_war");
				statusIcon.setToolTip(localize("#EM_AtWar"));
				statusIcon.setVisible(true);
				panel.setColor(Color(0xffffa9a9));
			}
			else {
				statusIcon.setVisible(false);

				if (alliance)
					panel.setColor(Color(0xffc4ff8f));
				else
					panel.setColor(Color(0xffffffff));
			}
		}
	}

	void setPosition(pos2di pos) {
		panel.setPosition(pos);
	}

	void setSize(dim2di size) {
		panel.setSize(size);
		statusIcon.setPosition(pos2di(size.width - 25, 35));
		
		if (emp.getPlayerName().length() == 0)
			empName.setSize(dim2di(size.width - 8, 18));
		else
			empName.setSize(dim2di(size.width - 128, 18));

		playerName.setPosition(pos2di(size.width - 120, 2));
		desc.setSize(dim2di(size.width - 74 - 36, 16));
		update();
	}
	
	void remove() {
		clearGuiCallback(guiID);
	}
};

class TreatyIcon {
	GuiButton@ icon;
	GuiStaticText@ timeText;
	const Treaty@ treaty;
	bool active;
	
	TreatyIcon(const Treaty@ represent, bool activeTreaty, GuiElement@ parent) {
		@icon = GuiButton(recti(0, 0, 26, 26), null, parent);
		icon.setAppearance(BA_ScaleImage, BA_Background);

		@timeText = GuiStaticText(recti(0, 0, 26, 26), null, false, false, false, icon);
		timeText.setFont("stroked");
		timeText.setTextAlignment(EA_Center, EA_Center);
		timeText.setVisible(false);
		timeText.setColor(Color(0xff99ff33));

		setTreaty(represent, activeTreaty);
	}

	void setTreaty(const Treaty@ newTreaty, bool activeTreaty) {
		@treaty = newTreaty;
		active = activeTreaty;

		const string@ material;
		if(treaty is null) {
			@material = "treaty_new";
		} else if(activeTreaty) {
			@material = @treaty.getClause(0).icon;
		} else {
			@material = "treaty_proposed";
		}

		if (treaty !is null && activeTreaty) {
			float time = 0;
			uint clauseCnt = treaty.clauseCount;
			for (uint i = 0; i < clauseCnt; ++i) {
				const Clause@ cl = treaty.getClause(i);
				if (cl.optionCount > 0 && cl.id == "timeout")
					time = cl.getOption(0).toFloat();
			}

			if (time > 0) {
				timeText.setText(f_to_s(ceil(time / 60.f), 0)+"m");
				timeText.setVisible(true);
			}
			else {
				timeText.setVisible(false);
			}
		}
		else {
			timeText.setVisible(false);
		}

		icon.setImages(material, material);
	}

	void setID(int ID) {
		icon.setID(ID);
		timeText.setID(ID);
	}

	void setPosition(pos2di pos) {
		icon.setPosition(pos);
	}
	
	bool OnClick(const Empire@ emp) {
		if(treaty is null)
			proposeNewTreaty(emp);
		else
			showTreaty(treaty);
		return false;
	}
	
	string@ getDescription() {
		if(treaty is null)
			return localize("#EM_TreatyCreate");
		else if(active)
			return combine(localize("#EM_TreatyActiveWith"), " ", i_to_s(treaty.clauseCount), " ", localize("#EM_Clauses"));
		else
			return combine(localize("#EM_TreatyProposedText"), " ", treaty.getFromEmpire().getName(), localize("#EM_TreatyProposedEmpire"));
	}
};
/* }}} */
//{{{ Treaty Notifier
//=========
GuiElement@ treatyNotice;


void showTreatyNotice() {
	if(treatyNotice is null) {
		@treatyNotice = GuiScripted( recti(pos2di(0,0),dim2di(16,16)), notification_icon("event_sheet",2), null );
		showEventIndicator(treatyNotice);

		playSound("new_treaty");
	}
	treatyNotice.setToolTip(localize("#EMTT_TreatyNotice"));
}

void OnNotificationAccept(notification_icon@ evt) {
	hideEventNotifiers();
	toggleEmpireWindow(true);
}

//=========

void hideEventNotifiers() {
	if(treatyNotice is null)
		return;
	hideEventIndicator(treatyNotice);
	treatyNotice.remove();
	@treatyNotice = null;
}
void OnNotificationDismiss(notification_icon@ evt) {
	hideEventNotifiers();
}
// }}}
/* {{{ Multiplayer empire chooser */
GuiDraggable@ chooseWin;
GuiExtText@[] empText;
GuiButton@[] empButton;
GuiButton@ spectateButton;
int[] empIDs;

void updateChooseWindow() {
	// Ignore things that aren't MP clients
	if (!isClient())
		return;

	// Create window when empire is not valid
	if (chooseWin is null) {
		if (isClient() && !getActiveEmpire().isValid() && !choseSpectator)
			createChooseWindow();
		return;
	}

	// Remove window after empire becomes valid
	if (getActiveEmpire().isValid()) {
		destroyChooseWindow();
		return;
	}

	int empCnt = empIDs.length();
	for (int i = 0; i < empCnt; ++i) {
		const Empire@ emp = getEmpireByID(empIDs[i]);
		empButton[i].setVisible(emp.getPlayerName() == "");
		empButton[i].setText(combine(localize("#EM_PlayAs"), " ", emp.getName()));
		empText[i].setText(combine("#c:", emp.color.format(), "#" + emp.getName(), "#c##tab:150#", emp.getPlayerName()));
	}
}

bool playAsEmpire(const GUIEvent@ evt) {
	if (evt.EventType == GEVT_Clicked) {
		int empCnt = empButton.length();
		for (int i = 0; i < empCnt; ++i) {
			if (evt.Caller is empButton[i]) {
				playAsEmpire(getEmpireByID(empIDs[i]));
				destroyChooseWindow();
				return true;
			}
		}
	}
	return false;
}

bool choseSpectator = false;
bool playAsSpectator(const GUIEvent@ evt) {
	if (evt.EventType == GEVT_Clicked) {
		playAsSpectator();
		destroyChooseWindow();
		choseSpectator = true;
		return true;
	}
	return false;
}

void createChooseWindow() {
	if (!isClient())
		return;

	if (chooseWin !is null) {
		chooseWin.setVisible(true);
		chooseWin.bringToFront();
		return;
	}

	@chooseWin = GuiDraggable(getSkinnable("Dialog"), makeScreenCenteredRect(dim2di(400, 300)), true, null);
	
	GuiPanel@ choosePanel = GuiPanel(recti(7, 40, 393, 493), false, SBM_Auto, SBM_Invisible, chooseWin);
	choosePanel.fitChildren();
	choosePanel.orphan(true);

	GuiStaticText(recti(11, 23, 389, 40), localize("#EM_ChooseEmpire"), false, false, false, chooseWin).orphan(true);

	int y = 4;
	int empCnt = getEmpireCount();
	int realCnt = 0;
	int playID = reserveGuiID();

	bindGuiCallback(playID, "playAsEmpire");

	empText.resize(empCnt);
	empButton.resize(empCnt);
	empIDs.resize(empCnt);

	for (int i = 0; i < empCnt; ++i) {
		const Empire@ emp = getEmpire(i);

		if (emp.isReserved() || !emp.isValid() || emp.ID < 0)
			continue;

		@empText[realCnt] = GuiExtText(recti(8, y, 259, y + 20), choosePanel);
		@empButton[realCnt] = Button(recti(260, y+1, 380, y + 19), localize("#EM_PlayAs"), choosePanel);

		empButton[realCnt].setID(playID);
		empIDs[realCnt] = emp.ID;

		y += 24;
		++realCnt;
	}

	if(getGameSetting("SV_ALLOW_SPECTATORS", 0.f) > 0.5) {
		@spectateButton = Button(recti(8, y+1, 128, y + 19), localize("#EM_Spectate"), choosePanel);
		bindGuiCallback(spectateButton, "playAsSpectator");
		y += 24;
	}

	if (y < 300) {
		recti pos = makeScreenCenteredRect(dim2di(400, y+50));
		chooseWin.setSize(pos.getSize());
		chooseWin.setPosition(pos.UpperLeftCorner);
	}

	empText.resize(realCnt);
	empButton.resize(realCnt);
	empIDs.resize(realCnt);

	updateChooseWindow();
}

void destroyChooseWindow() {
	chooseWin.remove();
	@chooseWin = null;
	empText.resize(0);
	empButton.resize(0);
	empIDs.resize(0);
}
/* }}} */

void showProfileMsg(const Empire@ emp) {
	if (emp is null)
		return;

	string@ text = combine("#font:frank_12##c:", emp.color.format(), "#", emp.getName(), "#c##font#\n");
	text += combine(localize("#RP_Race"), "#tab:120#", emp.getRaceName(), "\n\n");
	text += combine("#font:frank_10b#", localize("#RP_Background"), "#font#\n", emp.getRaceDescription(), "\n\n");
	text += combine("#font:frank_10b#", localize("#RP_Traits"), "#font#\n");

	EmpireTraits traits;
	traits.prepare(emp);

	if (traits.getCount() == 0) {
		text += localize("#RP_NoTraits");
	}
	else {
		do {
			Trait@ desc = traits.getTrait();
			text += combine("#c:759ca6#", desc.getName(), "#c#\n#font:frank_10i#", desc.getDescription(), "#font#\n");
		}
		while (traits.next());
	}

	traits.prepare(null);

	addMessageDialog(text, null);
}

void createEmpireWindow() {
	uint n = wins.length();
	wins.resize(n+1);
	@wins[n] = EmpireWindowHandle(makeScreenCenteredRect(defaultSize));
	wins[n].addTab(DiplomacyTab());
	wins[n].switchTab(0);
	wins[n].bringToFront();
}

void closeEmpireWindow(EmpireWindow@ win) {
	int index = findEmpireWindow(win);
	if (index < 0) return;

	if (wins.length() > 1) {
		wins[index].remove();
		wins.erase(index);
	}
	else {
		wins[index].setVisible(false);
	}
	setGuiFocus(null);
}

GuiElement@ getEmpireWindow() {
	if (wins.length() == 0)
		return null;
	return wins[0].ele;
}

void toggleEmpireWindow() {
	bool anyVisible = false;
	for (uint i = 0; i < wins.length(); ++i)
		if (wins[i].isVisible())
			anyVisible = true;
	toggleEmpireWindow(!anyVisible);
}

void toggleEmpireWindow(bool show) {
	// If we're in multiplayer and we don't have a valid empire,
	// show a dialog to choose one
	if (show && isClient() && !getActiveEmpire().isValid() && !choseSpectator) {
		createChooseWindow();
		return;
	}

	if (shiftKey || wins.length() == 0) {
		createEmpireWindow();
	}
	else {
		// Toggle all windows to a particular state
		for (uint i = 0; i < wins.length(); ++i) {
			wins[i].setVisible(show);
			if (show)
				wins[i].bringToFront();
		}
		if (show) {
			hideEventNotifiers();
		}
	}
}

bool ToggleEmpireWin(const GUIEvent@ evt) {
	if (evt.EventType == GEVT_Clicked) {
		toggleEmpireWindow();
		return true;
	}
	return false;
}

bool ToggleEmpireWin_key(uint8 flags) {
	if (flags & KF_Pressed != 0) {
		toggleEmpireWindow();
		return true;
	}
	return false;
}

int findEmpireWindow(EmpireWindow@ win) {
	for (uint i = 0; i < wins.length(); ++i)
		if (wins[i].script is win)
			return i;
	return -1;
}

EmpireWindowHandle@[] wins;

GuiButton@ ew_restore_ew;
dim2di defaultSize;

uint realEmpCnt;
uint statStart;

void setEmpVisible(bool vis) {
	ew_restore_ew.setVisible(vis);
}
void init() {
	// Count the number of actual empires
	uint cnt = getEmpireCount();
	for (uint i = 0; i < cnt; ++i) {
		const Empire@ emp = getEmpire(i);

		if (emp.isValid() && emp.ID >= 0)
			++realEmpCnt;
	}

	// Check if we should display ranking stats
	statStart = (realEmpCnt > 2 || getGameSetting("GAME_TWO_PLAYER_RANKINGS", 0.f) > 0.5) ? 0 : 4;

	// Initialize some constants
	initSkin();
	defaultSize = dim2di(890, 571);

	// Toggle key
	bindFuncToKey("F1", "script:ToggleEmpireWin_key");

	// Topbar button
	int width = getScreenWidth();
	@ew_restore_ew = GuiButton(recti(pos2di(width / 2 - 250, 0), dim2di(100, 25)), null, null);
	ew_restore_ew.setSprites("TB_Empire", 0, 2, 1);
	ew_restore_ew.setAppearance(BA_UseAlpha, BA_Background);
	ew_restore_ew.setAlignment(EA_Center, EA_Top, EA_Center, EA_Top);
	bindGuiCallback(ew_restore_ew, "ToggleEmpireWin");
}

uint newestProposedTreaty = 0;

int empCheckTreaty = 0;
void tick(float time) {
	updateChooseWindow();

	bool anyVisible = false;
	for (uint i = 0; i < wins.length(); ++i) {
		if (wins[i].isVisible()) {
			wins[i].update(time);
			anyVisible = true;
		}
	}

	if (!anyVisible) {
		if(treatyNotice is null) {
			Empire@ us = getActiveEmpire();
			const Empire@ other = getEmpire(empCheckTreaty);

			if (other.isValid() && other !is us) {
				TreatyList treaties;
				treaties.prepare(us);

				const Treaty@ proposed = treaties.getProposedTreaty(other);
				if(proposed !is null && proposed.getFromEmpire() is other && uint(proposed.getID()) > newestProposedTreaty) {
					showTreatyNotice();
					newestProposedTreaty = uint(proposed.getID());
				}
			}
			
			empCheckTreaty = (empCheckTreaty + 1) % getEmpireCount();
		}
	}
}
