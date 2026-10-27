import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;

(:background)
function ciqProbeHeld() as Boolean {
    var value=Storage.getValue("ciqProbeMode"); return value instanceof Boolean && value;
}
(:background)
function ciqProbePhaseIs(expected as String) as Boolean {
    var value=Storage.getValue("ciqProbePhase"); return value instanceof String && value.equals(expected);
}

// Ensayo acotado a una cita y una revisión que no existía al armarlo.
// El 200 no acredita importación: la biblioteca se comprobará después, sin red.
(:background)
class CiqSilentProbe {
    private var _run as Number=0;
    private var _finished as Boolean=false;
    private var _credential as String="";
    private var _began as Number=0;
    function initialize() { }
    function record(phase as String,state as String) as Void {
        Storage.setValue("ciqProbePhase",phase); Storage.setValue("ciqProbeState",state);
        Storage.setValue("ciqProbeAt",Time.now().value());
    }
    function run() as Void {
        if (!ciqProbeHeld() || !ciqProbePhaseIs("armed")) { finish(); return; }
        var generation=Storage.getValue("ciqProbeRun"); var credential=Storage.getValue("ciqCredential");
        var started=Storage.getValue("ciqProbeStarted");
        if (!(generation instanceof Number) || !(credential instanceof String) ||
            Storage.getValue("ciqPairCode")!=null || !(started instanceof Number)) {
            fail("Vínculo no disponible"); return;
        }
        _run=generation; _credential=credential; _began=Time.now().value();
        if (_began-started>1800) { fail("Prueba caducada (30 min)"); return; }
        record("manifest","Consultando en fondo");
        try { requestManifest(); } catch(error) { fail("No se pudo consultar"); }
    }
    function requestManifest() as Void {
        Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/watch",
            {"action"=>"manifest"},{:method=>Communications.HTTP_REQUEST_METHOD_POST,
            :headers=>{"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON,"Authorization"=>"Bearer "+_credential},
            :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},method(:onManifest));
    }
    private function current() as Boolean {
        var generation=Storage.getValue("ciqProbeRun");
        return !_finished && ciqProbeHeld() && generation instanceof Number && generation==_run;
    }
    function onManifest(code as Number,data as Communications.ContentType?) as Void {
        if (!current()) { finish(); return; }
        if (!ciqProbePhaseIs("manifest")) { return; }
        Storage.setValue("ciqProbeManifestHttp",code);
        if (code!=200 || !(data instanceof Dictionary)) { fail("Consulta fallida: "+code); return; }
        try {
            var entries=ciqManifestEntries(data as Dictionary);
            var target=Storage.getValue("ciqProbeTarget"); var baseline=Storage.getValue("ciqProbeBaseline");
            if (entries==null || !(target instanceof String) || !(baseline instanceof Array)) {
                fail("Lista de prueba inválida"); return;
            }
            var candidate=null as Dictionary?;
            for (var index=0;index<entries.size();index++) {
                var entry=entries[index];
                var appointment=entry["scheduled_id"];
                if (!(appointment instanceof String) || !appointment.equals(target)) { continue; }
                if (candidate!=null) { fail("Cita duplicada en lista"); return; }
                candidate=entry;
            }
            if (candidate==null || (baseline as Array).indexOf(candidate["fit_name"])>=0) {
                record("armed","Esperando revisión nueva"); finish(); return;
            }
            // Conservar margen dentro del máximo de 30 s del servicio de Garmin.
            if (Time.now().value()-_began>=25) { fail("Consulta demasiado lenta"); return; }
            Storage.setValue("ciqProbeName",candidate["fit_name"] as String);
            Storage.setValue("ciqProbeExport",candidate["id"] as String);
            record("fit","FIT solicitado en fondo"); stopEvent();
            requestFit(candidate["id"] as String);
        } catch(error) { fail("Error al preparar FIT"); }
    }
    function requestFit(id as String) as Void {
        Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/fit/"+
            Communications.encodeURL(id),null,{:method=>Communications.HTTP_REQUEST_METHOD_GET,
            :headers=>{"Authorization"=>"Bearer "+_credential},
            :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT},method(:onFit));
    }
    function onFit(code as Number,data as Communications.ContentType?) as Void {
        if (!current()) { finish(); return; }
        if (!ciqProbePhaseIs("fit")) { return; }
        Storage.setValue("ciqProbeFitHttp",code);
        // No tocar PersistedContent en background ni confundir respuesta con instalación.
        record(code==200?"response":"failed",code==200?"FIT recibido; falta comprobar":"FIT rechazado: "+code);
        finish();
    }
    private function stopEvent() as Void { try { Background.deleteTemporalEvent(); } catch(error) { } }
    private function fail(state as String) as Void { record("failed",state); stopEvent(); finish(); }
    function finish() as Void { if (_finished) { return; } _finished=true; exitService(); }
    function exitService() as Void { Background.exit(null); }
}
