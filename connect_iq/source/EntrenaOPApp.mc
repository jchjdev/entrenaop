import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Time;

(:background)
class EntrenaOPApp extends Application.AppBase {
    private var _foregroundInstance as Boolean=false;
    function initialize() { AppBase.initialize(); }
    // Este punto de entrada solo se invoca en primer plano, como en el SDK oficial.
    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        _foregroundInstance=true;
        try { ciqSuspendChecks(); } catch(error) { }
        var view = new CiqView();
        return [view, new CiqDelegate(view)];
    }
    function onStop(state as Dictionary?) as Void {
        // La instancia del servicio no debe reprogramar eventos al terminar.
        if (!_foregroundInstance) { return; }
        try { ciqResumeChecks(); }
        catch(error) {
            Storage.setValue("ciqBackgroundState","Error al programar consulta");
            Storage.setValue("ciqBackgroundStateAt",Time.now().value());
        }
    }
    function getServiceDelegate() as [System.ServiceDelegate] { return [new CiqBackground()]; }
}
