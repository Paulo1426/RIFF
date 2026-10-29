import { bucketDe, coleccion, genero } from "../_shared/genero.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Se esperaba ${JSON.stringify(expected)} y llegó ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("colecciones y buckets llevan el prefijo del género", () => {
  assertEquals(genero, "vallenato");
  assertEquals(coleccion("songs"), "vallenato_songs");
  assertEquals(coleccion("privateLevelAnswers"), "vallenato_privateLevelAnswers");
  assertEquals(bucketDe("instrumentos"), "vallenato-instrumentos");
  assertEquals(bucketDe("cancion-intro"), "vallenato-cancion-intro");
});
