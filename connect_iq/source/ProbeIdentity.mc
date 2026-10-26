import Toybox.Lang;

typedef ProbeIdentity as interface {
    function getName() as String;
    function getId() as Number;
};

// El llamador aporta contenido de getAppWorkouts, nunca del catálogo ajeno.
function isProbeWorkout(content as ProbeIdentity, expectedId as Number) as Boolean {
    // En Monkey C comparar el contenido textual con equals(), no su referencia.
    return content.getId() == expectedId && content.getName().equals("EntrenaOP IQ prueba 01");
}
