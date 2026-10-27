import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

(:background)
function ciqAutoEnabled() as Boolean {
    var value=Storage.getValue("ciqAutoEnabled"); return value instanceof Boolean && value;
}

(:background)
function ciqSyncRecords() as Dictionary {
    var value=Storage.getValue("ciqSyncRecords"); return value instanceof Dictionary?value as Dictionary:{} as Dictionary;
}

(:background)
function ciqSyncGeneration() as Number {
    var value=Storage.getValue("ciqSyncGeneration"); return value instanceof Number?value:0;
}

(:background)
function ciqCancelSyncCallbacks() as Void { Storage.setValue("ciqSyncGeneration",ciqSyncGeneration()+1); }

(:background)
function ciqSyncKeep(entries as Array<Dictionary>) as Void {
    var previous=ciqSyncRecords(); var next={} as Dictionary;
    for (var i=0;i<entries.size();i++) {
        var name=entries[i]["fit_name"];
        if (previous[name] instanceof Dictionary) { next[name]=previous[name]; }
    }
    // Acotar el diario a las 30 revisiones actuales; no se borra contenido Garmin.
    Storage.setValue("ciqSyncRecords",next as Storage.ValueType);
}

(:background)
function ciqSyncAttempt(name as String,id as String,now as Number,origin as String) as Void {
    var records=ciqSyncRecords(); var old=records[name]; var attempts=0;
    if (old instanceof Dictionary && old["attempts"] instanceof Number) { attempts=old["attempts"] as Number; }
    records[name]={"export"=>id,"phase"=>"requested","attempts"=>attempts+1,"at"=>now,"origin"=>origin};
    Storage.setValue("ciqSyncRecords",records as Storage.ValueType);
}

(:background)
function ciqSyncResponse(name as String,code as Number) as Void {
    var records=ciqSyncRecords(); var record=records[name];
    if (!(record instanceof Dictionary)) { return; }
    record["phase"]=code==200?"received":"failed"; record["http"]=code;
    records[name]=record; Storage.setValue("ciqSyncRecords",records as Storage.ValueType);
}

(:background)
function ciqSyncDue(record as Dictionary?,now as Number) as Boolean {
    if (!(record instanceof Dictionary)) { return true; }
    var phase=record["phase"]; var attempts=record["attempts"]; var at=record["at"];
    if (phase instanceof String && (phase.equals("verified") || phase.equals("received"))) { return false; }
    if (!(attempts instanceof Number) || !(at instanceof Number) || attempts>=3) { return false; }
    // Si falta callback, dar margen al importador. Reintentar la MISMA exportación,
    // como máximo tres veces, nunca generar otra identidad para cada reintento.
    return now>=at && now-at>=1800;
}

(:background)
function ciqNativeAlias(name as String) as Boolean {
    if (name.length()!=13 || !(name.substring(0,3) as String).equals("EOP")) { return false; }
    for (var i=3;i<name.length();i++) {
        if ("0123456789".find(name.substring(i,i+1) as String)==null) { return false; }
    }
    return true;
}

function ciqSyncTrustsNative(name as String) as Boolean {
    if (!ciqNativeAlias(name)) { return false; }
    if (ciqSyncRecords()[name] instanceof Dictionary) { return true; }
    // Migrar la evidencia del ensayo 1.5, cuyo callback pudo no quedar registrado.
    var probe=Storage.getValue("ciqProbeName");
    return probe instanceof String && probe.equals(name);
}

function ciqSyncImportPending(name as String,now as Number) as Boolean {
    var value=ciqSyncRecords()[name];
    if (!(value instanceof Dictionary)) { return false; }
    var record=value as Dictionary;
    var origin=record["origin"]; var phase=record["phase"]; var at=record["at"];
    if (!(origin instanceof String) || !(origin as String).equals("segundo plano")) { return false; }
    if (!(phase instanceof String)) { return false; }
    var stage=phase as String;
    if (!stage.equals("requested") && !stage.equals("received")) { return false; }
    if (!(at instanceof Number)) { return false; }
    var started=at as Number;
    return now>=started && now-started<90;
}
