import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Test;
import Toybox.Time;

class CiqAutoSpy extends CiqAutoSync {
    var manifests as Number=0; var downloads as Number=0; var exits as Number=0;
    function initialize() { CiqAutoSync.initialize(); }
    function requestManifest() as Void { manifests++; }
    function requestFit(id as String) as Void { downloads++; }
    function exitService() as Void { exits++; }
}
class CiqLibraryTestContent {
    function initialize() { }
    function getId() as Number { return 144; }
    function getName() as String { return "EOP1000000144"; }
    function toIntent() as System.Intent { throw new Lang.InvalidValueException("Sin apertura en la prueba"); }
    function remove() as Void { throw new Lang.InvalidValueException("No borrar contenido"); }
}
class CiqLibrarySpy extends CiqLibrary {
    var nativeReads as Number=0; var hasApp as Boolean=false;
    function initialize() { CiqLibrary.initialize(); }
    function findApp(name as String) as PersistedContent.Content? { return hasApp?new CiqLibraryTestContent():null; }
    function findNative(name as String) as PersistedContent.Content? { nativeReads++; return new CiqLibraryTestContent(); }
}
class CiqAutoViewSpy extends CiqView {
    function initialize() { CiqView.initialize(); }
    function localWorkout(name as String) as PersistedContent.Content? { return new CiqLibraryTestContent(); }
}
function ciqAutoKeys() as Array<String> {
    return ["ciqAutoEnabled","ciqSyncRecords","ciqSyncGeneration","ciqCredential","ciqPairCode","ciqProbeMode",
        "ciqProbeName","ciqAutoState","ciqAutoAt","ciqAutoHttp","ciqAutoManifestHttp","ciqAutoName","ciqBackgroundEnabled"];
}
function ciqAutoSave() as Dictionary {
    var saved={} as Dictionary; var keys=ciqAutoKeys();
    for (var i=0;i<keys.size();i++) { saved[keys[i]]=Storage.getValue(keys[i]); }
    Storage.setValue("ciqAutoEnabled",true); Storage.setValue("ciqSyncRecords",{});
    Storage.setValue("ciqSyncGeneration",1); Storage.setValue("ciqCredential","synthetic-local-test");
    Storage.setValue("ciqProbeMode",false); Storage.deleteValue("ciqPairCode"); Storage.deleteValue("ciqProbeName");
    return saved;
}
function ciqAutoRestore(saved as Dictionary) as Void {
    var keys=ciqAutoKeys();
    for (var i=0;i<keys.size();i++) {
        if (saved[keys[i]]==null) { Storage.deleteValue(keys[i]); }
        else { Storage.setValue(keys[i],saved[keys[i]] as Storage.ValueType); }
    }
}
function ciqAutoData() as Dictionary {
    var entry=ciqTestEntry(); entry["fit_name"]="EOP1000000144";
    return {"complete"=>true,"entries"=>[entry]};
}
(:test)
function nativeBackgroundCopyIsRecognizedWithoutFitCallback(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var library=new CiqLibrarySpy();
    ciqSyncAttempt("EOP1000000144","10000000-0000-4000-8000-000000000001",Time.now().value(),"segundo plano");
    var content=library.find("EOP1000000144"); var record=ciqSyncRecords()["EOP1000000144"] as Dictionary;
    var result=content!=null && library.nativeReads==1 && (record["phase"] as String).equals("verified") &&
        (record["native_id"] as Number)==144 && (record["origin"] as String).equals("segundo plano") &&
        (record["library"] as String).equals("general");
    ciqAutoRestore(saved); return result;
}
(:test)
function unrequestedOrMalformedNativeAliasesAreNotAdopted(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var library=new CiqLibrarySpy();
    var unknown=library.find("EOP1000000144")==null;
    Storage.setValue("ciqSyncRecords",{"Otro entrenamiento"=>{"phase"=>"requested"}});
    var result=unknown && library.find("Otro entrenamiento")==null && library.nativeReads==0;
    ciqAutoRestore(saved); return result;
}
(:test)
function legacyProbeCopyCanBeFoundWithoutDownloadingAgain(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); Storage.setValue("ciqProbeName","EOP1000000144");
    var library=new CiqLibrarySpy(); var result=library.find("EOP1000000144")!=null && library.nativeReads==1;
    ciqAutoRestore(saved); return result;
}
(:test)
function ownLibraryStillWorksWithoutAdoptingGlobalContent(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var library=new CiqLibrarySpy(); library.hasApp=true;
    var result=library.find("EOP1000000144")!=null && library.nativeReads==0;
    ciqAutoRestore(saved); return result;
}
(:test)
function automaticDuplicateCallbacksNeverDuplicateDownload(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var worker=new CiqAutoSpy(); worker.run();
    worker.onManifest(200,ciqAutoData()); worker.onManifest(200,ciqAutoData());
    var pendingHttp=Storage.getValue("ciqAutoHttp") as Number;
    worker.onFit(200,null); worker.onFit(200,null);
    var record=ciqSyncRecords()["EOP1000000144"] as Dictionary;
    var result=pendingHttp==0 && worker.manifests==1 && worker.downloads==1 && worker.exits==1 &&
        (record["phase"] as String).equals("received") && !record.hasKey("native_id");
    worker=new CiqAutoSpy(); worker.run(); worker.onManifest(200,ciqAutoData());
    result=result && worker.downloads==0 && worker.exits==1;
    ciqAutoRestore(saved); return result;
}
(:test)
function missingCallbackHasCooldownAndFiniteRetryBudget(logger as Test.Logger) as Boolean {
    var now=Time.now().value();
    return !ciqSyncDue({"phase"=>"requested","attempts"=>1,"at"=>now-1799},now) &&
        ciqSyncDue({"phase"=>"requested","attempts"=>1,"at"=>now-1800},now) &&
        !ciqSyncDue({"phase"=>"failed","attempts"=>3,"at"=>now-3600},now) &&
        !ciqSyncDue({"phase"=>"received","attempts"=>1,"at"=>now-3600},now) &&
        !ciqSyncDue({"phase"=>"verified","attempts"=>1,"at"=>now-3600},now);
}
(:test)
function automaticRechecksManifestBeforeRetryAndStopsOnDenial(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); ciqSyncAttempt("EOP1000000144","10000000-0000-4000-8000-000000000001",Time.now().value()-1800,"segundo plano");
    var worker=new CiqAutoSpy(); worker.run(); worker.onManifest(403,ciqAutoData());
    var result=worker.manifests==1 && worker.downloads==0 && worker.exits==1 && !ciqAutoEnabled();
    ciqAutoRestore(saved); return result;
}
(:test)
function automaticDoesNotPruneFromMalformedOrPartialList(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); ciqSyncAttempt("EOP1000000144","10000000-0000-4000-8000-000000000001",Time.now().value(),"segundo plano");
    var data=ciqAutoData(); data["complete"]=false;
    var worker=new CiqAutoSpy(); worker.run(); worker.onManifest(200,data);
    var result=worker.downloads==0 && ciqSyncRecords().hasKey("EOP1000000144");
    ciqAutoRestore(saved); return result;
}
(:test)
function changedRevisionReplacesJournalAndGetsOneNewFit(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); ciqSyncAttempt("EOP1000000104","10000000-0000-4000-8000-000000000001",Time.now().value(),"segundo plano");
    ciqSyncResponse("EOP1000000104",200);
    var worker=new CiqAutoSpy(); worker.run(); worker.onManifest(200,ciqAutoData());
    var result=worker.downloads==1 && !ciqSyncRecords().hasKey("EOP1000000104") && ciqSyncRecords().hasKey("EOP1000000144");
    ciqAutoRestore(saved); return result;
}
(:test)
function emptyCurrentListWithdrawsJournalWithoutDeletingNativeContent(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); ciqSyncAttempt("EOP1000000144","10000000-0000-4000-8000-000000000001",Time.now().value(),"segundo plano");
    var worker=new CiqAutoSpy(); worker.run(); worker.onManifest(200,{"complete"=>true,"entries"=>[]});
    var result=worker.downloads==0 && worker.exits==1 && ciqSyncRecords().size()==0;
    ciqAutoRestore(saved); return result;
}
(:test)
function enteringForegroundOrChangingCredentialDiscardsAutoCallbacks(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var worker=new CiqAutoSpy(); worker.run(); ciqCancelSyncCallbacks();
    worker.onManifest(200,ciqAutoData()); var stale=worker.downloads==0 && worker.exits==1;
    worker=new CiqAutoSpy(); worker.run(); worker.onManifest(200,ciqAutoData());
    Storage.setValue("ciqCredential","different-synthetic-link"); worker.onFit(200,null);
    var record=ciqSyncRecords()["EOP1000000144"] as Dictionary;
    var result=stale && (record["phase"] as String).equals("requested");
    ciqAutoRestore(saved); return result;
}
(:test)
function automaticScheduleUsesOneOptInAndNeedsNoAlertConsent(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var previous=Background.getTemporalEventRegisteredTime();
    Storage.setValue("ciqBackgroundEnabled",false); ciqResumeChecks();
    var event=Background.getTemporalEventRegisteredTime(); var enabled=event instanceof Time.Duration && event.value()==900;
    Storage.setValue("ciqPairCode","PENDING1"); ciqResumeChecks();
    var result=enabled && Background.getTemporalEventRegisteredTime()==null;
    ciqAutoRestore(saved); if (previous!=null) { Background.registerForTemporalEvent(previous); }
    return result;
}
(:test)
function automaticStopsOnOptOutAndIgnoresEarlierEventCallbacks(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var first=new CiqAutoSpy(); first.run();
    var second=new CiqAutoSpy(); second.run(); first.onManifest(200,ciqAutoData());
    var stale=first.downloads==0 && first.exits==1;
    Storage.setValue("ciqAutoEnabled",false); second.onManifest(200,ciqAutoData());
    var off=new CiqAutoSpy(); off.run();
    var result=stale && second.downloads==0 && off.manifests==0 && off.downloads==0;
    ciqAutoRestore(saved); return result;
}
(:test)
function automaticDoesNotStarveAnotherAppointmentDuringCooldown(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave();
    ciqSyncAttempt("EOP1000000144","10000000-0000-4000-8000-000000000001",Time.now().value(),"segundo plano");
    var data=ciqAutoData(); var entries=data["entries"] as Array<Dictionary>;
    var next=ciqTestEntry(); next["id"]="10000000-0000-4000-8000-000000000002"; next["fit_name"]="EOP1000000145";
    entries.add(next);
    var worker=new CiqAutoSpy(); worker.run(); worker.onManifest(200,data);
    var result=worker.downloads==1 && ciqSyncRecords().hasKey("EOP1000000145") && ciqSyncRecords().size()==2;
    ciqAutoRestore(saved); return result;
}
(:test)
function automaticMigrationRequiresValidManifestAndRespectsOptOut(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); Storage.deleteValue("ciqAutoEnabled"); var view=new CiqAutoViewSpy();
    var data=ciqAutoData(); data["complete"]=false; view.onManifest(200,data);
    var invalid=Storage.getValue("ciqAutoEnabled")==null;
    view.onManifest(200,ciqAutoData()); var enabled=ciqAutoEnabled();
    Storage.setValue("ciqAutoEnabled",false); view.onManifest(200,ciqAutoData());
    var result=invalid && enabled && !ciqAutoEnabled();
    ciqAutoRestore(saved); return result;
}
(:test)
function foregroundWaitsForRecentBackgroundImportWithoutWaitingForever(logger as Test.Logger) as Boolean {
    var saved=ciqAutoSave(); var now=Time.now().value();
    ciqSyncAttempt("EOP1000000144","10000000-0000-4000-8000-000000000001",now,"segundo plano");
    var pending=ciqSyncImportPending("EOP1000000144",now+89) && !ciqSyncImportPending("EOP1000000144",now+90);
    ciqSyncResponse("EOP1000000144",200); pending=pending && ciqSyncImportPending("EOP1000000144",now+1);
    ciqSyncAttempt("EOP1000000144","10000000-0000-4000-8000-000000000001",now,"primer plano");
    var result=pending && !ciqSyncImportPending("EOP1000000144",now+1);
    ciqAutoRestore(saved); return result;
}
