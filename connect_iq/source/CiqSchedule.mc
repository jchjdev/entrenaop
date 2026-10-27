import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;

// Como BackgroundTimer del SDK: consultar tras salir, suspender al abrir.
// isActive() de la instancia de fondo no identifica el primer plano del usuario.
(:background)
function ciqSuspendChecks() as Void { Background.deleteTemporalEvent(); }

(:background)
function ciqResumeChecks() as Void {
    var enabled=Storage.getValue("ciqBackgroundEnabled");
    var credential=Storage.getValue("ciqCredential");
    if (ciqProbeHeld()) {
        if (ciqProbePhaseIs("armed") && credential instanceof String &&
            Storage.getValue("ciqPairCode")==null) {
            Background.registerForTemporalEvent(new Time.Duration(300));
        } else { Background.deleteTemporalEvent(); }
        return;
    }
    if (!(enabled instanceof Boolean) || !enabled || !(credential instanceof String) ||
        Storage.getValue("ciqPairCode")!=null) {
        Background.deleteTemporalEvent(); return;
    }
    Background.registerForTemporalEvent(new Time.Duration(900));
}
