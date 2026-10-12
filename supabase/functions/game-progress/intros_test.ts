import {
  coinBalance,
  coinsEarned,
  introCoinRewards,
} from "./intros.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Se esperaba ${JSON.stringify(expected)} y llegó ${JSON.stringify(actual)}`);
  }
}

Deno.test("completar las tres dificultades paga exactamente 45 monedas", () => {
  const five = (prefix: string) => [1, 2, 3, 4, 5].map((n) => `${prefix}-0${n}`);
  assertEquals(
    coinsEarned({
      facil: five("facil"),
      medio: five("media"),
      avanzado: five("dificil"),
    }),
    45,
  );
  assertEquals(Object.values(introCoinRewards), [2, 3, 4]);
});

Deno.test("repetir un nivel no vuelve a pagar", () => {
  assertEquals(coinsEarned({ facil: ["facil-01", "facil-01"] }), 2);
  assertEquals(coinsEarned({}), 0);
});

Deno.test("el saldo descuenta una moneda por intro y nunca es negativo", () => {
  assertEquals(coinBalance(9, 4), 5);
  assertEquals(coinBalance(2, 5), 0);
});
