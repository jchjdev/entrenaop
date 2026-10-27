import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

class CiqProbeSpy extends CiqSilentProbe {
    var manifests as Number=0;
    var downloads as Number=0;
    var exits as Number=0;
    function initialize() { CiqSilentProbe.initialize(); }
    function requestManifest() as Void { manifests++; }
    function requestFit(id as String) as Void { downloads++; }
    function exitService() as Void { exits++; }
}
function ciqProbeTestKeys() as Array<String> {
    return ["ciqProbeMode","ciqProbePhase","ciqProbeRun","ciqProbeStarted","ciqProbeState","ciqProbeAt",
        "ciqProbeManifestHttp","ciqProbeFitHttp","ciqProbeTarget","ciqProbeBaseline","ciqProbeName",
        "ciqProbeExport","ciqProbeVerifiedAt","ciqCredential","ciqPairCode","ciqLocalRevision"];
}
function ciqProbeSave() as Dictionary {
    var saved={} as Dictionary; var keys=ciqProbeTestKeys();
    for (var i=0;i<keys.size();i++) { saved[keys[i]]=Storage.getValue(keys[i]); }
    Storage.setValue("ciqProbeMode",true); Storage.setValue("ciqProbePhase","armed"); Storage.setValue("ciqProbeRun",1);
    Storage.setValue("ciqProbeStarted",Time.now().value()); Storage.setValue("ciqCredential","synthetic-local-test");
    Storage.deleteValue("ciqPairCode"); Storage.setValue("ciqProbeTarget","20000000-0000-4000-8000-000000000002");
    Storage.setValue("ciqProbeBaseline",["OLD"]); Storage.setValue("ciqLocalRevision","original");
    Storage.deleteValue("ciqProbeName"); Storage.deleteValue("ciqProbeExport"); Storage.deleteValue("ciqProbeVerifiedAt");
    return saved;
}
function ciqProbeRestore(saved as Dictionary) as Void {
    var keys=ciqProbeTestKeys();
    for (var i=0;i<keys.size();i++) {
        if (saved[keys[i]]==null) { Storage.deleteValue(keys[i]); }
        else { Storage.setValue(keys[i],saved[keys[i]] as Storage.ValueType); }
    }
}
function ciqProbeData(name as String) as Dictionary {
    var entry=ciqTestEntry(); entry["scheduled_id"]="20000000-0000-4000-8000-000000000002";
    entry["fit_name"]=name;
    return {"complete"=>true,"entries"=>[entry]};
}
(:test)
function silentProbeDownloadsOnceAndNeverMarksHttpAsInstalled(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); var worker=new CiqProbeSpy(); worker.run();
    worker.onManifest(200,ciqProbeData("NEW")); worker.onManifest(200,ciqProbeData("NEW"));
    worker.onFit(200,null); worker.onFit(200,null);
    var result=worker.manifests==1 && worker.downloads==1 && worker.exits==1 &&
        (Storage.getValue("ciqProbePhase") as String).equals("response") &&
        Storage.getValue("ciqProbeVerifiedAt")==null && (Storage.getValue("ciqLocalRevision") as String).equals("original");
    ciqProbeRestore(saved); return result;
}
(:test)
function silentProbeWaitsForUnseenCopyOfTheChosenAppointment(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); var worker=new CiqProbeSpy(); worker.run(); worker.onManifest(200,ciqProbeData("OLD"));
    var known=worker.downloads==0 && (Storage.getValue("ciqProbePhase") as String).equals("armed");
    var other=ciqProbeData("NEW"); var otherEntries=other["entries"] as Array<Dictionary>;
    otherEntries[0]["scheduled_id"]="OTHER";
    worker=new CiqProbeSpy(); worker.run(); worker.onManifest(200,other);
    var result=known && worker.downloads==0 && worker.exits==1 && Storage.getValue("ciqProbeName")==null;
    ciqProbeRestore(saved); return result;
}
(:test)
function silentProbeRejectsPartialAndDeniedManifests(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); var partial=ciqProbeData("NEW"); partial["complete"]=false;
    var worker=new CiqProbeSpy(); worker.run(); worker.onManifest(200,partial);
    var first=worker.downloads==0 && worker.exits==1;
    Storage.setValue("ciqProbePhase","armed"); worker=new CiqProbeSpy(); worker.run(); worker.onManifest(403,ciqProbeData("NEW"));
    var result=first && worker.downloads==0 && worker.exits==1 && (Storage.getValue("ciqProbePhase") as String).equals("failed");
    ciqProbeRestore(saved); return result;
}
(:test)
function silentProbeDiscardsCancelledAndPreviousGenerationResponses(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); var worker=new CiqProbeSpy(); worker.run(); Storage.setValue("ciqProbeRun",2);
    Storage.setValue("ciqProbePhase","armed"); worker.onManifest(200,ciqProbeData("NEW"));
    var stale=worker.downloads==0 && (Storage.getValue("ciqProbePhase") as String).equals("armed");
    worker=new CiqProbeSpy(); worker.run(); Storage.setValue("ciqProbeMode",false); worker.onManifest(200,ciqProbeData("NEW"));
    var result=stale && worker.downloads==0 && worker.exits==1;
    ciqProbeRestore(saved); return result;
}
(:test)
function silentProbeExpiresWithoutNetwork(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); Storage.setValue("ciqProbeStarted",Time.now().value()-1801);
    var worker=new CiqProbeSpy(); worker.run();
    var result=worker.manifests==0 && worker.downloads==0 && worker.exits==1;
    ciqProbeRestore(saved); return result;
}
(:test)
function probeInspectionCannotStartForegroundDownload(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); var view=new CiqOpenTestOwner();
    view.onShow(); view.synchronize(); view.select(); view.onManifest(200,ciqProbeData("NEW"));
    var result=view.checks==0 && view.lookups==0;
    ciqProbeRestore(saved); return result;
}
(:test)
function silentProbeSuppressesAnEarlierChangeNotification(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); var worker=new CiqBackgroundSpy();
    worker.onChanges(200,ciqBackgroundTestData());
    var result=worker.alerts==0 && worker.exits==1 && (Storage.getValue("ciqLocalRevision") as String).equals("original");
    ciqProbeRestore(saved); return result;
}
(:test)
function silentProbeSchedulesOnlyUntilTheSingleFitRequest(logger as Test.Logger) as Boolean {
    var saved=ciqProbeSave(); var previous=Toybox.Background.getTemporalEventRegisteredTime();
    ciqResumeChecks(); var event=Toybox.Background.getTemporalEventRegisteredTime();
    var armed=event instanceof Time.Duration && event.value()==300;
    Storage.setValue("ciqProbePhase","fit"); ciqResumeChecks();
    var result=armed && Toybox.Background.getTemporalEventRegisteredTime()==null;
    ciqProbeRestore(saved);
    if (previous!=null) { Toybox.Background.registerForTemporalEvent(previous); }
    return result;
}
