import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

(:test)
function foregroundEntrySuspendsRegisteredChecks(logger as Test.Logger) as Boolean {
    var original=Background.getTemporalEventRegisteredTime();
    Background.registerForTemporalEvent(new Time.Duration(900));
    ciqSuspendChecks();
    var result=Background.getTemporalEventRegisteredTime()==null;
    if (original!=null) { Background.registerForTemporalEvent(original); }
    return result;
}

(:test)
function foregroundExitSchedulesOnlyOptedInLinkedWatch(logger as Test.Logger) as Boolean {
    var keys=["ciqBackgroundEnabled","ciqCredential","ciqPairCode"] as Array<String>;
    var saved={} as Dictionary;
    for (var index=0;index<keys.size();index++) { saved[keys[index]]=Storage.getValue(keys[index]); }
    var original=Background.getTemporalEventRegisteredTime();
    // Credencial local sintética: no se hace ninguna petición ni se ejecuta el evento.
    Storage.setValue("ciqCredential","synthetic-local-test"); Storage.deleteValue("ciqPairCode");
    Storage.setValue("ciqBackgroundEnabled",false); ciqResumeChecks();
    var disabled=Background.getTemporalEventRegisteredTime()==null;
    Storage.setValue("ciqBackgroundEnabled",true); ciqResumeChecks();
    var registered=Background.getTemporalEventRegisteredTime();
    var linked=registered instanceof Time.Duration && registered.value()==900;
    Storage.setValue("ciqPairCode","PENDING1"); ciqResumeChecks();
    var pending=Background.getTemporalEventRegisteredTime()==null;
    Storage.deleteValue("ciqPairCode"); Storage.deleteValue("ciqCredential"); ciqResumeChecks();
    var unlinked=Background.getTemporalEventRegisteredTime()==null;
    for (var index=0;index<keys.size();index++) {
        var key=keys[index];
        if (saved[key]==null) { Storage.deleteValue(key); } else { Storage.setValue(key,saved[key] as Storage.ValueType); }
    }
    if (original!=null) { Background.registerForTemporalEvent(original); }
    return disabled && linked && pending && unlinked;
}
