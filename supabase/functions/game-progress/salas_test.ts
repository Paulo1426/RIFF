import {
  codigoValido,
  eliminadoDeRonda,
  generarCodigo,
  nivelDeIndice,
  puntosAcierto,
} from "./salas.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Se esperaba ${JSON.stringify(expected)} y llegó ${JSON.stringify(actual)}`);
  }
}

Deno.test("el código tiene 6 caracteres válidos", () => {
  let n = 0;
  const codigo = generarCodigo((max) => n++ % max);
  assertEquals(codigo.length, 6);
  assertEquals(codigoValido(codigo), true);
  assertEquals(codigoValido("ABC10O"), false);
});

Deno.test("acertar rápido y sin gastar da más puntos", () => {
  assertEquals(puntosAcierto(0, 1_000_000), 250);
  assertEquals(puntosAcierto(60, 300_000), 170);
  assertEquals(puntosAcierto(400, 0), 100);
});

Deno.test("sale el único que falta por adivinar", () => {
  assertEquals(eliminadoDeRonda(["a", "b", "c"], ["a"]), null);
  assertEquals(eliminadoDeRonda(["a", "b", "c"], ["c", "a"]), "b");
  assertEquals(eliminadoDeRonda(["a", "b"], ["b"]), "a");
  assertEquals(eliminadoDeRonda(["a"], []), null);
});

Deno.test("la lista de canciones vuelve a empezar", () => {
  assertEquals(nivelDeIndice(["x", "y"], 3), "y");
});
