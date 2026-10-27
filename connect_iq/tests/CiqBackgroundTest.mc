import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

class CiqBackgroundSpy extends CiqBackground {
    var reject as Boolean=false;
    var alerts as Number=0;
    var exits as Number=0;
    function initialize() { CiqBackground.initialize(); }
    function showChangeAlert() as Void {
        if (reject) { throw new Lang.InvalidValueException("Rechazo simulado del diálogo"); }
        alerts++;
    }
    function finish() as Void { exits++; }
}

function ciqBackgroundTestKeys() as Array<String> {
    return ["ciqBackgroundState","ciqBackgroundStateAt","ciqBackgroundHttp","ciqPending",
        "ciqLastCheck","ciqBackgroundEnabled","ciqChangeAlertsEnabled","ciqNotifiedRevision","ciqLocalRevision","ciqProbeMode","ciqAutoEnabled"];
}
function ciqBackgroundTestSave() as Dictionary {
    var saved={} as Dictionary;
    var keys=ciqBackgroundTestKeys();
    for (var index=0;index<keys.size();index++) { saved[keys[index]]=Storage.getValue(keys[index]); }
    Storage.setValue("ciqBackgroundEnabled",true); Storage.setValue("ciqChangeAlertsEnabled",true);
    Storage.setValue("ciqNotifiedRevision","anterior"); Storage.setValue("ciqLocalRevision","anterior");
    Storage.setValue("ciqProbeMode",false);
    Storage.setValue("ciqAutoEnabled",false);
    return saved;
}
function ciqBackgroundTestRestore(saved as Dictionary) as Void {
    var keys=ciqBackgroundTestKeys();
    for (var index=0;index<keys.size();index++) {
        var key=keys[index];
        if (saved[key]==null) { Storage.deleteValue(key); } else { Storage.setValue(key,saved[key] as Storage.ValueType); }
    }
}
function ciqBackgroundTestData() as Dictionary {
    return {"revision"=>ciqChangesTestRevision(),"count"=>1,"blocked"=>0};
}

(:test)
function backgroundCallbackAlertsOnceAndExits(logger as Test.Logger) as Boolean {
    var saved=ciqBackgroundTestSave(); var worker=new CiqBackgroundSpy();
    worker.onChanges(200,ciqBackgroundTestData());
    var first=worker.alerts==1 && worker.exits==1 && (Storage.getValue("ciqPending") as Boolean) &&
        (Storage.getValue("ciqBackgroundState") as String).equals("Aviso solicitado");
    worker.onChanges(200,ciqBackgroundTestData());
    var result=first && worker.alerts==1 && worker.exits==2 &&
        (Storage.getValue("ciqBackgroundState") as String).equals("Cambio ya avisado");
    ciqBackgroundTestRestore(saved); return result;
}
(:test)
function backgroundFailureDoesNotConsumeAlert(logger as Test.Logger) as Boolean {
    var saved=ciqBackgroundTestSave(); var worker=new CiqBackgroundSpy(); worker.reject=true;
    worker.onChanges(200,ciqBackgroundTestData());
    var failed=worker.exits==1 && (Storage.getValue("ciqNotifiedRevision") as String).equals("anterior") &&
        (Storage.getValue("ciqBackgroundState") as String).equals("Error al pedir aviso");
    worker.reject=false; worker.onChanges(200,ciqBackgroundTestData());
    var result=failed && worker.alerts==1 && worker.exits==2;
    ciqBackgroundTestRestore(saved); return result;
}
(:test)
function disabledAlertsNeverPrompt(logger as Test.Logger) as Boolean {
    var saved=ciqBackgroundTestSave(); var worker=new CiqBackgroundSpy();
    Storage.setValue("ciqChangeAlertsEnabled",false);
    worker.onChanges(200,ciqBackgroundTestData());
    var result=worker.alerts==0 && worker.exits==1 &&
        (Storage.getValue("ciqBackgroundState") as String).equals("Avisos desactivados");
    ciqBackgroundTestRestore(saved); return result;
}
(:test)
function backgroundRejectsMalformedAndDeniedResponses(logger as Test.Logger) as Boolean {
    var saved=ciqBackgroundTestSave(); var worker=new CiqBackgroundSpy();
    worker.onChanges(200,{"revision"=>ciqChangesTestRevision()});
    var invalid=(Storage.getValue("ciqBackgroundState") as String).equals("Respuesta incompleta");
    worker.onChanges(403,ciqBackgroundTestData());
    var result=invalid && worker.alerts==0 && worker.exits==2 &&
        !(Storage.getValue("ciqBackgroundEnabled") as Boolean) && (Storage.getValue("ciqBackgroundHttp") as Number)==403;
    ciqBackgroundTestRestore(saved); return result;
}
