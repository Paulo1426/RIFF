// Mide el volumen (LUFS) de un mp3 y devuelve el filtro de ffmpeg que lo lleva al objetivo.
// Sube como máximo [subidaMax] dB (un stem casi mudo no se convierte en ruido) y un limitador
// evita que los picos pasen de ~-1 dBFS. Necesita ffmpeg en el PATH o en la variable FFMPEG.
import { spawn } from "node:child_process";

export const objetivoCancion = -16; // canciones completas e instrumentales
export const objetivoStem = -22; // cada instrumento; los 4 juntos quedan cerca de las canciones

function medir(buf) {
  return new Promise((ok, fallo) => {
    const ff = spawn(process.env.FFMPEG ?? "ffmpeg", [
      "-hide_banner", "-nostats", "-i", "pipe:0", "-af", "loudnorm=I=-23:print_format=json", "-f", "null", "-",
    ]);
    let errores = "";
    ff.stderr.on("data", (d) => (errores += d));
    ff.stdin.on("error", () => {});
    ff.on("error", fallo);
    ff.on("close", () => {
      const m = errores.match(/\{[^{}]*"input_i"[^{}]*\}/);
      if (!m) return fallo(new Error(`ffmpeg no midió el volumen: ${errores.slice(-300)}`));
      const i = parseFloat(JSON.parse(m[0]).input_i);
      ok(Number.isFinite(i) ? i : -70); // "-inf" = silencio digital
    });
    ff.stdin.end(buf);
  });
}

export async function filtroNivel(buf, objetivo, subidaMax = 15) {
  const medido = await medir(buf);
  const ganancia = Math.max(-20, Math.min(subidaMax, objetivo - medido));
  return {
    medido,
    ganancia,
    filtro: `volume=${ganancia.toFixed(2)}dB,alimiter=limit=0.89:attack=5:release=50:level=false`,
  };
}
