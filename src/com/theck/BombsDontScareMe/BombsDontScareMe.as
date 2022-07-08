/*
* ...
* @author theck
*/

import com.Utils.Archive;
import com.GameInterface.Game.Character;
import com.Utils.ID32;
import com.Utils.LDBFormat;
import com.Utils.Text;
import com.Utils.GlobalSignal;
import com.Utils.Signal;
import com.GameInterface.VicinitySystem;
import com.GameInterface.Game.Dynel;
import mx.utils.Delegate;
import flash.geom.Point;
import com.theck.BombsDontScareMe.ConfigManager;
import com.theck.Utils.Common;

class com.theck.BombsDontScareMe.BombsDontScareMe 
{
	static var debugMode:Boolean = true;
	
	// Version
	static var version:String = "0.3";
	
	// Signals
	static var SubtitleSignal:Signal;

	// GUI
	private var m_swfRoot:MovieClip;	
	public  var clip:MovieClip;	
	private var m_WarningText:TextField;	
	private var m_pos:flash.geom.Point;
	private var guiEditThrottle:Boolean = true;
	static var COLOR_EXPLOSION:Number = 0xFF0000;
	static var COLOR_POSSESSION:Number = 0x9300FF;
	
	// Config
	private var Config:ConfigManager;
	
	// NPC storage
	private var SurvivorList:Object;
	
	
	//////////////////////////////////////////////////////////
	// Constructor and Mod Management
	//////////////////////////////////////////////////////////
	
	
	public function BombsDontScareMe(swfRoot:MovieClip){
		
        m_swfRoot = swfRoot;
		
		Config = new ConfigManager();
		Config.NewSetting("fontsize", 50, "");
		
		clip = m_swfRoot.createEmptyMovieClip("BombsDontScareMe", m_swfRoot.getNextHighestDepth());
		
		clip._x = Stage.width /  2;
		clip._y = Stage.height / 2;
		
		Config.NewSetting("position", new Point(clip._x, clip._y), "");
		
		// initiate signals and arrays
		SubtitleSignal = new Signal();
		SurvivorList = new Object();
	}

	public function Load(){
		com.GameInterface.UtilsBase.PrintChatText("BombsDontScareMe v" + version + " Loaded");
		
		// TODO: maybe move signal connections to another function and connect/disconnect based on zone? 7602/7612/7622 are scenarios
		
		// connect signals
		GlobalSignal.SignalSetGUIEditMode.Connect(GUIEdit, this);	
		Config.SignalValueChanged.Connect(SettingChanged, this);
        SubtitleSignal.Connect(ProcessSubtitle, this);
		
		// hook subtitle function
        Hook2DText();
		
		// first GUIEdit call to fix locations
		GUIEdit(false);
	}

	public function Unload(){
		
		// disconnect signals
		GlobalSignal.SignalSetGUIEditMode.Disconnect(GUIEdit, this);
        SubtitleSignal.Disconnect(ProcessSubtitle, this);	
		Config.SignalValueChanged.Disconnect(SettingChanged, this);
	}
	
	public function Activate(config:Archive){
		//Debug("Activate()")
		
		Config.LoadConfig(config);
		
		// Create text field and fix visibility
		if ( !m_WarningText ) {
			CreateTextField();
		}		
		SetVisible(m_WarningText, false);
		
		// move clip to location
		SetPosition(Config.GetValue("position") );
		
		
		// connect vicinity system signal
		VicinitySystem.SignalDynelEnterVicinity.Connect(DetectSurvivors, this);
	}

	public function Deactivate():Archive{
		var config = new Archive();
		config = Config.SaveConfig();
		return config;
	}
	
	
	//////////////////////////////////////////////////////////
	// Text Field Controls
	//////////////////////////////////////////////////////////

	
	private function CreateTextField() {
		//Debug("CTF called");
		var fontSize:Number = Config.GetValue("fontsize");
		var m_text:String = "test";		
		
		var textFormat:TextFormat = new TextFormat("_StandardFont", fontSize, 0xFFFFFF, true);
		textFormat.align = "center";
		
		var extents:Object = Text.GetTextExtent("Possession", textFormat, clip);
		var height:Number = Math.ceil( extents.height * 1.10 );
		var width:Number = Math.ceil( extents.width * 1.10 );
		
		//Debug("CTF, height = "+ height + ", width = " + width)
		
		m_WarningText = clip.createTextField("BombsDontScareMe_Warning", clip.getNextHighestDepth(), 0, 0, width, height);
		m_WarningText.setNewTextFormat(textFormat);
		
		InitializeTextField(m_WarningText);
		
		SetText(m_WarningText, m_text );
		
		GUIEdit(false);
	}
	
	private function DestroyTextField() {
		Debug("DTF called");
		m_WarningText.removeTextField();
	}
	
	private function ReCreateTextField() {
		Debug("RCTF called");
		DestroyTextField();
		CreateTextField();
	}
		
	private function InitializeTextField(field:TextField) {
		field.background = true;
		field.backgroundColor = 0x000000;
		field.autoSize = "center";
		field.textColor = COLOR_EXPLOSION;		
		field._alpha = 90;
		//field._visible = true;
	}
	
	private function SetText(field:TextField, textString:String) {
		field.text = textString;		
	}
	
	private function SetVisible(field:TextField, state:Boolean) {
		field._visible = state;
	}
	
	private function SetTextColor(color:Number) {
		m_WarningText.textColor = color;
	}
	
	private function ClearWarning() {
		SetVisible(m_WarningText, false);
	}
	
	private function SetPosition(pos:Point) {
		
		// sanitize inputs - this fixes a bug where someone changes screen resolution and suddenly the field is off the visible screen
		//Debug("pos.x: " + pos.x + "  pos.y: " + pos.y, debugMode);
		if ( pos.x > Stage.width || pos.x < 0 ) { pos.x = Stage.width / 2; }
		if ( pos.y > Stage.height || pos.y < 0 ) { pos.y = Stage.height / 2; }
		
		clip._x = pos.x;
		clip._y = pos.y;
	}
	
	private function GetPosition() {
		var pos:Point = new Point(clip._x, clip._y);
		Debug("GetPos: x: " + pos.x + "  y: " + pos.y, debugMode);
		return pos;
	}
	
	public function EnableInteraction(state:Boolean) {
		clip.hitTestDisable = !state;
	}
	
	public function ToggleBackground(flag:Boolean) {
		m_WarningText.background = flag;
	}
	
	
	//////////////////////////////////////////////////////////
	//  GUI functions
	//////////////////////////////////////////////////////////
	
	
	public function GUIEdit(state:Boolean) {
		//Debug("GUIEdit() called with argument: " + state);
		ToggleBackground(state);
		EnableInteraction(state);
		SetVisible(m_WarningText, state);
		if (state) {
			clip.onPress = Delegate.create(this, WarningStartDrag);
			clip.onRelease = Delegate.create(this, WarningStopDrag);
			SetText(m_WarningText, "~~Move Me~~");
			SetVisible(m_WarningText, true);
			
			// set throttle variable - this prevents extra spam when the game calls GuiEdit event with false argument, which it seems to like to do ALL THE DAMN TIME
			guiEditThrottle = true;
		}
		else if guiEditThrottle {
			clip.stopDrag();
			clip.onPress = undefined;
			clip.onRelease = undefined;
			SetVisible(m_WarningText, false);
			
			// set throttle variable
			guiEditThrottle = false;
			setTimeout(Delegate.create(this, ResetGuiEditThrottle), 100);
		}
	}
	
	public function WarningStartDrag() {
		//Debug("WarningStartDrag called");
        clip.startDrag();
    }

    public function WarningStopDrag() {
		//Debug("WarningStopDrag called");
        clip.stopDrag();
		
		// grab position for config storage on Deactivate()
        m_pos = Common.getOnScreen(clip); 
        Config.SetValue("position", m_pos ); 
		
		Debug("WarningStopDrag: x: " + m_pos.x + "  y: " + m_pos.y);
    }
	
	private function ResetGuiEditThrottle() {
		guiEditThrottle = true;
	}
	
	
	//////////////////////////////////////////////////////////
	// Core Logic
	//////////////////////////////////////////////////////////
	
	
	private function DisplayPossessWarning() {
		SetText(m_WarningText, "Possession");
		SetTextColor(COLOR_POSSESSION);
		SetVisible(m_WarningText, true);	
	}
	
	private function DisplayBombWarning() {
		SetText(m_WarningText, "Explosive");
		SetTextColor(COLOR_EXPLOSION);
		SetVisible(m_WarningText, true);	
	}
	
	private function DisplayTestWarning(text:String) {
		SetText(m_WarningText, text);
		SetTextColor(COLOR_EXPLOSION);
		SetVisible(m_WarningText, true);
		setTimeout(Delegate.create(this, ClearWarning), 2000 );
	}
	
	private function CheckSubtitleTextForWarnings(text:String) {
		
		//Possession: 18639, 18640, 18641
		if ( text.indexOf(LDBFormat.LDBGetText(50000, 18639)) > 0 || text.indexOf(LDBFormat.LDBGetText(50000, 18640)) > 0 || text.indexOf(LDBFormat.LDBGetText(50000, 18641)) > 0 ) {  
			DisplayPossessWarning();
		}
		// fully possessed 18642
		else if ( text == LDBFormat.LDBGetText(50000, 18639) ) {
			Debug("Fully Possessed");
			ClearWarning();
		}
		// Explosive placed: 18644
		else if ( text.indexOf(LDBFormat.LDBGetText(50000, 18644)) > 0 ) { 
			Debug("Explosive Placed");
			DisplayBombWarning();
		}
		// injured 18645; detonated 18646
		else if ( text == LDBFormat.LDBGetText(50000, 18645) || text == LDBFormat.LDBGetText(50000, 18646) ) {
			Debug("Explosive Detonated");		
			ClearWarning();
		}
		// testing
		//else if ( debugMode && ( text.indexOf("i") > 0 ) ) {
			//Debug("Testing");
			//DisplayTestWarning("Testing");
		//}
	}
	
	private function AddSurvivorToList(dynelId:ID32) {
		if ( !SurvivorList[dynelId] ) {
			var char:Character = Character.GetCharacter(dynelId);
			SurvivorList[dynelId] = char;
			SurvivorList[dynelId].SignalBuffRemoved.Connect(OnSurvivorBuffRemoved, this);
			SurvivorList[dynelId].SignalCharacterDestructed.Connect(OnSurvivorDeleted, this);
			//SurvivorList[dynelId].SignalCharacterDied.Connect(OnSurvivorDeleted, this);
			Debug("Survivor added: " + dynelId);
		}
	}
	
	private function OnSurvivorBuffRemoved(buffId:Number) {
		Debug("Buff removed: " + buffId + " " + LDBFormat.LDBGetText( 50210, buffId) );
		
		// Possession has two ids: 9264872 and 9264873. 
		switch ( buffId ) {
			case 9264872: // both of these appear to drop off when possession is cleared
			case 9264873: //
			case 9264874: // These two don't appear to be used, but we'll include them for good measure
			case 9264875: //
				ClearWarning();
				break;
		}
		// Also seen is 9264888, which seems to be removed a long time after someone gets possessed
		// (maybe a lockout timer, or related to letting it go to full term)
	}
	
	private function OnSurvivorDeleted(dynelId:ID32) {
		Debug("OSD arg: " + dynelId);
		SurvivorList[dynelId] = undefined;
	}
	
	//////////////////////////////////////////////////////////
	// Signal Handling
	//////////////////////////////////////////////////////////
	
	public function ProcessSubtitle(args:Array)
    {
		var text:String = args[0];
		//Debug(text);
		
		CheckSubtitleTextForWarnings(text);
    }
    
    private function Hook2DText(){
        if (!_global.com.theck.BombsDontScareMe.SubtitleHook)
        {
            var f:Function = function()
            {
				BombsDontScareMe.SubtitleSignal.Emit(arguments);
                var subtitleUID = arguments.callee.base.apply(this, arguments);
            }
            f.base = _global.com.GameInterface.ProjectUtils.Show2DText;
            _global.com.GameInterface.ProjectUtils.Show2DText = f;
            _global.com.theck.BombsDontScareMe.SubtitleHook = true;
        }
    }
	
	private function SettingChanged(key:String) {
		if ( key != "position" ) {
			// for when settings are updated. Create bar
			ReCreateTextField();
			
			// Move clip to location
			SetPosition( Config.GetValue("position") );
		}
	}
	
	private function DetectSurvivors(dynelId:ID32):Void {
		var dynel:Dynel = Dynel.GetDynel(dynelId);
		var dynel112:Number = dynel.GetStat(112);
		
		// bail if this isn't a character
		if dynelId.GetType() != 50000 {return; }
		
		// these are e17 ids, not sure about other difficulties
		switch ( dynel112 ) {
			
			case 33351: // E14-E17
			case 33352: // E14-E17
			
			case 33123: // E1-E13
			case 33124: // E1-E13
				
			case 33437: // These two don't appear to be used, but let's include them for good measure
			case 33438: // ???
			
			// add to list and monitor
				AddSurvivorToList(dynelId);
				break;
			
			default:
				break;
		}
		//Debug("Dynel Id: " + dynelId + ", GetName(): " + dynel.GetName() + ", GetType(): " + dynelId.GetType() + ", Stat 112: " + dynel.GetStat(112));
		

	}
	//////////////////////////////////////////////////////////
	// Debugging
	//////////////////////////////////////////////////////////
	
	private function Debug(text:String) {
		if debugMode { com.GameInterface.UtilsBase.PrintChatText("BS:" + text ); }
	}
	
}