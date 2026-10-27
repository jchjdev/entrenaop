import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

function ciqOpenTestFlow() as CiqOpenFlow {
    var entry=ciqTestEntry();
    return new CiqOpenFlow(entry["id"] as String,entry["fit_name"] as String);
}
function ciqOpenTestPermission() as Dictionary {
    return {"complete"=>true,"entries"=>[ciqTestEntry()]};
}
(:test)
function openingSendsOnlyOneCheckAndOneNativeRequest(logger as Test.Logger) as Boolean {
    var flow=ciqOpenTestFlow(); var checks=0; var launches=0;
    if (flow.begin()) { checks++; }
    if (flow.begin()) { checks++; }
    var first=flow.authorize(ciqOpenTestPermission());
    var duplicate=flow.authorize(ciqOpenTestPermission());
    if (flow.takeLaunch()) { launches++; }
    if (flow.takeLaunch()) { launches++; }
    flow.handedOff();
    return checks==1 && first && !duplicate && launches==1 && flow.phase()==:handedOff;
}
(:test)
function closingBeforePermissionDiscardsLateResponse(logger as Test.Logger) as Boolean {
    var old=ciqOpenTestFlow(); old.begin(); old.cancel();
    var fresh=ciqOpenTestFlow(); fresh.begin();
    return !old.authorize(ciqOpenTestPermission()) && !old.takeLaunch() &&
        !fresh.takeLaunch() && fresh.authorize(ciqOpenTestPermission()) && fresh.takeLaunch();
}
(:test)
function closingAfterPermissionCancelsQueuedIntent(logger as Test.Logger) as Boolean {
    var flow=ciqOpenTestFlow(); flow.begin(); flow.authorize(ciqOpenTestPermission());
    flow.cancel();
    return !flow.takeLaunch() && flow.phase()==:cancelled;
}
(:test)
function withdrawnOrPartialPermissionNeverReachesNativeLaunch(logger as Test.Logger) as Boolean {
    var cases=[{"complete"=>true,"entries"=>[]},
        {"complete"=>false,"entries"=>[ciqTestEntry()]}] as Array<Dictionary>;
    for (var index=0;index<cases.size();index++) {
        var flow=ciqOpenTestFlow(); flow.begin();
        if (flow.authorize(cases[index]) || flow.takeLaunch() || flow.begin()) { return false; }
    }
    return true;
}
(:test)
function nativeFailureRequiresFreshPermissionRatherThanAutomaticRetry(logger as Test.Logger) as Boolean {
    var flow=ciqOpenTestFlow(); flow.begin(); flow.authorize(ciqOpenTestPermission());
    if (!flow.takeLaunch()) { return false; }
    flow.fail();
    var fresh=ciqOpenTestFlow(); fresh.begin();
    return !flow.takeLaunch() && !flow.begin() && !fresh.takeLaunch() &&
        fresh.authorize(ciqOpenTestPermission()) && fresh.takeLaunch();
}
(:test)
function permissionForAnotherWorkoutCannotOpenSelectedCopy(logger as Test.Logger) as Boolean {
    var entry=ciqTestEntry(); entry["id"]="20000000-0000-4000-8000-000000000002";
    var flow=ciqOpenTestFlow(); flow.begin();
    return !flow.authorize({"complete"=>true,"entries"=>[entry]}) && !flow.takeLaunch();
}
(:test)
function sdkIntentExceptionsKeepTheirSpecificRecoveryCase(logger as Test.Logger) as Boolean {
    return ciqOpenErrorCode(new System.PreviousOperationNotCompleteException("pending")).equals("pending") &&
        ciqOpenErrorCode(new System.AppNotInstalledException()).equals("not_installed") &&
        ciqOpenErrorCode(new System.UnexpectedAppTypeException("type")).equals("wrong_type") &&
        ciqOpenErrorCode(new Lang.Exception()).equals("native_error");
}
