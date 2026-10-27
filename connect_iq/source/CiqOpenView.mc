import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class CiqOpenView extends WatchUi.View {
    private var _owner as CiqView;
    private var _flow as CiqOpenFlow;
    private var _fitName as String;
    private var _entry as Dictionary;
    private var _retry as Boolean=false;
    private var _active as Boolean=false;
    private var _launchTimer as Timer.Timer;
    private var _status as String="Abriendo Fuerza";
    private var _detail as String="Comprobando permiso";
    private var _hint as String="Mantén el móvil conectado";
    private var _stage as String="Permiso";

    function initialize(owner as CiqView,entry as Dictionary) {
        View.initialize(); _owner=owner; _entry=entry;
        _fitName=entry["fit_name"] as String;
        _flow=new CiqOpenFlow(entry["id"] as String,_fitName);
        _launchTimer=new Timer.Timer();
    }
    function onShow() as Void {
        _active=true;
        // El menú ya ha sido sustituido: no se solicita el intent durante su cierre.
        if (_flow.begin()) {
            _launchTimer.start(method(:onSlow),60000,false);
            try { _owner.requestOpenPermission(method(:onPermission)); }
            catch(error) {
                showConnectionFailure(Communications.BLE_ERROR);
            }
        } else if (_flow.phase()==:handedOff || _flow.phase()==:cancelled) {
            _retry=false;
            _status="Apertura interrumpida"; _detail="Vuelve a elegir la sesión";
            _hint="Se comprobará otra vez el permiso";
        }
        WatchUi.requestUpdate();
    }
    function onHide() as Void {
        _active=false; _launchTimer.stop(); _flow.cancel();
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        var done=_flow.phase()==:failed || _flow.phase()==:cancelled;
        var action=_retry?"START: reintentar\nBACK: volver\nMENU: detalle":
            (done?"START: volver\nMENU: detalle":"BACK: cancelar");
        ciqDrawScreen(dc,[_status,_detail,_hint,action]);
    }
    function onPermission(code as Number,data as Communications.ContentType?) as Void {
        if (!_active || _flow.phase()!=:checking) { return; }
        _launchTimer.stop();
        if (ciqConnectionCanRetry(code)) { showConnectionFailure(code); return; }
        if (code!=200 || !(data instanceof Dictionary)) {
            var detail=_owner.openPermissionFailure(code,data);
            showFailure("Acceso no confirmado",detail,"Permiso","HTTP "+code); return;
        }
        if (!_flow.authorize(data as Dictionary)) {
            _owner.invalidateOpen("La sesión cambió. Actualiza");
            showFailure("Sesión no disponible","Vuelve y actualiza","Permiso","Lista o revisión no vigente"); return;
        }
        _detail="Preparando entrenamiento"; _hint="Espera la apertura de Garmin";
        WatchUi.requestUpdate();
        // Ceder un turno a la interfaz evita encadenar la apertura nativa al callback HTTP.
        _launchTimer.start(method(:onLaunch),50,false);
    }
    function onSlow() as Void {
        if (!_active || _flow.phase()!=:checking) { return; }
        _detail="La conexión está tardando"; _hint="Puedes esperar o BACK para salir";
        WatchUi.requestUpdate();
    }
    function onLaunch() as Void {
        if (!_active || !_flow.takeLaunch()) { return; }
        try {
            _stage="Biblioteca";
            var content=_owner.owned(_fitName);
            if (content==null) {
                _owner.invalidateOpen("La copia ya no está. Actualiza");
                showFailure("Copia no disponible","Vuelve y actualiza",_stage,"No figura en biblioteca propia"); return;
            }
            _stage="Preparar intent"; var intent=content.toIntent();
            _stage="Abrir Fuerza";
            // El flujo ya está en launching: ni START ni otro callback pueden duplicarlo.
            System.exitTo(intent); _flow.handedOff();
            record("Solicitud enviada","Sin error");
            _detail="Confirma la apertura en Garmin"; _hint="Si cancelas, vuelve a elegir sesión";
            WatchUi.requestUpdate();
        } catch(error) {
            var kind=ciqOpenErrorCode(error);
            var detail="Garmin rechazó la apertura";
            if (kind.equals("pending")) { detail="Garmin tiene una apertura pendiente"; }
            else if (kind.equals("not_installed")) { detail="Garmin no encuentra la actividad"; }
            else if (kind.equals("wrong_type")) { detail="Actividad de destino no admitida"; }
            var message=error.getErrorMessage();
            // Solo errores de biblioteca/intent local; nunca mensajes de transporte o credenciales.
            var diagnostic=kind;
            if (message instanceof String) { diagnostic=message as String; }
            if (diagnostic.length()>96) { diagnostic=diagnostic.substring(0,96) as String; }
            showFailure("No se pudo abrir Fuerza",detail,_stage,diagnostic);
        }
    }
    private function record(stage as String,message as String) as Void {
        // Un fallo del diagnóstico no debe convertir una apertura aceptada en error.
        try {
            Storage.setValue("ciqOpenStage",stage); Storage.setValue("ciqOpenError",message);
            Storage.setValue("ciqOpenAt",Time.now().value());
        } catch(error) { }
    }
    private function showFailure(status as String,detail as String,stage as String,message as String) as Void {
        _flow.fail(); _launchTimer.stop(); record(stage,message);
        _retry=false; _status=status; _detail=detail; _hint="Vuelve a elegir la sesión";
        WatchUi.requestUpdate();
    }
    private function showConnectionFailure(code as Number) as Void {
        showFailure("Sin respuesta",ciqConnectionMessage(code),"Conexión","Garmin "+code);
        _retry=true; _hint="Abre Garmin Connect";
        WatchUi.requestUpdate();
    }
    function close() as Void {
        _active=false; _launchTimer.stop(); _flow.cancel();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
    function select() as Void {
        if (_retry && _active && _flow.phase()==:failed) {
            // Pantalla nueva: una respuesta del intento anterior no autoriza el siguiente.
            var next=new CiqOpenView(_owner,_entry);
            WatchUi.switchToView(next,new CiqOpenDelegate(next),WatchUi.SLIDE_IMMEDIATE); return;
        }
        if (_flow.phase()==:failed || _flow.phase()==:cancelled) { close(); }
    }
    function diagnostics() as Void {
        if (_flow.phase()==:failed || _flow.phase()==:cancelled) { _owner.openingDiagnostics(); }
    }
}

class CiqOpenDelegate extends WatchUi.BehaviorDelegate {
    private var _view as CiqOpenView;
    function initialize(view as CiqOpenView) { BehaviorDelegate.initialize(); _view=view; }
    function onSelect() as Boolean { _view.select(); return true; }
    function onMenu() as Boolean { _view.diagnostics(); return true; }
    function onBack() as Boolean { _view.close(); return true; }
}
