import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class CiqView extends WatchUi.View {
    private var _credential as String?;
    private var _pairCode as String?;
    private var _started as Boolean=false;
    private var _busy as Boolean=false;
    private var _verified as Boolean=false;
    private var _entries as Array<Dictionary> = [];
    private var _index as Number=0;
    private var _blocked as Number=0;
    private var _status as String="Preparando...";
    private var _detail as String="Conecta Garmin Connect";
    private var _hint as String="";
    private var _wait as Timer.Timer;
    private var _poll as Timer.Timer;
    private var _revision as String?;

    function initialize() {
        View.initialize(); _wait=new Timer.Timer(); _poll=new Timer.Timer();
        var credential=Storage.getValue("ciqCredential"); var code=Storage.getValue("ciqPairCode");
        if (credential instanceof String) { _credential=credential; }
        if (code instanceof String) { _pairCode=code; }
    }
    function onShow() as Void {
        if (_started) { return; } _started=true;
        if (ciqProbeHeld()) { probeSummary(); return; }
        if (_credential==null) { beginPair(); } else if (_pairCode!=null) { checkPair(); } else { synchronize(); }
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        var title=(WatchUi.loadResource(Rez.Strings.AppName) as String)+" "+(WatchUi.loadResource(Rez.Strings.AppVersion) as String);
        var action=ciqProbeHeld()?"START: comprobar\nMENU: prueba":
            (_busy?"Espera o BACK para salir":(_pairCode!=null?"START: comprobar":(_verified?"START: sesiones":"START: actualizar")));
        ciqDrawScreen(dc,[title,_status,_detail,_hint,action]);
    }
    private function startWait(status as String) as Void {
        _busy=true; _status=status; _hint=""; _wait.start(method(:onSlow),60000,false); WatchUi.requestUpdate();
    }
    private function stopWait() as Void { _busy=false; _wait.stop(); }
    function onSlow() as Void {
        if (!_busy) { return; }
        // Aviso de demora, no cancelación: conservar el callback sin duplicar petición.
        _status="Garmin sigue procesando"; _detail="Puedes esperar o salir";
        _hint="No repitas la descarga"; WatchUi.requestUpdate();
    }
    private function request(action as String,callback as Method(code as Number,data as Communications.ContentType?) as Void) as Void {
        if (ciqProbeHeld()) { throw new Lang.InvalidValueException("Ensayo: sin red en primer plano"); }
        var headers={"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON} as Dictionary;
        if (_credential!=null) { headers["Authorization"]="Bearer "+_credential; }
        Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/watch",
            {"action"=>action},{:method=>Communications.HTTP_REQUEST_METHOD_POST,:headers=>headers,
            :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},callback);
    }
    private function beginPair() as Void {
        startWait("Solicitando código"); _detail="Abre EntrenaOP en el móvil";
        try { request("begin",method(:onPair)); } catch(error) { fail("No se pudo conectar"); }
    }
    function onPair(code as Number,data as Communications.ContentType?) as Void {
        stopWait();
        if (code!=200 || !(data instanceof Dictionary)) { fail("No se pudo crear el código"); return; }
        var response=data as Dictionary; var credential=response["credential"]; var pairCode=response["code"];
        if (!(credential instanceof String) || !(pairCode instanceof String) || pairCode.length()!=8) { fail("Respuesta inválida"); return; }
        _credential=credential; _pairCode=pairCode;
        Storage.setValue("ciqCredential",credential); Storage.setValue("ciqPairCode",pairCode);
        showCode(); _poll.start(method(:checkPair),5000,true);
    }
    private function showCode() as Void {
        var pairCode=_pairCode; if (pairCode==null) { return; }
        _status="Vincula tu cuenta"; _detail=pairCode.substring(0,4)+"-"+pairCode.substring(4,8);
        _hint="Perfil > Garmin > app del reloj"; WatchUi.requestUpdate();
    }
    function checkPair() as Void {
        if (_busy) { return; } startWait("Comprobando vínculo");
        try { request("status",method(:onStatus)); } catch(error) { fail("Sin conexión con el móvil"); }
    }
    function onStatus(code as Number,data as Communications.ContentType?) as Void {
        stopWait();
        if (code!=200 || !(data instanceof Dictionary)) { protocolFailure(code,data); return; }
        var response=data as Dictionary; var status=response["status"];
        if (status instanceof String && status.equals("pending")) { showCode(); _poll.start(method(:checkPair),5000,true); return; }
        if (!(status instanceof String) || !status.equals("linked")) { fail("Vínculo no confirmado"); return; }
        _pairCode=null; Storage.deleteValue("ciqPairCode"); _poll.stop(); synchronize();
    }
    function synchronize() as Void {
        if (ciqProbeHeld()) { probeSummary(); return; }
        if (_busy) { return; }
        if (_credential==null) { beginPair(); return; }
        if (_pairCode!=null) { checkPair(); return; }
        _verified=false; startWait("Revisando tus sesiones"); _detail="Solo versiones vigentes";
        try { request("manifest",method(:onManifest)); } catch(error) { fail("Sin conexión. Actualiza luego"); }
    }
    function onManifest(code as Number,data as Communications.ContentType?) as Void {
        if (ciqProbeHeld()) { stopWait(); probeSummary(); return; }
        stopWait();
        if (code!=200 || !(data instanceof Dictionary)) { protocolFailure(code,data); return; }
        var response=data as Dictionary; var entries=ciqManifestEntries(response);
        if (entries==null) { fail("Lista incompleta. No se modifica"); return; }
        ciqSyncKeep(entries);
        // Una sola migración tras permiso válido; respetar la desactivación posterior.
        if (Storage.getValue("ciqAutoEnabled")==null) { Storage.setValue("ciqAutoEnabled",true); }
        _entries=entries; _index=0;
        var blocked=response["blocked"]; _blocked=blocked instanceof Number?blocked:0;
        var revision=response["revision"]; _revision=revision instanceof String?revision:null;
        try { nextDownload(); } catch(error) { fail("No se pudo comprobar el reloj"); }
    }
    function localWorkout(name as String) as PersistedContent.Content? { return new CiqLibrary().find(name); }
    private function nextDownload() as Void {
        if (ciqProbeHeld()) { stopWait(); probeSummary(); return; }
        while (_index<_entries.size()) {
            var entry=_entries[_index]; var name=entry["fit_name"] as String;
            if (localWorkout(name)!=null) { _index++; continue; }
            if (ciqSyncImportPending(name,Time.now().value())) {
                startWait("Garmin está importando"); _detail="Esperando la copia del fondo";
                _hint="No hace falta volver a descargar";
                _poll.start(method(:recheckLocalImport),2000,false); return;
            }
            startWait("Descargando "+(_index+1)+"/"+_entries.size()); _detail="Garmin puede tardar un poco";
            try {
                ciqSyncAttempt(name,entry["id"] as String,Time.now().value(),"primer plano");
                Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/fit/"+
                    Communications.encodeURL(entry["id"] as String),null,
                    {:method=>Communications.HTTP_REQUEST_METHOD_GET,:headers=>{"Authorization"=>"Bearer "+_credential},
                     :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT},method(:onFit));
            } catch(error) { fail("Descarga no confirmada"); } return;
        }
        stopWait(); _verified=true;
        _status=_entries.size()==1?"1 sesión lista":_entries.size()+" sesiones listas"; _detail="Actualizado ahora";
        _hint=_blocked>0?_blocked+" no compatibles o no vigentes":
            (ciqAutoEnabled()?"Automática al salir · cada 15 min":"MENU: actualizar / START: abrir");
        if (_revision!=null) { Storage.setValue("ciqLocalRevision",_revision); }
        Storage.setValue("ciqPending",false); Storage.setValue("ciqLastSync",Time.now().value()); WatchUi.requestUpdate();
    }
    function recheckLocalImport() as Void {
        stopWait(); try { nextDownload(); } catch(error) { fail("No se pudo comprobar la copia"); }
    }
    function onFit(code as Number,data as Communications.ContentType?) as Void {
        stopWait(); if (_index>=_entries.size()) { fail("Respuesta fuera de secuencia"); return; }
        try {
            ciqSyncResponse(_entries[_index]["fit_name"] as String,code);
            if (code!=200 || localWorkout(_entries[_index]["fit_name"] as String)==null) { fail("FIT no confirmado: "+code); return; }
            _index++; nextDownload();
        } catch(error) { fail("No se pudo comprobar el FIT"); }
    }
    private function protocolFailure(code as Number,data as Communications.ContentType?) as Void {
        if (ciqConnectionCanRetry(code)) {
            fail(ciqConnectionMessage(code)); _status="Sin conexión"; _hint="Abre Garmin Connect"; return;
        }
        var reason=null as String?;
        if (data instanceof Dictionary) { var value=data["code"]; if (value instanceof String) { reason=value; } }
        if (reason!=null && (reason.equals("link_revoked") || reason.equals("link_required") || reason.equals("pair_expired"))) {
            _poll.stop(); _credential=null; _pairCode=null; Storage.deleteValue("ciqCredential"); Storage.deleteValue("ciqPairCode");
            fail("Vinculación caducada o retirada"); return;
        }
        if (reason!=null && reason.equals("access_required")) { fail("Revisa tu acceso en EntrenaOP"); return; }
        fail("Sin respuesta válida: "+code);
    }
    private function fail(message as String) as Void {
        stopWait(); _verified=false; _status="No se ha actualizado"; _detail=message;
        _hint="No se muestran copias antiguas"; WatchUi.requestUpdate();
    }
    function select() as Void { if (ciqProbeHeld()) { probeSummary(); return; } if (_busy) { return; } if (_verified) { sessions(); } else { synchronize(); } }
    function menu() as Void {
        if (_busy) { return; } var menu=new WatchUi.Menu2({:title=>"EntrenaOP"});
        if (ciqProbeHeld()) {
            menu.addItem(new WatchUi.MenuItem("Leer resultado", "Sin descargar",:probeRead,{}));
            menu.addItem(new WatchUi.MenuItem("Terminar prueba", "Vuelve al modo habitual",:probeEnd,{}));
            WatchUi.pushView(menu,new CiqMenuDelegate(self),WatchUi.SLIDE_UP); return;
        }
        menu.addItem(new WatchUi.MenuItem("Actualizar",null,:refresh,{}));
        if (_pairCode==null && _credential!=null) {
            menu.addItem(new WatchUi.MenuItem(ciqAutoEnabled()?"Desactivar descarga automática":"Activar descarga automática",
                "Sin avisos; cada 15 min",:automatic,{}));
            menu.addItem(new WatchUi.MenuItem("Estado de descargas",null,:syncDiagnostics,{}));
        }
        if (_verified && _entries.size()==1) {
            menu.addItem(new WatchUi.MenuItem("Prueba: descarga en fondo","Una revisión; sin avisos",:probeArm,{}));
        }
        menu.addItem(new WatchUi.MenuItem("Estado de apertura",null,:openingDiagnostics,{}));
        if (_verified) { menu.addItem(new WatchUi.MenuItem("Abrir sesiones",null,:sessions,{})); }
        if (_pairCode==null && _credential!=null && !ciqAutoEnabled()) {
            var enabled=Storage.getValue("ciqBackgroundEnabled");
            menu.addItem(new WatchUi.MenuItem((enabled instanceof Boolean && enabled) ?
                "Desactivar consulta en fondo" : "Activar consulta cada 15 min", "Solo detecta cambios", :background, {}));
            var alerts=Storage.getValue("ciqChangeAlertsEnabled");
            menu.addItem(new WatchUi.MenuItem((alerts instanceof Boolean && alerts) ?
                "Desactivar avisos de cambios" : "Activar avisos de cambios", "Cada 15 min; aceptar abre y actualiza", :alerts, {}));
            menu.addItem(new WatchUi.MenuItem("Estado de avisos",null,:diagnostics,{}));
        }
        WatchUi.pushView(menu,new CiqMenuDelegate(self),WatchUi.SLIDE_UP);
    }
    function toggleBackground() as Void {
        var enabled=Storage.getValue("ciqBackgroundEnabled");
        if (enabled instanceof Boolean && enabled) {
            Storage.setValue("ciqBackgroundEnabled",false);
            Storage.setValue("ciqChangeAlertsEnabled",false);
            try { Background.deleteTemporalEvent(); } catch(error) { }
            _hint="Consulta en fondo desactivada";
        } else {
            try {
                Storage.setValue("ciqBackgroundEnabled",true); _hint="Consulta cada 15 min al salir";
            } catch(error) { _hint="No se pudo activar la consulta"; }
        }
        WatchUi.requestUpdate();
    }
    function toggleAutomatic() as Void {
        ciqCancelSyncCallbacks(); Storage.setValue("ciqAutoEnabled",!ciqAutoEnabled());
        // Al desactivar, no reactivar por sorpresa los diálogos de la beta anterior.
        Storage.setValue("ciqBackgroundEnabled",ciqAutoEnabled());
        Storage.setValue("ciqChangeAlertsEnabled",false);
        _hint=ciqAutoEnabled()?"Descarga automática al salir":"Descarga automática desactivada";
        WatchUi.requestUpdate();
    }
    function syncDiagnostics() as Void {
        var menu=new WatchUi.Menu2({:title=>"Estado de descargas"});
        var state=Storage.getValue("ciqAutoState"); var stamp=Storage.getValue("ciqAutoAt");
        var code=Storage.getValue("ciqAutoHttp"); var queryCode=Storage.getValue("ciqAutoManifestHttp");
        var name=Storage.getValue("ciqAutoName");
        menu.addItem(new WatchUi.MenuItem("Automática",ciqAutoEnabled()?"Activada · cada 15 min":"Desactivada",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Último estado",state instanceof String?state:"Al salir se programará",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Hace",stamp instanceof Number?((Time.now().value()-stamp)/60).toString()+" min":"Sin dato",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Consulta HTTP",queryCode instanceof Number && queryCode!=0?queryCode.toString():"Sin respuesta",:info,{}));
        menu.addItem(new WatchUi.MenuItem("FIT HTTP",code instanceof Number && code!=0?code.toString():"Sin respuesta final",:info,{}));
        if (name instanceof String) {
            menu.addItem(new WatchUi.MenuItem("Revisión",name,:info,{}));
            var record=ciqSyncRecords()[name];
            if (record instanceof Dictionary) {
                var library=record["library"]; var origin=record["origin"];
                menu.addItem(new WatchUi.MenuItem("Biblioteca",library instanceof String?library:"Sin comprobar",:info,{}));
                menu.addItem(new WatchUi.MenuItem("Solicitud desde",origin instanceof String?origin:"Sin dato",:info,{}));
            }
        }
        WatchUi.pushView(menu,new CiqMenuDelegate(self),WatchUi.SLIDE_UP);
    }
    function toggleAlerts() as Void {
        var enabled=Storage.getValue("ciqChangeAlertsEnabled");
        if (enabled instanceof Boolean && enabled) {
            Storage.setValue("ciqChangeAlertsEnabled",false);
            _hint="Avisos desactivados";
        } else {
            try {
                Storage.setValue("ciqBackgroundEnabled",true);
                Storage.setValue("ciqChangeAlertsEnabled",true);
                _hint="Avisos cada 15 min al salir";
            } catch(error) { _hint="No se pudieron activar los avisos"; }
        }
        WatchUi.requestUpdate();
    }
    function sessions() as Void {
        if (!_verified) { return; } var menu=new WatchUi.Menu2({:title=>"Sesiones vigentes"});
        for (var index=0;index<_entries.size();index++) {
            var entry=_entries[index]; menu.addItem(new WatchUi.MenuItem(entry["name"] as String,entry["date"] as String,index,{}));
        }
        if (_entries.size()==0) { menu.addItem(new WatchUi.MenuItem("Sin fuerza compatible",null,:empty,{})); }
        WatchUi.pushView(menu,new CiqMenuDelegate(self),WatchUi.SLIDE_UP);
    }
    function diagnostics() as Void {
        var menu=new WatchUi.Menu2({:title=>"Estado de avisos"});
        var state=Storage.getValue("ciqBackgroundState");
        var stamp=Storage.getValue("ciqBackgroundStateAt");
        var http=Storage.getValue("ciqBackgroundHttp");
        var enabled=Storage.getValue("ciqBackgroundEnabled");
        var alerts=Storage.getValue("ciqChangeAlertsEnabled");
        menu.addItem(new WatchUi.MenuItem("Consulta en fondo",enabled instanceof Boolean && enabled?"Activada":"Desactivada",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Avisos",alerts instanceof Boolean && alerts?"Activados":"Desactivados",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Último estado",state instanceof String?state:"Sin ejecutar",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Hace",stamp instanceof Number?((Time.now().value()-stamp)/60).toString()+" min":"Sin dato",:info,{}));
        menu.addItem(new WatchUi.MenuItem("HTTP",http instanceof Number && http!=0?http.toString():"Sin respuesta",:info,{}));
        WatchUi.pushView(menu,new CiqMenuDelegate(self),WatchUi.SLIDE_UP);
    }
    function open(index as Number) as Void {
        if (ciqProbeHeld()) { probeSummary(); return; }
        if (_busy || !_verified || index<0 || index>=_entries.size()) { return; }
        var view=new CiqOpenView(self,_entries[index]);
        WatchUi.switchToView(view,new CiqOpenDelegate(view),WatchUi.SLIDE_IMMEDIATE);
    }
    function requestOpenPermission(callback as Method(code as Number,data as Communications.ContentType?) as Void) as Void {
        request("manifest",callback);
    }
    function openPermissionFailure(code as Number,data as Communications.ContentType?) as String {
        protocolFailure(code,data); return _detail;
    }
    function invalidateOpen(message as String) as Void { fail(message); }
    function openingDiagnostics() as Void {
        var menu=new WatchUi.Menu2({:title=>"Estado de apertura"});
        var stage=Storage.getValue("ciqOpenStage"); var error=Storage.getValue("ciqOpenError");
        var stamp=Storage.getValue("ciqOpenAt");
        menu.addItem(new WatchUi.MenuItem("Etapa",stage instanceof String?stage:"Sin intento",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Detalle",error instanceof String?error:"Sin dato",:info,{}));
        menu.addItem(new WatchUi.MenuItem("Hace",stamp instanceof Number?((Time.now().value()-stamp)/60).toString()+" min":"Sin dato",:info,{}));
        WatchUi.pushView(menu,new CiqMenuDelegate(self),WatchUi.SLIDE_IMMEDIATE);
    }
    function armProbe() as Void {
        if (_busy || !_verified || _entries.size()!=1 || _credential==null || _pairCode!=null) { return; }
        var target=_entries[0]["scheduled_id"];
        if (!(target instanceof String) || target.length()!=36) { fail("Cita de prueba no válida"); return; }
        ciqCancelSyncCallbacks();
        // Capturar toda la biblioteca propia impide acreditar como nueva una copia antigua.
        var baseline=[] as Array<String>; var iterator=PersistedContent.getAppWorkouts(); var content=iterator.next();
        while (content!=null) {
            if (baseline.size()>=200) { fail("Demasiadas copias para probar"); return; }
            baseline.add(content.getName()); content=iterator.next();
        }
        var currentName=_entries[0]["fit_name"] as String;
        if (baseline.indexOf(currentName)<0) { baseline.add(currentName); }
        var generation=Storage.getValue("ciqProbeRun");
        Storage.setValue("ciqProbeRun",generation instanceof Number?generation+1:1);
        Storage.setValue("ciqProbeTarget",target); Storage.setValue("ciqProbeBaseline",baseline as Array<Storage.ValueType>);
        Storage.setValue("ciqProbeStarted",Time.now().value()); Storage.setValue("ciqProbePhase","armed");
        Storage.setValue("ciqProbeState","Prueba preparada"); Storage.setValue("ciqProbeManifestHttp",0);
        Storage.setValue("ciqProbeFitHttp",0); Storage.deleteValue("ciqProbeName"); Storage.deleteValue("ciqProbeExport");
        Storage.deleteValue("ciqProbeVerifiedAt"); Storage.setValue("ciqProbeMode",true); probeSummary();
    }
    function probeSummary() as Void {
        _verified=false;
        var state=Storage.getValue("ciqProbeState"); var name=Storage.getValue("ciqProbeName");
        _status="Prueba en segundo plano"; _detail=state instanceof String?state:"Sin resultado";
        _hint="Sal hasta la esfera";
        if (name instanceof String) {
            _hint=name;
            if (localWorkout(name)!=null) {
                _detail="Instalada en segundo plano"; _hint=name+" / Sin descarga al abrir";
                Storage.setValue("ciqProbeVerifiedAt",Time.now().value());
            } else {
                _detail="Sin confirmación local"; _hint=name+" / Comprueba Fuerza";
            }
        }
        var http=Storage.getValue("ciqProbeFitHttp");
        if (http instanceof Number && http!=0 && Storage.getValue("ciqProbeVerifiedAt")==null) {
            _hint="Garmin: "+http+" / Sin descarga al abrir";
        }
        WatchUi.requestUpdate();
    }
    function endProbe() as Void {
        Storage.setValue("ciqProbeMode",false); synchronize();
    }
}
class CiqDelegate extends WatchUi.BehaviorDelegate {
    private var _view as CiqView;
    function initialize(view as CiqView) { BehaviorDelegate.initialize(); _view=view; }
    function onSelect() as Boolean { _view.select(); return true; }
    function onMenu() as Boolean { _view.menu(); return true; }
    function onBack() as Boolean { return false; }
}
class CiqMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view as CiqView;
    function initialize(view as CiqView) { Menu2InputDelegate.initialize(); _view=view; }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id=item.getId();
        if (id instanceof Number) { _view.open(id); return; }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (id==:refresh) { _view.synchronize(); }
        else if (id==:sessions) { _view.sessions(); } else if (id==:background) { _view.toggleBackground(); }
        else if (id==:alerts) { _view.toggleAlerts(); }
        else if (id==:diagnostics) { _view.diagnostics(); }
        else if (id==:openingDiagnostics) { _view.openingDiagnostics(); }
        else if (id==:probeArm) { _view.armProbe(); }
        else if (id==:probeRead) { _view.probeSummary(); }
        else if (id==:probeEnd) { _view.endProbe(); }
        else if (id==:automatic) { _view.toggleAutomatic(); }
        else if (id==:syncDiagnostics) { _view.syncDiagnostics(); }
    }
}
