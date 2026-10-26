import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class DownloadView extends WatchUi.View {
    private var _busy as Boolean = false;
    private var _workout as PersistedContent.Content? = null;
    private var _timer as Timer.Timer;
    private var _stalled as Boolean = false;
    private var _status as String = "Prueba sin cuenta";
    private var _detail as String = "Conecta Garmin Connect";

    function initialize() { View.initialize(); _timer = new Timer.Timer(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var x = dc.getWidth() / 2;
        var y = dc.getHeight() / 2;
        dc.drawText(x, y - 90, Graphics.FONT_SMALL, "EntrenaOP Dev 0.2", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x, y - 35, Graphics.FONT_XTINY, _status, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x, y + 5, Graphics.FONT_XTINY, _detail, Graphics.TEXT_JUSTIFY_CENTER);
        var action = _busy ? "Espera..." : (_workout == null ? "START: descargar" : "START: abrir en Fuerza");
        if (_stalled) { action = "BACK: salir y reabrir"; }
        dc.drawText(x, y + 65, Graphics.FONT_XTINY, action, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function select() as Void {
        if (_busy || _stalled) { return; }
        if (_workout != null) {
            System.exitTo(_workout.toIntent());
            return;
        }
        _busy = true;
        _status = "Descargando FIT";
        _detail = "Mantén el móvil conectado";
        WatchUi.requestUpdate();
        _timer.start(method(:onTimeout), 60000, false);
        try {
            Communications.makeWebRequest(
                "https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq-probe/workout.fit",
                null,
                {:method => Communications.HTTP_REQUEST_METHOD_GET,
                 :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT},
                method(:onDownload));
        } catch (error) {
            fail("No se pudo solicitar");
        }
    }

    function onDownload(code as Number, data as Communications.ContentType?) as Void {
        _busy = false;
        _timer.stop();
        _stalled = false;
        System.println("CIQ probe HTTP=" + code + " iterator=" + (data instanceof PersistedContent.Iterator));
        if (code != 200) { fail("Error de conexión: " + code.toString()); return; }
        // HTTP 200 solo no acredita instalación: el iterador puede estar vacío.
        if (code == 200 && data instanceof PersistedContent.Iterator) {
            var content = data.next();
            System.println("CIQ probe empty=" + (content == null));
            if (content == null) { fail("Garmin no importó el FIT"); return; }
            System.println("CIQ probe content name=" + content.getName() + " id=" + content.getId());
            // Iterator.next() devuelve Content; la clase nativa concreta no es
            // un contrato de identificación. Confirmar en la biblioteca propia.
            var installed = findInstalledProbe(content.getId());
            if (installed != null) {
                _workout = installed;
                _status = "Entrenamiento instalado";
                _detail = "Comprueba nombres y descansos";
                WatchUi.requestUpdate();
                return;
            }
            fail("No figura en biblioteca propia");
            return;
        }
        fail("Respuesta sin iterador FIT");
    }

    private function findInstalledProbe(id as Number) as PersistedContent.Content? {
        var iterator = PersistedContent.getAppWorkouts();
        var content = iterator.next();
        while (content != null) {
            System.println("CIQ probe owned name=" + content.getName() + " id=" + content.getId());
            if (isProbeWorkout(content, id)) { return content; }
            content = iterator.next();
        }
        return null;
    }

    function onTimeout() as Void {
        if (!_busy) { return; }
        _busy = false;
        // Una respuesta tardía todavía puede confirmar la importación. No abrir
        // otra solicitud concurrente ni afirmar que Garmin haya cancelado la suya.
        _stalled = true;
        _status = "Sin respuesta tras 60 s";
        _detail = "Sal y comprueba Garmin Connect";
        WatchUi.requestUpdate();
    }

    private function fail(detail as String) as Void {
        _busy = false;
        _timer.stop();
        _workout = null;
        _status = "Descarga sin confirmar";
        _detail = detail;
        WatchUi.requestUpdate();
    }

    function isBusy() as Boolean { return _busy; }
}

class DownloadDelegate extends WatchUi.BehaviorDelegate {
    private var _view as DownloadView;
    function initialize(view as DownloadView) { BehaviorDelegate.initialize(); _view = view; }
    function onSelect() as Boolean { _view.select(); return true; }
    function onBack() as Boolean {
        // Evitar otra solicitud mientras el sistema todavía procesa el FIT.
        if (_view.isBusy()) { return true; }
        return false;
    }
}
