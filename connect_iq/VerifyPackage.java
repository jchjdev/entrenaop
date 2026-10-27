import java.io.File;
import com.garmin.connectiq.common.signing.KeyUtils;
import com.garmin.connectiq.common.signing.VerifyingUtils;

// Usa el verificador del mismo SDK que compila: no reempaqueta ni modifica el IQ.
// La clave solo se lee localmente; nunca se imprime ni se añade al paquete.
class VerifyPackage {
    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("Indicar paquete IQ y clave local de firma.");
        var publicKey = KeyUtils.getPublicKey(KeyUtils.getPrivateKey(new File(args[1])));
        if (!VerifyingUtils.verifyIqFile(new File(args[0]), publicKey)) {
            throw new IllegalStateException("El SDK rechaza la firma del paquete IQ.");
        }
        System.out.println("Firma IQ verificada por el SDK: manifiesto y ejecutables correctos.");
    }
}
