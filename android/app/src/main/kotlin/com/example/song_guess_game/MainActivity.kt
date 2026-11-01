package com.example.song_guess_game

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // En pantallas de 90/120 Hz la app pide 60 Hz: deslizar y las
        // transiciones van parejas y gasta menos batería. Se elige el modo de
        // la pantalla más cercano a 60 Hz con la misma resolución.
        @Suppress("DEPRECATION")
        val pantalla = windowManager.defaultDisplay
        // Los modos de pantalla existen desde Android 6 (API 23).
        val modo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val actual = pantalla.mode
            pantalla.supportedModes
                .filter {
                    it.physicalWidth == actual.physicalWidth &&
                        it.physicalHeight == actual.physicalHeight
                }
                .minByOrNull { abs(it.refreshRate - 60f) }
        } else {
            null
        }
        window.attributes = window.attributes.apply {
            preferredRefreshRate = 60f
            if (modo != null) preferredDisplayModeId = modo.modeId
        }
    }
}
