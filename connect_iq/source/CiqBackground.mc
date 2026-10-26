import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Se ejecuta solo si el usuario activa la comprobación desde el menú del reloj.
// No importa, elimina ni abre FIT: únicamente consulta una huella de cambios.
(:background)
class CiqBackground extends System.ServiceDelegate {
    function initialize() { ServiceDelegate.initialize(); }
    function onTemporalEvent() as Void {
        var credential=Storage.getValue("ciqCredential");
        var enabled=Storage.getValue("ciqBackgroundEnabled");
        if (!(enabled instanceof Boolean) || !enabled || !(credential instanceof String) ||
            Storage.getValue("ciqPairCode")!=null) { Background.exit(null); return; }
        // Timer no está disponible en background. Garmin limita este proceso a 30 s.
        try {
            Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/watch",
                {"action"=>"changes"},{:method=>Communications.HTTP_REQUEST_METHOD_POST,
                :headers=>{"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON,"Authorization"=>"Bearer "+credential},
                :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},method(:onChanges));
        } catch(error) { finish(); }
    }
    function onChanges(code as Number,data as Communications.ContentType?) as Void {
        // Un permiso retirado o perdido no debe seguir generando consultas de red.
        if (code==401 || code==403) { Storage.setValue("ciqBackgroundEnabled",false); }
        if (code==200 && data instanceof Dictionary) {
            var revision=data["revision"];
            if (revision instanceof String) {
                var local=Storage.getValue("ciqLocalRevision");
                Storage.setValue("ciqPending",!(local instanceof String) || !revision.equals(local));
                Storage.setValue("ciqLastCheck",Time.now().value());
            }
        }
        finish();
    }
    function finish() as Void { Background.exit(null); }
}
