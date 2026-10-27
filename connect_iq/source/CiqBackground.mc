import Toybox.Application;
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
    function recordState(state as String) as Void {
        Storage.setValue("ciqBackgroundState",state);
        Storage.setValue("ciqBackgroundStateAt",Time.now().value());
    }
    function onTemporalEvent() as Void {
        var credential=Storage.getValue("ciqCredential");
        var enabled=Storage.getValue("ciqBackgroundEnabled");
        if (!(enabled instanceof Boolean) || !enabled || !(credential instanceof String) ||
            Storage.getValue("ciqPairCode")!=null) { recordState("Consulta desactivada"); finish(); return; }
        recordState("Esperando respuesta"); Storage.setValue("ciqBackgroundHttp",0);
        // Timer no está disponible en background. Garmin limita este proceso a 30 s.
        try {
            Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/watch",
                {"action"=>"changes"},{:method=>Communications.HTTP_REQUEST_METHOD_POST,
                :headers=>{"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON,"Authorization"=>"Bearer "+credential},
                :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},method(:onChanges));
        } catch(error) { recordState("Error al solicitar"); finish(); }
    }
    function onChanges(code as Number,data as Communications.ContentType?) as Void {
        Storage.setValue("ciqBackgroundHttp",code); recordState("Respuesta recibida");
        // Un permiso retirado o perdido no debe seguir generando consultas de red.
        if (code==401 || code==403) { Storage.setValue("ciqBackgroundEnabled",false); }
        if (code!=200) { recordState("Error de respuesta"); finish(); return; }
        try {
            if (!(data instanceof Dictionary)) { recordState("Respuesta incompleta"); finish(); return; }
            var revision=ciqChangesRevision(data);
            if (revision==null) { recordState("Respuesta incompleta"); finish(); return; }
            var local=Storage.getValue("ciqLocalRevision");
            Storage.setValue("ciqPending",!(local instanceof String) || !revision.equals(local));
            Storage.setValue("ciqLastCheck",Time.now().value());
            var enabled=Storage.getValue("ciqChangeAlertsEnabled");
            var notified=Storage.getValue("ciqNotifiedRevision");
            if (!(enabled instanceof Boolean) || !enabled) { recordState("Avisos desactivados"); }
            else if (local instanceof String && revision.equals(local)) { recordState("Ya está actualizado"); }
            else if (notified instanceof String && revision.equals(notified)) { recordState("Cambio ya avisado"); }
            else if (foregroundActive()) { recordState("App en primer plano"); }
            else if (ciqShouldAlert(true,revision,local instanceof String?local:null,notified instanceof String?notified:null)) {
                try {
                    // Un aviso por huella; el usuario elige abrir y el FIT se importa en primer plano.
                    showChangeAlert();
                    Storage.setValue("ciqNotifiedRevision",revision);
                    recordState("Aviso solicitado");
                } catch(error) { recordState("Error al pedir aviso"); }
            }
        } catch(error) { recordState("Error al procesar respuesta"); }
        finish();
    }
    function foregroundActive() as Boolean { return Application.getApp().isActive(); }
    function showChangeAlert() as Void { Background.requestApplicationWake("Tus sesiones han cambiado. ¿Actualizar EntrenaOP?"); }
    function finish() as Void { Background.exit(null); }
}
