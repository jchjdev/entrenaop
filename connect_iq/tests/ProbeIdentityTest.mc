import Toybox.Lang;
import Toybox.Test;

class ProbeIdentityStub {
    private var _name as String;
    private var _id as Number;
    function initialize(name as String, id as Number) { _name = name; _id = id; }
    function getName() as String { return _name; }
    function getId() as Number { return _id; }
}

(:test)
function contentInterfaceNeedsNoWorkoutSubclass(logger as Test.Logger) as Boolean {
    // Regresión: un objeto con la interfaz oficial es válido sin heredar Workout.
    return isProbeWorkout(new ProbeIdentityStub("EntrenaOP IQ prueba 01", 42), 42);
}

(:test)
function anotherInstalledWorkoutCannotConfirmProbe(logger as Test.Logger) as Boolean {
    return !isProbeWorkout(new ProbeIdentityStub("Otro entrenamiento", 42), 42) &&
        !isProbeWorkout(new ProbeIdentityStub("EntrenaOP IQ prueba 01", 43), 42);
}
