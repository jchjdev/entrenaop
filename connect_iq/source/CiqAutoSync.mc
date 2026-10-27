import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;

// Un manifiesto completo y, como máximo, un FIT por evento. El diario evita
// confundir un 200 o un callback perdido con una instalación verificada.
(:background)
class CiqAutoSync {
    private var _generation as Number=0;
    private var _credential as String="";
    private var _began as Number=0;
    private var _phase as Symbol=:idle;
    private var _name as String="";
    function initialize() { }
    function state(value as String) as Void {
        Storage.setValue("ciqAutoState",value); Storage.setValue("ciqAutoAt",Time.now().value());
    }
    private function current() as Boolean {
        var credential=Storage.getValue("ciqCredential");
        return ciqAutoEnabled() && !ciqProbeHeld() && ciqSyncGeneration()==_generation &&
            credential instanceof String && credential.equals(_credential) && Storage.getValue("ciqPairCode")==null;
    }
    function run() as Void {
        var credential=Storage.getValue("ciqCredential");
        if (!ciqAutoEnabled() || !(credential instanceof String) || Storage.getValue("ciqPairCode")!=null || ciqProbeHeld()) {
            finish(); return;
        }
        ciqCancelSyncCallbacks(); _generation=ciqSyncGeneration();
        _credential=credential; _began=Time.now().value(); _phase=:manifest;
        state("Consultando sesiones"); Storage.setValue("ciqAutoManifestHttp",0);
        try { requestManifest(); } catch(error) { state("Sin conexión; reintentará"); finish(); }
    }
    function requestManifest() as Void {
        Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/watch",
            {"action"=>"manifest"},{:method=>Communications.HTTP_REQUEST_METHOD_POST,
            :headers=>{"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON,"Authorization"=>"Bearer "+_credential},
            :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},method(:onManifest));
    }
    function onManifest(code as Number,data as Communications.ContentType?) as Void {
        if (_phase!=:manifest) { return; }
        if (!current()) { finish(); return; }
        Storage.setValue("ciqAutoManifestHttp",code);
        if (code==401 || code==403) { deny(); return; }
        if (code!=200 || !(data instanceof Dictionary)) { state("Consulta pendiente; reintentará"); finish(); return; }
        var entries=ciqManifestEntries(data as Dictionary);
        if (entries==null) { state("Lista incompleta; reintentará"); finish(); return; }
        ciqSyncKeep(entries);
        var records=ciqSyncRecords(); var candidate=null as Dictionary?; var waiting=false;
        for (var i=0;i<entries.size();i++) {
            var name=entries[i]["fit_name"] as String;
            var record=records[name];
            if (ciqSyncDue(record instanceof Dictionary?record as Dictionary:null,Time.now().value())) { candidate=entries[i]; break; }
            if (record instanceof Dictionary) {
                var phase=record["phase"];
                if (!(phase instanceof String) || !phase.equals("verified")) { waiting=true; }
            }
        }
        if (candidate==null) {
            state(entries.size()==0?"Sin fuerza compatible":(waiting?"Descargas por comprobar":"Sesiones comprobadas")); finish(); return;
        }
        if (Time.now().value()-_began>=25) { state("Consulta lenta; próximo ciclo"); finish(); return; }
        _name=candidate["fit_name"] as String; _phase=:fit;
        ciqSyncAttempt(_name,candidate["id"] as String,Time.now().value(),"segundo plano");
        Storage.setValue("ciqAutoName",_name); Storage.setValue("ciqAutoHttp",0); state("FIT solicitado en fondo");
        try { requestFit(candidate["id"] as String); }
        catch(error) { ciqSyncResponse(_name,Communications.BLE_ERROR); state("Descarga pendiente; reintentará"); finish(); }
    }
    function requestFit(id as String) as Void {
        Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/fit/"+
            Communications.encodeURL(id),null,{:method=>Communications.HTTP_REQUEST_METHOD_GET,
            :headers=>{"Authorization"=>"Bearer "+_credential},
            :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT},method(:onFit));
    }
    function onFit(code as Number,data as Communications.ContentType?) as Void {
        if (_phase!=:fit) { return; }
        if (!current()) { finish(); return; }
        Storage.setValue("ciqAutoHttp",code); ciqSyncResponse(_name,code);
        if (code==401 || code==403) { deny(); return; }
        state(code==200?"FIT recibido; por comprobar":"Descarga pendiente; reintentará"); finish();
    }
    private function deny() as Void {
        Storage.setValue("ciqAutoEnabled",false); Storage.setValue("ciqBackgroundEnabled",false);
        state("Acceso retirado; abre la app"); Background.deleteTemporalEvent(); finish();
    }
    function finish() as Void { if (_phase==:done) { return; } _phase=:done; exitService(); }
    function exitService() as Void { Background.exit(null); }
}
