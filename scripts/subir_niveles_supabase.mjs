// Sube (comprimidos) los niveles de un género a su bucket de Supabase. Uso:
//   GENERO=vallenato node scripts/subir_niveles_supabase.mjs <carpeta>          (vista previa)
//   GENERO=vallenato node scripts/subir_niveles_supabase.mjs <carpeta> --apply  (sube)
// <carpeta> tiene "01 Facil", "02 Medio", "03 Difícil" con cancion_N/ dentro:
//   <titulo>.mp3 + portada.jpg      -> canciones-completas/cancion-00N/
//   <titulo>_instrumental.mp3       -> canciones-instrumentales/cancion-00N/
//   acordeon|trompeta|violin|bajo|bateria|guitarra|otros -> instrumentos/cancion-00N/ (trompeta y violin como acordeon)
// Cualquier otro archivo (p. ej. p1.MP3) se ignora. Sobrescribe lo que ya exista.
// "N_<titulo>_(Instrumental).mp3" se sube como <titulo>_instrumental.mp3 (titulo = el mp3 completo).
// Con SOLO_STEMS=1 sube únicamente instrumentos/ (acordeon, bajo, bateria, guitarra).
// Todo se nivela de volumen al subir (nivelar_audio.mjs): canciones -16 LUFS, stems -22 LUFS.
import { readdir, readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { comprimir } from "./comprimir_audio.mjs";
import { filtroNivel, objetivoCancion, objetivoStem } from "./nivelar_audio.mjs";
import { genero } from "./cargar_niveles_firestore.mjs";

const kbps = 112;
const supabaseUrl = process.env.SUPABASE_URL ?? "https://btfoclgtqhokqkgbpxmp.supabase.co";
const bucket = genero.replaceAll("_", "-");
const stems = new Set(["acordeon", "bajo", "bateria", "guitarra", "otros"]);
// El stem melódico se sube siempre como "acordeon" (id interno de la app, que
// en cada género muestra su instrumento: Trompeta en salsa, Violín en popular).
const melodico = new Set(["trompeta", "violin"]);

// Destino en el bucket de un archivo de nivel, o null si se ignora.
export function destino(nombre, id) {
  const lower = nombre.toLowerCase();
  if (!/^[\w.-]+$/.test(nombre)) return null; // clave inválida en Storage (ñ, paréntesis…)
  if (lower === "portada.jpg") return `canciones-completas/${id}/portada.jpg`;
  if (!lower.endsWith(".mp3")) return null;
  const base = nombre.slice(0, -4);
  if (melodico.has(base.toLowerCase())) return `instrumentos/${id}/acordeon.mp3`;
  if (stems.has(base.toLowerCase())) return `instrumentos/${id}/${lower}`;
  if (/_instrumental$/i.test(base)) return `canciones-instrumentales/${id}/${base}.mp3`;
  if (/^p\d+$/i.test(base)) return null;
  return `canciones-completas/${id}/${base}.mp3`;
}

async function subir(key, ruta, cuerpo, tipo) {
  const r = await fetch(`${supabaseUrl}/storage/v1/object/${bucket}/${ruta}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, apikey: key, "Content-Type": tipo, "x-upsert": "true" },
    body: cuerpo,
  });
  if (!r.ok) throw new Error(`Supabase rechazó ${ruta} (${r.status}): ${await r.text()}`);
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const base = resolve(args.find((a) => !a.startsWith("--")) ?? ".");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (apply && !key) throw new Error("Define SUPABASE_SERVICE_ROLE_KEY.");
  if (apply) {
    // Bucket privado del género (en un proyecto nuevo aún no existe).
    const creado = await fetch(`${supabaseUrl}/storage/v1/bucket`, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({ id: bucket, name: bucket, public: false }),
    });
    const texto = await creado.text();
    if (!creado.ok && !/already exists|Duplicate/i.test(texto)) {
      throw new Error(`No se pudo crear el bucket ${bucket} (${creado.status}): ${texto}`);
    }
  }

  let antes = 0, despues = 0, n = 0;
  for (const dificultad of (await readdir(base)).filter((d) => /^0\d /.test(d)).sort()) {
    for (const c of (await readdir(join(base, dificultad))).filter((d) => /^cancion_\d+$/.test(d)).sort()) {
      const id = `cancion-${c.split("_")[1].padStart(3, "0")}`;
      const archivos = await readdir(join(base, dificultad, c));
      const completa = archivos.find((a) => destino(a, id)?.startsWith("canciones-completas/") && a.endsWith(".mp3"));
      for (const nombre of archivos) {
        const ruta = /^\d+_.*\(Instrumental\)\.mp3$/i.test(nombre) && completa
          ? `canciones-instrumentales/${id}/${completa.slice(0, -4)}_instrumental.mp3`
          : destino(nombre, id);
        if (!ruta || (process.env.SOLO_STEMS && !ruta.startsWith("instrumentos/"))) continue;
        let cuerpo = await readFile(join(base, dificultad, c, nombre));
        const tam = cuerpo.length;
        let nivel = "";
        if (ruta.endsWith(".mp3")) {
          const esStem = ruta.startsWith("instrumentos/");
          const { medido, ganancia, filtro } = await filtroNivel(cuerpo, esStem ? objetivoStem : objetivoCancion);
          cuerpo = await comprimir(cuerpo, kbps, filtro);
          nivel = ` ${medido.toFixed(1)} LUFS ${ganancia >= 0 ? "+" : ""}${ganancia.toFixed(1)} dB`;
        }
        antes += tam; despues += cuerpo.length; n++;
        console.log(`  ${bucket}/${ruta} ${Math.round(tam / 1024)} -> ${Math.round(cuerpo.length / 1024)} KB${nivel}`);
        if (apply) await subir(key, ruta, cuerpo, ruta.endsWith(".mp3") ? "audio/mpeg" : "image/jpeg");
      }
    }
  }
  console.log(`${apply ? "Subidos" : "Vista previa:"} ${n} archivos, ${(antes / 1e6).toFixed(1)} -> ${(despues / 1e6).toFixed(1)} MB.`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((e) => { console.error(e.message); process.exitCode = 1; });
}
