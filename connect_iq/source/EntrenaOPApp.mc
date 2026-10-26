import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

(:background)
class EntrenaOPApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    // Este punto de entrada solo se invoca en primer plano, como en el SDK oficial.
    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new CiqView();
        return [view, new CiqDelegate(view)];
    }
    function getServiceDelegate() as [System.ServiceDelegate] { return [new CiqBackground()]; }
}
