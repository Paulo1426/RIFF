import { coleccion, genero, ubicacion } from "../_shared/genero.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Se esperaba ${JSON.stringify(expected)} y llegó ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("colecciones con prefijo y un bucket por género con carpetas", () => {
  assertEquals(genero, "vallenato");
  assertEquals(coleccion("songs"), "vallenato_songs");
  assertEquals(coleccion("privateLevelAnswers"), "vallenato_privateLevelAnswers");
  assertEquals(ubicacion("instrumentos", "cancion-001/bateria.mp3"), {
    bucket: "vallenato",
    ruta: "instrumentos/cancion-001/bateria.mp3",
  });
  assertEquals(ubicacion("intro", "cancion-01/intro.mp3"), {
    bucket: "vallenato",
    ruta: "intro_vallenato/cancion-01/intro.mp3",
  });
});
