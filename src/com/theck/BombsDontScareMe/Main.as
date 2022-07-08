/*
* ...
* @author theck
*/
import com.Utils.Archive;
//import com.theck.Rangefinder.Rangefinder;
 
class com.theck.BombsDontScareMe.Main 

{
	private static var s_app:com.theck.BombsDontScareMe.BombsDontScareMe;
	public static function main(swfRoot:MovieClip):Void
	{
		s_app = new com.theck.BombsDontScareMe.BombsDontScareMe(swfRoot);
		swfRoot.onLoad = OnLoad;
		swfRoot.onUnload = OnUnload;
		swfRoot.OnModuleActivated = OnActivated;
		swfRoot.OnModuleDeactivated = OnDeactivated;
	}

	public function Main() { }
	
	public static function OnLoad()
	{
		s_app.Load();
	}
	
	public static function OnUnload()
	{
		s_app.Unload();
	}
	
	public static function OnActivated(config: Archive):Void
	{
		s_app.Activate(config);
	}

	public static function OnDeactivated():Archive
	{
		return s_app.Deactivate();
	}
}