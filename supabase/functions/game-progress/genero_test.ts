import {
  coleccion,
  coleccionJugador,
  conGenero,
  esGenero,
  generoActual,
  ubicacion,
} from "../_shared/genero.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Se esperaba ${JSON.stringify(expected)} y llegó ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("colecciones con prefijo y un bucket por género con carpetas", () => {
  assertEquals(generoActual(), "vallenato");
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
  assertEquals(coleccionJugador("progress"), "progress");
});

Deno.test("cada petición usa su propio género", async () => {
  const [reggaeton, rock] = await Promise.all([
    conGenero("reggaeton", async () => {
      await new Promise((resolve) => setTimeout(resolve, 10));
      return [coleccion("levels"), coleccionJugador("progress")];
    }),
    conGenero("rock_pop", async () => {
      await new Promise((resolve) => setTimeout(resolve, 1));
      return [
        ubicacion("intro", "cancion-01/intro.mp3"),
        coleccionJugador("introProgress"),
      ];
    }),
  ]);
  assertEquals(reggaeton, ["reggaeton_levels", "reggaeton_progress"]);
  assertEquals(rock, [
    { bucket: "rock-pop", ruta: "intro_rock-pop/cancion-01/intro.mp3" },
    "rock_pop_introProgress",
  ]);
  assertEquals(conGenero("hackeo", generoActual), "vallenato");
  assertEquals(esGenero("hackeo"), false);
  assertEquals(generoActual(), "vallenato");
});
