import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.Test;

class CiqOpenTestOwner extends CiqView {
    var checks as Number=0;
    var lookups as Number=0;
    var invalidations as Number=0;
    var failures as Number=0;
    function initialize() { CiqView.initialize(); }
    function requestOpenPermission(callback as Method(code as Number,data as Communications.ContentType?) as Void) as Void {
        checks++;
    }
    function localWorkout(name as String) as PersistedContent.Content? { lookups++; return null; }
    function invalidateOpen(message as String) as Void { invalidations++; }
    function openPermissionFailure(code as Number,data as Communications.ContentType?) as String {
        failures++; return "No autorizado";
    }
}

(:test)
function hiddenOpeningViewDiscardsLateCallbacks(logger as Test.Logger) as Boolean {
    var owner=new CiqOpenTestOwner(); var view=new CiqOpenView(owner,ciqTestEntry());
    view.onShow(); view.onHide();
    view.onPermission(200,ciqOpenTestPermission()); view.onPermission(401,null);
    view.onLaunch(); view.onShow(); view.onHide();
    return owner.checks==1 && owner.lookups==0 && owner.invalidations==0 && owner.failures==0;
}

(:test)
function openingViewChecksOnceAndRejectsMissingLocalCopy(logger as Test.Logger) as Boolean {
    var owner=new CiqOpenTestOwner(); var view=new CiqOpenView(owner,ciqTestEntry());
    view.onShow(); view.onShow();
    view.onPermission(200,ciqOpenTestPermission()); view.onPermission(401,null);
    view.onLaunch(); view.onLaunch(); view.onHide();
    return owner.checks==1 && owner.lookups==1 && owner.invalidations==1 && owner.failures==0;
}

(:test)
function timeoutCannotAuthorizeOpeningAndFreshAttemptRequiresPermission(logger as Test.Logger) as Boolean {
    var owner=new CiqOpenTestOwner(); var old=new CiqOpenView(owner,ciqTestEntry());
    old.onShow(); old.onPermission(Communications.NETWORK_REQUEST_TIMED_OUT,null);
    old.onPermission(200,ciqOpenTestPermission()); old.onLaunch(); old.onHide();
    if (owner.lookups!=0 || owner.invalidations!=0 || owner.failures!=0) { return false; }
    var fresh=new CiqOpenView(owner,ciqTestEntry()); fresh.onShow(); fresh.onLaunch();
    if (owner.lookups!=0) { fresh.onHide(); return false; }
    fresh.onPermission(200,ciqOpenTestPermission()); fresh.onLaunch(); fresh.onHide();
    return owner.checks==2 && owner.lookups==1 && owner.invalidations==1 && owner.failures==0;
}

(:test)
function accessDeniedNeverUsesConnectionRetryPath(logger as Test.Logger) as Boolean {
    var owner=new CiqOpenTestOwner(); var view=new CiqOpenView(owner,ciqTestEntry());
    view.onShow(); view.onPermission(401,{"code"=>"link_revoked"});
    view.onPermission(200,ciqOpenTestPermission()); view.onLaunch(); view.onHide();
    return owner.checks==1 && owner.failures==1 && owner.lookups==0;
}
