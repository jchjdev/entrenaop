import 'package:device_health/device_health.dart';
export 'package:device_health/device_health.dart'
    show
        LocalHealthPlatform,
        HealthStoreAvailability,
        HealthReadConsent,
        HealthReadWindow,
        LocalHealthRead,
        LocalRunningHealth;

// Alias del ensayo: el puerto compartido ya no depende de la app de laboratorio.
typedef HealthProbeException = HealthReadException;
typedef HealthProbeProblem = HealthReadProblem;
