import { hintCosts, hintTypes, maskInitials, titleLetter } from "./hints.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Se esperaba ${JSON.stringify(expected)} y llegó ${JSON.stringify(actual)}`);
  }
}

Deno.test("las iniciales dejan ver solo la primera letra de cada palabra", () => {
  assertEquals(maskInitials("Los caminos de la vida"), "L__ c______ d_ l_ v___");
  assertEquals(maskInitials("¡Ay, corazón!"), "¡A_, c______!");
});

Deno.test("primera y última letra ignoran puntuación y espacios", () => {
  assertEquals(titleLetter("¡Ay, corazón!"), "A");
  assertEquals(titleLetter("¡Ay, corazón!", true), "N");
  assertEquals(titleLetter("90 60 90", true), "0");
  assertEquals(titleLetter("..."), "");
});

Deno.test("cada tipo de pista tiene precio", () => {
  for (const tipo of hintTypes) {
    assertEquals(typeof hintCosts[tipo as keyof typeof hintCosts], "number");
  }
  assertEquals(hintTypes.has("first_letter"), true);
  assertEquals(hintTypes.has("last_letter"), true);
});
