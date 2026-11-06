// Recodifica mp3 con ffmpeg (sin etiquetas ni carátula) para ahorrar espacio.
// Como script copia una carpeta entera a otra, comprimiendo los .mp3 y
// copiando el resto (portadas, etc.); no toca el origen. Uso:
//   node scripts/comprimir_audio.mjs <origen> <destino> [kbps=112]
// Necesita ffmpeg en el PATH o en la variable FFMPEG.
import { spawn } from "node:child_process";
import { copyFile, mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

// Devuelve el mp3 recodificado a [kbps], o el original si no queda más pequeño
// (p. ej. los stems, que ya vienen a poco bitrate).
export function comprimir(buf, kbps) {
  return new Promise((ok, fallo) => {
    const ff = spawn(process.env.FFMPEG ?? "ffmpeg", [
      "-v", "error", "-i", "pipe:0", "-map", "0:a", "-map_metadata", "-1",
      "-c:a", "libmp3lame", "-b:a", `${kbps}k`, "-write_xing", "0", "-f", "mp3", "pipe:1",
    ]);
    const salida = [];
    let errores = "";
    ff.stdout.on("data", (d) => salida.push(d));
    ff.stderr.on("data", (d) => (errores += d));
    ff.on("error", fallo);
    ff.stdin.on("error", () => {}); // si ffmpeg cierra antes, lo reporta "close"
    ff.on("close", (code) => {
      const out = Buffer.concat(salida);
      if (code !== 0 || !out.length) return fallo(new Error(`ffmpeg falló: ${errores}`));
      ok(out.length < buf.length ? out : buf);
    });
    ff.stdin.end(buf);
  });
}

async function copiar(origen, destino, kbps) {
  let antes = 0, despues = 0;
  await mkdir(destino, { recursive: true });
  for (const e of await readdir(origen, { withFileTypes: true })) {
    const o = join(origen, e.name), d = join(destino, e.name);
    if (e.isDirectory()) {
      const r = await copiar(o, d, kbps);
      antes += r.antes; despues += r.despues;
    } else if (/\.mp3$/i.test(e.name)) {
      const buf = await readFile(o);
      const out = await comprimir(buf, kbps);
      await writeFile(d, out);
      antes += buf.length; despues += out.length;
    } else {
      await copyFile(o, d);
    }
  }
  return { antes, despues };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [origen, destino, kbps = "112"] = process.argv.slice(2);
  if (!origen || !destino) {
    console.error("Uso: node scripts/comprimir_audio.mjs <origen> <destino> [kbps=112]");
    process.exit(1);
  }
  if (resolve(origen) === resolve(destino)) {
    console.error("El destino debe ser distinto del origen.");
    process.exit(1);
  }
  copiar(resolve(origen), resolve(destino), Number(kbps)).then(
    ({ antes, despues }) =>
      console.log(`mp3: ${(antes / 1e6).toFixed(1)} MB -> ${(despues / 1e6).toFixed(1)} MB`),
    (e) => { console.error(e.message); process.exitCode = 1; },
  );
}
