package es.entrenaop.health_read_probe

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView

class HealthRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = TextView(this).apply {
            textSize = 18f
            setPadding(32, 48, 32, 48)
            this.text = "Ensayo local de EntrenaOP\n\n" +
                "Solo solicita leer entrenamientos para mostrar carreras de los últimos siete días, " +
                "sus fechas, duración y aplicación de origen. No solicita pasos, calorías, pulso, " +
                "ubicación, rutas ni permisos de escritura o segundo plano.\n\n" +
                "Los datos permanecen en memoria. No hay cuenta, servidor, exportación ni comunicación " +
                "con entrenadores. Vaciar la lectura o cerrar la app elimina la lectura local; " +
                "los permisos se retiran desde los ajustes de Health Connect."
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }
}
