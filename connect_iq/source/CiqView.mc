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
    private var _opening as Dictionary?;

    function initialize() {
        View.initialize(); _wait=new Timer.Timer(); _poll=new Timer.Timer();
        var credential=Storage.getValue("ciqCredential"); var code=Storage.getValue("ciqPairCode");
        if (credential instanceof String) { _credential=credential; }
        if (code instanceof String) { _pairCode=code; }
    }
    function onShow() as Void {
        if (_started) { return; } _started=true;
        if (_credential==null) { beginPair(); } else if (_pairCode!=null) { checkPair(); } else { synchronize(); }
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.clear();
        var x=dc.getWidth()/2; var y=dc.getHeight()/2;
        dc.drawText(x,y-100,Graphics.FONT_SMALL,"EntrenaOP Dev 1.2",Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x,y-45,Graphics.FONT_XTINY,_status,Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x,y-5,Graphics.FONT_XTINY,_detail,Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x,y+40,Graphics.FONT_XTINY,_hint,Graphics.TEXT_JUSTIFY_CENTER);
        var action=_busy?"Espera o BACK para salir":(_pairCode!=null?"START: comprobar":(_verified?"START: sesiones":"START: actualizar"));
        dc.drawText(x,y+90,Graphics.FONT_XTINY,action,Graphics.TEXT_JUSTIFY_CENTER);
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
        if (_busy) { return; }
        if (_credential==null) { beginPair(); return; }
        if (_pairCode!=null) { checkPair(); return; }
        _verified=false; startWait("Revisando tus sesiones"); _detail="Solo versiones vigentes";
        try { request("manifest",method(:onManifest)); } catch(error) { fail("Sin conexión. Actualiza luego"); }
    }
    function onManifest(code as Number,data as Communications.ContentType?) as Void {
        stopWait();
        if (code!=200 || !(data instanceof Dictionary)) { protocolFailure(code,data); return; }
        var response=data as Dictionary; var entries=ciqManifestEntries(response);
        if (entries==null) { fail("Lista incompleta. No se modifica"); return; }
        _entries=entries; _index=0;
        var blocked=response["blocked"]; _blocked=blocked instanceof Number?blocked:0;
        var revision=response["revision"]; _revision=revision instanceof String?revision:null;
        try { nextDownload(); } catch(error) { fail("No se pudo comprobar el reloj"); }
    }
    private function owned(name as String) as PersistedContent.Content? {
        var iterator=PersistedContent.getAppWorkouts(); var content=iterator.next();
        while (content!=null) { if (content.getName().equals(name)) { return content; } content=iterator.next(); }
        return null;
    }
    private function nextDownload() as Void {
        while (_index<_entries.size()) {
            var entry=_entries[_index]; var name=entry["fit_name"] as String;
            if (owned(name)!=null) { _index++; continue; }
            startWait("Descargando "+(_index+1)+"/"+_entries.size()); _detail="Garmin puede tardar un poco";
            try {
                Communications.makeWebRequest("https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq/fit/"+
                    Communications.encodeURL(entry["id"] as String),null,
                    {:method=>Communications.HTTP_REQUEST_METHOD_GET,:headers=>{"Authorization"=>"Bearer "+_credential},
                     :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT},method(:onFit));
            } catch(error) { fail("Descarga no confirmada"); } return;
        }
        stopWait(); _verified=true;
        _status=_entries.size()==1?"1 sesión lista":_entries.size()+" sesiones listas"; _detail="Actualizado ahora";
        _hint=_blocked>0?_blocked+" no compatibles o no vigentes":"MENU: actualizar / START: abrir";
        if (_revision!=null) { Storage.setValue("ciqLocalRevision",_revision); }
        Storage.setValue("ciqPending",false); Storage.setValue("ciqLastSync",Time.now().value()); WatchUi.requestUpdate();
    }
    function onFit(code as Number,data as Communications.ContentType?) as Void {
        stopWait(); if (_index>=_entries.size()) { fail("Respuesta fuera de secuencia"); return; }
        try {
            if (code!=200 || owned(_entries[_index]["fit_name"] as String)==null) { fail("FIT no confirmado: "+code); return; }
            _index++; nextDownload();
        } catch(error) { fail("No se pudo comprobar el FIT"); }
    }
    private function protocolFailure(code as Number,data as Communications.ContentType?) as Void {
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
    function select() as Void { if (_busy) { return; } if (_verified) { sessions(); } else { synchronize(); } }
    function menu() as Void {
        if (_busy) { return; } var menu=new WatchUi.Menu2({:title=>"EntrenaOP"});
        menu.addItem(new WatchUi.MenuItem("Actualizar",null,:refresh,{}));
        if (_verified) { menu.addItem(new WatchUi.MenuItem("Abrir sesiones",null,:sessions,{})); }
        if (_pairCode==null && _credential!=null) {
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
                Background.registerForTemporalEvent(new Time.Duration(900));
                Storage.setValue("ciqBackgroundEnabled",true); _hint="Cambios cada 15 min; abre para FIT";
            } catch(error) { _hint="No se pudo activar la consulta"; }
        }
        WatchUi.requestUpdate();
    }
    function toggleAlerts() as Void {
        var enabled=Storage.getValue("ciqChangeAlertsEnabled");
        if (enabled instanceof Boolean && enabled) {
            Storage.setValue("ciqChangeAlertsEnabled",false);
            _hint="Avisos desactivados";
        } else {
            try {
                Background.registerForTemporalEvent(new Time.Duration(900));
                Storage.setValue("ciqBackgroundEnabled",true);
                Storage.setValue("ciqChangeAlertsEnabled",true);
                _hint="Aviso de cambios; aceptar actualiza";
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
        var menu=new WatchUi.Menu2({:title=>"Diagnóstico 1.2"});
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
        if (_busy || !_verified || index<0 || index>=_entries.size()) { return; }
        _opening=_entries[index]; startWait("Comprobando permiso"); _detail="Antes de abrir en Fuerza";
        try { request("manifest",method(:onOpenPermission)); } catch(error) { _opening=null; fail("Sin conexión. No se abre"); }
    }
    function onOpenPermission(code as Number,data as Communications.ContentType?) as Void {
        stopWait(); var entry=_opening; _opening=null;
        if (code!=200 || !(data instanceof Dictionary)) { protocolFailure(code,data); return; }
        if (entry==null || !ciqManifestAllowsOpen(data,entry["id"] as String,entry["fit_name"] as String)) {
            fail("La sesión cambió. Actualiza"); return;
        }
        try {
            var content=owned(entry["fit_name"] as String);
            if (content==null) { fail("La copia ya no está. Actualiza"); return; }
            System.exitTo(content.toIntent());
        } catch(error) { fail("No se pudo abrir en Fuerza"); }
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
        var id=item.getId(); WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id instanceof Number) { _view.open(id); } else if (id==:refresh) { _view.synchronize(); }
        else if (id==:sessions) { _view.sessions(); } else if (id==:background) { _view.toggleBackground(); }
        else if (id==:alerts) { _view.toggleAlerts(); }
        else if (id==:diagnostics) { _view.diagnostics(); }
    }
}
